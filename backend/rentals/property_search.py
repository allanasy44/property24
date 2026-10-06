import re
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.db.models import Q

from .ai import SEARCH_CITIES, parse_search_intent
from .models import Property


PROPERTY_TYPES = {value for value, _ in Property.PropertyType.choices}
AMENITY_FIELDS = {
    "solar_power": "solar_power",
    "borehole": "borehole",
    "furnished": "furnished",
    "pet_friendly": "pet_friendly",
    "electricity": "electricity_available",
    "title_deed": "title_deed_status",
    "serviced": "servicing_status",
}
AMENITY_ALIASES = {
    "solar_power": ("solar", "solar power", "solar system", "backup power"),
    "borehole": ("borehole", "bore hole"),
    "parking": ("parking", "secure parking", "garage", "carport"),
    "water": ("water", "reliable water", "municipal water"),
    "furnished": ("furnished", "fully furnished"),
    "pet_friendly": ("pet friendly", "pets", "pet-friendly"),
    "electricity": ("electricity", "electricity available", "zesa"),
    "title_deed": ("title deed", "deed"),
    "serviced": ("serviced", "fully serviced"),
    "security": ("security", "secure", "24 hour security", "gated"),
}
HARD_PHRASES = (
    "must have",
    "must include",
    "need",
    "needs",
    "require",
    "required",
    "only show",
    "only with",
    "non negotiable",
    "can't do without",
    "cannot do without",
)
SOFT_PHRASES = ("prefer", "preferably", "ideally", "would like", "nice to have")


class InvalidSearchRequirements(ValueError):
    pass


def _decimal_value(value, name):
    if value in (None, ""):
        return None
    try:
        amount = Decimal(str(value).replace(",", "").replace("$", "").strip())
    except (InvalidOperation, TypeError, ValueError):
        raise InvalidSearchRequirements(f"{name} must be a valid amount") from None
    if not amount.is_finite() or amount < 0:
        raise InvalidSearchRequirements(f"{name} must be a non-negative amount")
    return str(amount)


def _local_requirements(query, previous=None):
    intent = parse_search_intent(query)
    text = query.casefold()
    locations = [
        city.replace("_", " ")
        for city in SEARCH_CITIES
        if re.search(rf"\b{re.escape(city.replace('_', ' '))}\b", text)
    ]
    if intent.get("city") and intent["city"] not in locations:
        locations.insert(0, intent["city"])
    locations = list(dict.fromkeys(locations))
    area = re.search(
        r"\b(?:around|near|in)\s+(.+?)"
        r"(?=\s+(?:under|below|for|from|with|must|need|prefer|at least|up to|i can|show me)\b|[.!?]|$)",
        text,
    )
    if area:
        locations.extend(
            value.strip(" ,")
            for value in re.split(r"\s+(?:or|and)\s+|,", area.group(1))
            if value.strip(" ,")
        )
    locations = list(dict.fromkeys(locations))[:8]
    min_price = None
    max_price = intent.get("budget_max")
    price_range = re.search(
        r"(?:\$?\s*)?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:to|[-–])\s*\$?\s*"
        r"([0-9][0-9,]*(?:\.[0-9]+)?)",
        text,
    )
    if price_range:
        min_price, max_price = price_range.groups()
        min_price = min_price.replace(",", "")
        max_price = max_price.replace(",", "")
    property_type = intent.get("property_type") or "unspecified"
    hard = []
    preferred = []
    for amenity, aliases in AMENITY_ALIASES.items():
        if any(alias in text for alias in aliases):
            preferred.append(amenity)
    _promote_explicit_hard_amenities(query, hard, preferred)
    if previous:
        requirements = dict(previous)
        if not re.search(r"\b(?:rent|rental|lease|sale|buy|purchase|for sale)\b", text):
            intent_value = requirements.get("listing_intent", intent["intent"])
        else:
            intent_value = intent["intent"]
        requirements["listing_intent"] = intent_value
        if locations:
            requirements["locations"] = locations
        if intent.get("bedrooms_min") is not None:
            requirements["min_bedrooms"] = intent["bedrooms_min"]
        if max_price is not None:
            requirements["max_price"] = max_price
        if min_price is not None:
            requirements["min_price"] = min_price
        if property_type != "unspecified":
            requirements["property_type"] = property_type
        if hard or preferred:
            requirements["required_amenities"] = list(dict.fromkeys(
                requirements.get("required_amenities", []) + hard
            ))
            requirements["preferred_amenities"] = list(dict.fromkeys(
                [
                    *[
                        item for item in requirements.get("preferred_amenities", [])
                        if item not in hard
                    ],
                    *preferred,
                ]
            ))
            requirements["preferred_amenities"] = [
                item for item in requirements["preferred_amenities"]
                if item not in requirements["required_amenities"]
            ]
        if re.search(r"\bcheaper\b|\blower priced\b|\blower price\b", text):
            maximum = requirements.get("max_price")
            if maximum is not None:
                requirements["max_price"] = str(
                    (Decimal(maximum) * Decimal("0.9")).quantize(Decimal("0.01"))
                )
        if locations and locations != requirements.get("locations"):
            requirements["locations"] = locations
        return requirements
    return {
        "listing_intent": intent["intent"],
        "property_type": property_type,
        "locations": locations,
        "min_bedrooms": intent.get("bedrooms_min"),
        "max_bedrooms": None,
        "min_price": min_price,
        "max_price": max_price,
        "currency": "USD",
        "move_in_date": "",
        "required_amenities": hard,
        "preferred_amenities": preferred,
        "required_keywords": [
            category for category in ("townhouse", "room")
            if re.search(rf"\b{category}\b", text)
        ],
        "keywords": [],
        "flexibility": {
            "budget": False,
            "location": False,
            "bedrooms": False,
            "property_type": False,
        },
        "clarification_question": "",
    }


def normalize_search_requirements(raw, query):
    if not isinstance(raw, dict):
        raise InvalidSearchRequirements("Search requirements must be an object")
    listing_intent = str(raw.get("listing_intent") or "rent").lower()
    if listing_intent not in {choice for choice, _ in Property.ListingIntent.choices}:
        raise InvalidSearchRequirements("Unsupported listing intent")

    property_type = str(raw.get("property_type") or "unspecified").lower()
    unsupported_category = property_type if property_type in {"townhouse", "room"} else None
    if property_type == "apartment":
        property_type = Property.PropertyType.FLAT
    if property_type in {"townhouse", "room"}:
        property_type = "unspecified"
    if property_type not in PROPERTY_TYPES and property_type != "unspecified":
        raise InvalidSearchRequirements("Unsupported property type")

    locations = raw.get("locations") or []
    if not isinstance(locations, list):
        raise InvalidSearchRequirements("locations must be a list")
    locations = list(dict.fromkeys(
        str(location).strip()[:100]
        for location in locations
        if str(location).strip()
    ))[:8]

    def bedroom_value(value, label):
        if value in (None, ""):
            return None
        try:
            result = int(value)
        except (TypeError, ValueError):
            raise InvalidSearchRequirements(f"{label} must be a whole number") from None
        if result < 0 or result > 20:
            raise InvalidSearchRequirements(f"{label} must be from 0 to 20")
        return result

    min_bedrooms = bedroom_value(raw.get("min_bedrooms"), "min_bedrooms")
    max_bedrooms = bedroom_value(raw.get("max_bedrooms"), "max_bedrooms")
    if min_bedrooms is not None and max_bedrooms is not None and min_bedrooms > max_bedrooms:
        raise InvalidSearchRequirements("min_bedrooms must not exceed max_bedrooms")

    min_price = _decimal_value(raw.get("min_price"), "min_price")
    max_price = _decimal_value(raw.get("max_price"), "max_price")
    if min_price is not None and max_price is not None and Decimal(min_price) > Decimal(max_price):
        raise InvalidSearchRequirements("min_price must not exceed max_price")

    def amenities(name):
        values = raw.get(name) or []
        if not isinstance(values, list):
            raise InvalidSearchRequirements(f"{name} must be a list")
        return list(dict.fromkeys(
            str(value).strip().lower()
            for value in values
            if str(value).strip().lower() in AMENITY_ALIASES
        ))

    required = amenities("required_amenities")
    preferred = amenities("preferred_amenities")
    _promote_explicit_hard_amenities(query, required, preferred)
    preferred = [value for value in preferred if value not in required]

    flexibility = raw.get("flexibility") or {}
    if not isinstance(flexibility, dict):
        raise InvalidSearchRequirements("flexibility must be an object")
    move_in_date = str(raw.get("move_in_date") or "").strip()
    if move_in_date and not re.fullmatch(r"\d{4}-\d{2}", move_in_date):
        move_in_date = ""
    if move_in_date and not 1 <= int(move_in_date[5:7]) <= 12:
        move_in_date = ""
    keywords = raw.get("keywords") or []
    if not isinstance(keywords, list):
        raise InvalidSearchRequirements("keywords must be a list")
    required_keywords = raw.get("required_keywords") or []
    if not isinstance(required_keywords, list):
        raise InvalidSearchRequirements("required_keywords must be a list")
    required_keywords = list(dict.fromkeys(
        str(value).strip()[:80]
        for value in [*required_keywords, *([unsupported_category] if unsupported_category else [])]
        if str(value).strip()
    ))[:10]
    query_text = str(query or "").casefold()
    if re.search(r"\btownhouse\b", query_text) and "townhouse" not in required_keywords:
        required_keywords.append("townhouse")
    if (
        re.search(r"\b(?:a|single|one|student)\s+room\b|\broom\s+to\s+rent\b", query_text)
        and "room" not in required_keywords
    ):
        required_keywords.append("room")

    return {
        "listing_intent": listing_intent,
        "property_type": property_type,
        "locations": locations,
        "min_bedrooms": min_bedrooms,
        "max_bedrooms": max_bedrooms,
        "min_price": min_price,
        "max_price": max_price,
        "currency": "USD",
        "move_in_date": move_in_date,
        "required_amenities": required,
        "preferred_amenities": preferred,
        "required_keywords": required_keywords,
        "keywords": list(dict.fromkeys(
            str(value).strip()[:80]
            for value in keywords
            if str(value).strip()
        ))[:10],
        "flexibility": {
            "budget": bool(flexibility.get("budget", False)),
            "location": bool(flexibility.get("location", False)),
            "bedrooms": bool(flexibility.get("bedrooms", False)),
            "property_type": bool(flexibility.get("property_type", False)),
        },
        "clarification_question": str(raw.get("clarification_question") or "").strip()[:240],
    }


def _promote_explicit_hard_amenities(query, required, preferred):
    text = str(query or "").casefold()
    clauses = re.split(r"\b(?:but|however|although)\b|[,;.!?]", text)
    for clause in clauses:
        if re.search(r"\b(?:don't need|do not need|no need|not required|not a requirement)\b", clause):
            continue
        if not any(phrase in clause for phrase in HARD_PHRASES):
            continue
        for amenity, aliases in AMENITY_ALIASES.items():
            if any(alias in clause for alias in aliases):
                if amenity not in required:
                    required.append(amenity)
                if amenity in preferred:
                    preferred.remove(amenity)


def _amenity_present(prop, amenity):
    field_name = AMENITY_FIELDS.get(amenity)
    if field_name:
        value = getattr(prop, field_name)
        if amenity in {"title_deed", "serviced"}:
            return value not in {"", "not_provided", "not_serviced"}
        return bool(value)
    if amenity == "parking":
        text = str(prop.parking or "").strip().casefold()
        return bool(text) and text not in {"none", "no", "n/a", "not available"} and not re.search(
            r"\b(?:no|not|without|unavailable)\b.{0,20}\b(?:parking|garage|carport)\b",
            text,
        )
    text = " ".join(
        [prop.title, prop.description, prop.address, prop.city, prop.suburb,
         prop.water_availability, prop.parking]
    ).casefold()
    if amenity == "water":
        if re.search(
            r"\b(?:water|borehole)\b.{0,20}\b(?:not available|unavailable|no|without)\b",
            text,
        ):
            return False
        return bool(
            prop.borehole
            or prop.land_water_available
            or any(term in text for term in ("water available", "reliable water", "municipal water"))
        )
    if amenity == "security":
        if re.search(
            r"\b(?:no|not|without|lacks?)\b.{0,20}\b(?:security|secure|gated)\b",
            text,
        ):
            return False
        return any(term in text for term in ("security", "secure", "gated"))
    return False


def _location_matches(prop, locations):
    requested = {value.casefold() for value in locations}
    return bool(
        requested
        and (
            prop.city.casefold() in requested
            or prop.suburb.casefold() in requested
        )
    )


def _price_matches(prop, requirements):
    price = prop.monthly_rent
    minimum = requirements.get("min_price")
    maximum = requirements.get("max_price")
    return (
        (minimum is None or price >= Decimal(minimum))
        and (maximum is None or price <= Decimal(maximum))
    )


def _hard_requirements_match(prop, requirements, location_match, budget_match):
    flexibility = requirements["flexibility"]
    if not flexibility["location"] and requirements["locations"] and not location_match:
        return False
    if not flexibility["budget"] and (
        requirements["min_price"] is not None or requirements["max_price"] is not None
    ) and not budget_match:
        return False
    if not flexibility["bedrooms"]:
        if requirements["min_bedrooms"] is not None and prop.bedrooms < requirements["min_bedrooms"]:
            return False
        if requirements["max_bedrooms"] is not None and prop.bedrooms > requirements["max_bedrooms"]:
            return False
    if (
        not flexibility["property_type"]
        and requirements["property_type"] != "unspecified"
        and prop.property_type != requirements["property_type"]
    ):
        return False
    if requirements["move_in_date"] and prop.available_from:
        year, month = (int(part) for part in requirements["move_in_date"].split("-"))
        if (prop.available_from.year, prop.available_from.month) > (year, month):
            return False
    listing_text = " ".join(
        [prop.title, prop.description, prop.address, prop.city, prop.suburb]
    ).casefold()
    if any(keyword.casefold() not in listing_text for keyword in requirements["required_keywords"]):
        return False
    return all(_amenity_present(prop, amenity) for amenity in requirements["required_amenities"])


def rank_property_search(queryset, requirements, limit=40):
    weights = settings.PROPERTY_SEARCH_MATCH_WEIGHTS
    ranked = []
    total_exact = 0
    total_close = 0
    for prop in queryset.iterator(chunk_size=100):
        location_match = _location_matches(prop, requirements["locations"])
        budget_match = _price_matches(prop, requirements)
        property_checks = []
        if requirements["property_type"] != "unspecified":
            property_checks.append(prop.property_type == requirements["property_type"])
        if requirements["min_bedrooms"] is not None:
            property_checks.append(prop.bedrooms >= requirements["min_bedrooms"])
        if requirements["max_bedrooms"] is not None:
            property_checks.append(prop.bedrooms <= requirements["max_bedrooms"])
        listing_text = " ".join(
            [prop.title, prop.description, prop.address, prop.city, prop.suburb]
        ).casefold()
        property_checks.extend(
            keyword.casefold() in listing_text
            for keyword in requirements["required_keywords"]
        )
        property_score = (
            sum(property_checks) / len(property_checks) if property_checks else None
        )
        amenity_checks = [
            _amenity_present(prop, item)
            for item in requirements["required_amenities"] + requirements["preferred_amenities"]
        ]
        amenity_score = (
            sum(amenity_checks) / len(amenity_checks) if amenity_checks else None
        )
        components = {
            "budget": (
                float(budget_match)
                if requirements["min_price"] is not None or requirements["max_price"] is not None
                else None
            ),
            "location": (
                float(location_match) if requirements["locations"] else None
            ),
            "property": property_score,
            "amenities": amenity_score,
            "availability": 1.0,
        }
        active_weight = sum(weights[key] for key, score in components.items() if score is not None)
        score = round(
            sum(
                weights[key] * component
                for key, component in components.items()
                if component is not None
            )
            * 100
            / active_weight
        ) if active_weight else 100

        reasons = []
        missing = []
        missing_preferences = []
        if requirements["min_price"] is not None or requirements["max_price"] is not None:
            if budget_match:
                reasons.append("Within your budget")
            elif requirements["flexibility"]["budget"]:
                reasons.append("Above your flexible budget")
            else:
                missing.append("Outside your stated budget")
        if requirements["locations"]:
            if location_match:
                reasons.append(f"Located in {prop.suburb or prop.city}")
            elif requirements["flexibility"]["location"]:
                reasons.append("Outside your preferred areas")
            else:
                missing.append(f"Outside your preferred areas ({', '.join(requirements['locations'])})")
        if requirements["property_type"] != "unspecified":
            if prop.property_type == requirements["property_type"]:
                reasons.append(f"Matches your {prop.get_property_type_display().lower()} preference")
            elif requirements["flexibility"]["property_type"]:
                reasons.append(f"Different property type: {prop.get_property_type_display().lower()}")
            else:
                missing.append(f"Not the requested {requirements['property_type'].replace('_', ' ')} type")
        if requirements["min_bedrooms"] is not None:
            if prop.bedrooms >= requirements["min_bedrooms"]:
                reasons.append(f"Has {prop.bedrooms} bedrooms")
            elif requirements["flexibility"]["bedrooms"]:
                reasons.append(f"Has fewer than {requirements['min_bedrooms']} bedrooms")
            else:
                missing.append(f"Needs at least {requirements['min_bedrooms']} bedrooms")
        if requirements["max_bedrooms"] is not None and prop.bedrooms > requirements["max_bedrooms"]:
            message = f"Has more than {requirements['max_bedrooms']} bedrooms"
            (
                missing_preferences
                if requirements["flexibility"]["bedrooms"]
                else missing
            ).append(message)
        if requirements["move_in_date"]:
            if prop.available_from and (
                prop.available_from.year,
                prop.available_from.month,
            ) > tuple(int(part) for part in requirements["move_in_date"].split("-")):
                missing.append(f"Unavailable by {requirements['move_in_date']}")
            else:
                reasons.append(f"Available by {requirements['move_in_date']}")
        for amenity in requirements["required_amenities"]:
            if _amenity_present(prop, amenity):
                reasons.append(f"{amenity.replace('_', ' ').title()} available")
            else:
                missing.append(f"Does not confirm {amenity.replace('_', ' ')}")
        for amenity in requirements["preferred_amenities"]:
            if _amenity_present(prop, amenity):
                reasons.append(f"Has preferred {amenity.replace('_', ' ')}")
            else:
                missing_preferences.append(
                    f"Does not confirm preferred {amenity.replace('_', ' ')}"
                )
        for keyword in requirements["required_keywords"]:
            if keyword.casefold() in listing_text:
                reasons.append(f"Listing confirms {keyword}")
            else:
                missing.append(f"Does not confirm {keyword}")
        for keyword in requirements["keywords"]:
            if keyword.casefold() in listing_text:
                reasons.append(f"Listing mentions {keyword}")
            else:
                missing_preferences.append(f"Does not mention {keyword}")

        exact = _hard_requirements_match(prop, requirements, location_match, budget_match)
        if exact:
            total_exact += 1
        else:
            total_close += 1
        ranked.append({
            "property": prop,
            "score": score,
            "match_type": "exact" if exact else "close",
            "reasons": reasons,
            "missing_requirements": missing,
            "missing_preferences": missing_preferences,
        })

    ranked.sort(
        key=lambda item: (
            item["match_type"] != "exact",
            -item["score"],
            -item["property"].updated_at.timestamp(),
        )
    )
    return ranked[:limit], total_exact, total_close
