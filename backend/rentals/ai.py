import hashlib
import json
import re
from decimal import Decimal, InvalidOperation

from django.utils import timezone
from django.conf import settings


SCAM_TERMS = {
    "urgent deposit",
    "send deposit",
    "viewing fee",
    "cash only",
    "whatsapp only",
    "no viewing",
    "too good",
    "agent fee before viewing",
}


def review_listing_payload(data, owner=None):
    text = " ".join(str(data.get(field, "")) for field in ["title", "description", "address", "city", "suburb"]).lower()
    monthly_rent = as_decimal(data.get("monthly_rent") or data.get("price"))
    deposit = as_decimal(data.get("deposit_required") or data.get("deposit"))

    flags = []
    score = 0
    if str(data.get("property_type") or data.get("type") or "").lower() == "land":
        land_checks = [
            ("missing_land_size", not data.get("land_size")),
            ("missing_stand_count", not data.get("stands_available")),
            ("title_deed_status_missing", not data.get("title_deed_status")),
            ("servicing_status_missing", not data.get("servicing_status")),
            ("zoning_missing", not data.get("zoning")),
        ]
        for flag, missing in land_checks:
            if missing:
                flags.append(flag)
                score += 8
    if owner is not None and not owner.is_verified:
        flags.append("owner_not_verified")
        score += 35
    if deposit and monthly_rent and deposit > monthly_rent * 2:
        flags.append("deposit_above_two_months_rent")
        score += 20
    if not data.get("address"):
        flags.append("missing_address")
        score += 15
    if not data.get("gps") and not (data.get("latitude") and data.get("longitude")):
        flags.append("missing_gps_location")
        score += 10
    if not data.get("photos"):
        flags.append("missing_property_photos")
        score += 10

    matched_terms = [term for term in SCAM_TERMS if term in text]
    if matched_terms:
        flags.extend(f"suspicious_phrase:{term}" for term in matched_terms)
        score += min(35, 12 * len(matched_terms))

    recommendation = "approve_with_manual_review"
    if score >= 70:
        recommendation = "reject_or_escalate"
    elif score >= 35:
        recommendation = "manual_review"

    return ai_result(
        analysis_type="listing_risk",
        score=min(score, 100),
        confidence=0.78 if flags else 0.64,
        flags=flags,
        recommendation=recommendation,
        summary="Listing reviewed for fake advert and scam deposit risk.",
    )


def score_application_payload(data, tenant=None):
    score = 50
    flags = []
    message = str(data.get("message", ""))
    if len(message.strip()) >= 80:
        score += 10
    else:
        flags.append("short_application_message")

    if tenant is not None:
        if not tenant.is_verified:
            flags.append("tenant_not_verified")
            score -= 8

    if data.get("monthly_income"):
        income = as_decimal(data["monthly_income"])
        rent = as_decimal(data.get("monthly_rent"))
        if income and rent and income < rent * 3:
            flags.append("income_below_three_times_rent")
            score -= 15

    score = max(0, min(score, 100))
    if score >= 75:
        recommendation = "strong_candidate"
    elif score >= 55:
        recommendation = "review_candidate"
    else:
        recommendation = "high_risk_candidate"

    return ai_result(
        analysis_type="application_score",
        score=score,
        confidence=0.69,
        flags=flags,
        recommendation=recommendation,
        summary="Tenant application scored from profile and affordability signals.",
    )



def property_insights(property_obj):
    """Explainable local scoring for trust, passport, and availability."""
    from .models import DisputeReport, VerificationRequest

    owner = property_obj.owner
    now = timezone.now()
    latest_verification = VerificationRequest.objects.filter(
        user=owner,
        status__in=[VerificationRequest.Status.VERIFIED, VerificationRequest.Status.APPROVED],
    ).order_by("-reviewed_at", "-submitted_at").first()
    location_verified = bool(
        (property_obj.latitude is not None and property_obj.longitude is not None)
        or (latest_verification and latest_verification.address_gps_confirmed)
    )
    freshness_days = (now - property_obj.updated_at).days if property_obj.updated_at else 999
    photos_present = property_obj.photos.exists()
    positive = [
        ("Identity verification", 20, bool(owner.is_verified), "Owner identity review"),
        ("Phone verified", 10, bool(owner.phone_verified), "Owner phone confirmation"),
        ("Email verified", 5, bool(owner.email_verified), "Owner email confirmation"),
        ("Property verification", 25, property_obj.is_verified, "Listing review status"),
        ("Location confirmed", 15, location_verified, "Coordinates or address review"),
        ("Listing freshness", 10, freshness_days <= 7, "Updated within the last 7 days"),
        ("Photos added", 5, photos_present, "Property photos available"),
    ]
    breakdown = [
        {"label": label, "score": points if complete else 0, "max_score": points, "complete": complete, "detail": detail}
        for label, points, complete, detail in positive
    ]
    reports = DisputeReport.objects.filter(property=property_obj)
    resolved_text = " ".join(
        f"{report.subject} {report.description}".lower()
        for report in reports.filter(status=DisputeReport.Status.RESOLVED)
    )
    penalty = 0
    penalties = []
    if "scam" in resolved_text or "fraud" in resolved_text:
        penalty += 40
        penalties.append("confirmed_scam_report")
    if "false property" in resolved_text or "misrepresentation" in resolved_text:
        penalty += 20
        penalties.append("false_property_information")
    if reports.filter(status=DisputeReport.Status.RESOLVED).count() >= 3:
        penalty += 15
        penalties.append("repeated_complaints")
    if not owner.is_verified:
        penalty += 5
        penalties.append("verification_expired_or_incomplete")
    review_required = reports.filter(status__in=[DisputeReport.Status.OPEN, DisputeReport.Status.REVIEWING]).exists()
    score = max(0, min(100, sum(item["score"] for item in breakdown) - penalty))

    confirmed_at = property_obj.availability_confirmed_at or property_obj.updated_at or property_obj.created_at
    status = property_obj.availability_status
    if status == property_obj.AvailabilityStatus.AVAILABLE:
        if property_obj.available_from and property_obj.available_from > timezone.localdate():
            available_date = property_obj.available_from
            availability_label = f"Available from {available_date.day} {available_date.strftime('%b')}"
            availability_state = "available_from"
        else:
            availability_label = "Available"
            availability_state = "available"
    else:
        availability_label = property_obj.get_availability_status_display()
        availability_state = status

    passport_seed = f"{property_obj.id}:{property_obj.city}:{property_obj.suburb}".encode("utf-8")
    passport_id = f"P24-{hashlib.sha1(passport_seed).hexdigest()[:8].upper()}"
    return {
        "passport_id": passport_id,
        "trust_score": score,
        "trust_breakdown": breakdown,
        "trust_penalties": penalties,
        "admin_review_required": review_required,
        "availability_label": availability_label,
        "availability_state": availability_state,
        "available_from": property_obj.available_from.isoformat() if property_obj.available_from else None,
        "last_confirmed_at": confirmed_at.isoformat() if confirmed_at else None,
        "availability_needs_confirmation": False,
        "availability_temporarily_hidden": False,
    }
SEARCH_STOP_WORDS = {
    "a", "an", "and", "at", "for", "from", "has", "have", "in", "is",
    "me", "near", "of", "on", "or", "please", "that", "the", "to", "with",
}
SEARCH_SYNONYMS = {
    "secure": {"security", "safe", "gated"},
    "safe": {"security", "secure", "gated"},
    "family": {"house", "secure", "garden"},
    "modern": {"new", "renovated", "solar"},
    "power": {"electricity", "solar", "backup"},
    "parking": {"garage", "carport"},
    "garden": {"yard", "outdoor"},
    "cheap": {"affordable", "budget", "low"},
    "furnished": {"furnished", "fully_furnished"},
    "student": {"student_accommodation", "flat", "room"},
    "office": {"office"},
    "shop": {"shop"},
    "room": {"room"},
}
SEARCH_CITIES = {
    "harare", "bulawayo", "mutare", "gweru", "masvingo", "kwekwe",
    "chitungwiza", "ruwa", "marondera", "victoria falls", "victoria_falls",
}


def parse_search_intent(query):
    text = re.sub(r"[^a-z0-9_\s.]", " ", str(query or "").lower())
    text = re.sub(r"\s+", " ", text).strip()
    land_query = bool(re.search(r"\b(land|stand|stands|plot|residential stand|farm)\b", text))
    sale_query = bool(re.search(r"\b(buy|sale|sell|buying|purchase|for sale)\b", text))
    intent = "sale" if sale_query or land_query else "rent"
    bedrooms = re.search(
        r"(\d+|one|two|three|four|five)\s*(?:bed|beds|bedroom|bedrooms)",
        text,
    )
    bedroom_value = bedrooms.group(1) if bedrooms else None
    bedroom_value = {
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
    }.get(bedroom_value, bedroom_value)
    budget = re.search(
        r"(?:under|below|less than|up to|max(?:imum)?|around|about|budget(?: of)?)\s*\$?\s*([0-9][0-9,]*(?:\.[0-9]+)?)",
        text,
    )
    if budget is None:
        budget = re.search(r"\$\s*([0-9][0-9,]*(?:\.[0-9]+)?)", text)
    size = re.search(r"(?:at least|minimum|min)[^0-9]{0,8}([0-9][0-9,]*(?:\.[0-9]+)?)\s*(sqm|m2|square metres?|hectares?|ha|acres?)", text)
    stands = re.search(r"(\d+)\s+(?:[a-z]+\s+){0,3}(?:stands?|plots?)", text)
    property_type = "land" if land_query else None
    for value in PropertyTypeValues:
        if value.replace("_", " ") in text:
            property_type = value
            break
    if "apartment" in text and "self catering apartment" not in text:
        property_type = "flat"
    city = next((value for value in SEARCH_CITIES if value in text), None)
    if city:
        city = city.replace("_", " ")
    features = []
    feature_terms = {
        "furnished": ("furnished",),
        "pet_friendly": ("pet friendly", "pets", "pet-friendly"),
        "solar_power": ("solar", "backup power"),
        "borehole": ("borehole",),
        "has_360_tour": ("360", "virtual tour"),
        "verified_only": ("verified", "trusted", "safe landlord"),
        "title_deed": ("title deed", "deed"),
        "serviced": ("serviced", "fully serviced"),
        "electricity": ("electricity", "zesa", "power lines"),
        "water": ("water", "municipal water"),
        "parking": ("parking", "garage", "carport"),
    }
    for feature, terms in feature_terms.items():
        if any(term in text for term in terms):
            features.append(feature)
    tokens = [token for token in text.replace("_", " ").split() if token not in SEARCH_STOP_WORDS]
    return {
        "query": str(query or "").strip(),
        "intent": intent,
        "city": city,
        "bedrooms_min": int(bedroom_value) if bedroom_value else None,
        "budget_max": str(budget.group(1)).replace(",", "") if budget else None,
        "land_size_min": str(size.group(1)).replace(",", "") if size else None,
        "land_size_unit": size.group(2).lower() if size else None,
        "stands_min": int(stands.group(1)) if stands else None,
        "property_type": property_type,
        "features": features,
        "water_reliability": bool(re.search(r"\b(reliable|reliability|constant|consistent|uninterrupted)\s+water\b", text))
        or "borehole" in text,
        "parking": bool(re.search(r"\b(parking|garage|carport)\b", text)),
        "quiet_area": bool(re.search(r"\b(quiet|peaceful|calm|low traffic|quiet area)\b", text)),
        "distance_to_town": "short"
        if re.search(r"\b(near|nearby|close to|not (?:too )?far from|walking distance|minutes from)\s+(town|the cbd|cbd|city centre|city center)\b", text)
        else None,
        "tokens": tokens[:32],
    }


PropertyTypeValues = (
    "self_catering_apartment",
    "corporate_event_space",
    "camping_glamping",
    "guest_house",
    "conference_venue",
    "wedding_venue",
    "holiday_home",
    "student_accommodation",
    "commercial_property",
    "function_hall",
    "party_venue",
    "lodge",
    "hotel",
    "resort",
    "cottage",
    "office",
    "house",
    "flat",
    "room",
    "shop",
    "garden",
    "land",
)


def _search_vector(text, dimensions=64):
    vector = [0.0] * dimensions
    tokens = re.findall(r"[a-z0-9]+", str(text).lower())
    expanded = list(tokens)
    for token in tokens:
        expanded.extend(SEARCH_SYNONYMS.get(token, ()))
    for token in expanded:
        digest = hashlib.sha1(token.encode("utf-8")).digest()
        index = int.from_bytes(digest[:2], "big") % dimensions
        vector[index] += 1.0
    length = sum(value * value for value in vector) ** 0.5
    return [value / length for value in vector] if length else vector


def _cosine(left, right):
    return sum(a * b for a, b in zip(left, right))


def rank_property_candidates(query, properties, limit=20):
    intent = parse_search_intent(query)
    query_vector = _search_vector(" ".join(intent["tokens"]))
    ranked = []
    for prop in properties:
        property_text = " ".join([
            prop.title, prop.description, prop.address, prop.city, prop.suburb,
            prop.property_type, prop.water_availability, prop.parking,
            getattr(prop, "stand_reference", ""), str(getattr(prop, "land_size", "")),
            getattr(prop, "land_size_unit", ""), getattr(prop, "title_deed_status", ""),
            getattr(prop, "servicing_status", ""), getattr(prop, "zoning", ""),
            getattr(prop, "road_access", ""),
            "land" if prop.property_type == "land" else "",
            "electricity" if getattr(prop, "electricity_available", False) else "",
            "water" if getattr(prop, "land_water_available", False) else "",
            " ".join(getattr(prop, "listing_categories", []) or []),
            " ".join(
                str(value)
                for value in (getattr(prop, "listing_details", {}) or {}).values()
                if value not in (None, "", False, 0)
            ),
            "furnished" if prop.furnished else "",
            "solar" if prop.solar_power else "",
            "borehole" if prop.borehole else "",
            "pet friendly" if prop.pet_friendly else "",
        ])
        semantic = max(0.0, _cosine(query_vector, _search_vector(property_text)))
        rules = 0.0
        reasons = []
        if prop.listing_intent == intent["intent"]:
            rules += 24
            reasons.append("matches your rent or sale preference")
        if prop.listing_status == "verified" and prop.owner.is_verified:
            rules += 18
            reasons.append("verified listing and owner")
        if prop.availability_status == "available":
            rules += 16
            reasons.append("currently available")
        if prop.property_type == "land" and intent.get("property_type") == "land":
            rules += 12
            reasons.append("matches the land or stand category")
            if getattr(prop, "land_size", None):
                rules += 5
            if getattr(prop, "title_deed_status", "") not in {"", "not_provided"}:
                rules += 5
            if getattr(prop, "servicing_status", "") not in {"", "not_serviced"}:
                rules += 5
        if prop.photos.exists():
            rules += 5
            reasons.append("has property photos")
        if intent.get("bedrooms_min") and prop.bedrooms >= intent["bedrooms_min"]:
            rules += 12
            reasons.append("meets your bedroom requirement")
        if intent.get("budget_max"):
            budget = as_decimal(intent["budget_max"])
            if budget and prop.monthly_rent <= budget:
                rules += 15
                reasons.append(f"fits your budget of ${budget.normalize()}")
            elif budget:
                rules -= 14
                reasons.append("is above your stated budget")
        if intent.get("parking"):
            has_parking = bool(str(prop.parking or "").strip()) and str(prop.parking).lower() not in {"none", "no", "n/a"}
            if has_parking:
                rules += 10
                reasons.append("parking is listed")
            else:
                rules -= 8
                reasons.append("parking is not confirmed")
        if intent.get("water_reliability"):
            water_text = f"{prop.water_availability} {prop.description}".lower()
            has_reliable_water = prop.borehole or getattr(prop, "land_water_available", False) or any(
                term in water_text for term in ("reliable", "constant", "consistent", "municipal", "available")
            )
            if has_reliable_water:
                rules += 10
                reasons.append("water availability is supported")
            else:
                rules -= 7
                reasons.append("water reliability is not confirmed")
        if intent.get("quiet_area"):
            location_text = f"{prop.title} {prop.description} {prop.suburb} {prop.address}".lower()
            if any(term in location_text for term in ("quiet", "peaceful", "calm", "low traffic", "cul-de-sac")):
                rules += 8
                reasons.append("quiet-area language is present")
        if intent.get("distance_to_town") == "short":
            location_text = f"{prop.title} {prop.description} {prop.suburb} {prop.address}".lower()
            if any(term in location_text for term in ("near cbd", "near town", "close to town", "minutes from", "walking distance")):
                rules += 8
                reasons.append("short town/CBD distance is described")
        for feature in intent["features"]:
            if feature == "furnished" and prop.furnished:
                rules += 8
            elif feature == "pet_friendly" and prop.pet_friendly:
                rules += 8
            elif feature == "solar_power" and prop.solar_power:
                rules += 8
            elif feature == "borehole" and prop.borehole:
                rules += 8
            elif feature == "has_360_tour" and prop.has_360_tour:
                rules += 8
            elif feature == "title_deed" and getattr(prop, "title_deed_status", "") not in {"", "not_provided"}:
                rules += 8
                reasons.append("has title documentation status")
            elif feature == "serviced" and getattr(prop, "servicing_status", "") not in {"", "not_serviced"}:
                rules += 8
                reasons.append("has servicing information")
            elif feature == "electricity" and getattr(prop, "electricity_available", False):
                rules += 6
                reasons.append("electricity is available")
            elif feature == "water" and getattr(prop, "land_water_available", False):
                rules += 6
                reasons.append("water is available")
        score = min(100, round(semantic * 42 + rules))
        ranked.append({"property": prop, "score": score, "reasons": reasons[:4]})
    return intent, sorted(ranked, key=lambda item: (-item["score"], -item["property"].updated_at.timestamp()))[:limit]


def search_explanation(query, intent, ranked):
    if not ranked:
        return "No live listings matched those requirements yet. Try widening the location, budget, or bedroom range."
    top = ranked[0]["property"].title
    filters = []
    if intent.get("city"):
        filters.append(intent["city"].title())
    if intent.get("bedrooms_min"):
        filters.append(f"{intent['bedrooms_min']}+ bedrooms")
    if intent.get("budget_max"):
        filters.append(f"up to {intent['budget_max']}")
    requested = []
    if intent.get("water_reliability"):
        requested.append("reliable water")
    if intent.get("parking"):
        requested.append("parking")
    if intent.get("quiet_area"):
        requested.append("a quiet area")
    if requested:
        filters.append(" and ".join(requested))
    detail = ", ".join(filters) or "your description"
    return f"I found {len(ranked)} live listing(s) matching {detail}. The strongest match is {top}."


def optional_llm_explanation(query, intent, ranked):
    if settings.AI_PROVIDER not in {"openai", "llm"} or not settings.OPENAI_API_KEY:
        return ""
    try:
        from urllib import request as urlrequest
        payload = json.dumps({
            "model": settings.AI_MODEL if not settings.AI_MODEL.startswith("property24-") else "gpt-4o-mini",
            "temperature": 0.1,
            "messages": [{
                "role": "user",
                "content": "Explain these property recommendations in one concise sentence. Do not invent facts. " + json.dumps({
                    "query": query,
                    "intent": intent,
                    "listings": [{"title": item["property"].title, "score": item["score"], "reasons": item["reasons"]} for item in ranked[:5]],
                }),
            }],
        }).encode("utf-8")
        request = urlrequest.Request(
            "https://api.openai.com/v1/chat/completions",
            data=payload,
            headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}", "Content-Type": "application/json"},
            method="POST",
        )
        with urlrequest.urlopen(request, timeout=4) as response:
            body = json.loads(response.read().decode("utf-8"))
        return str(body["choices"][0]["message"]["content"]).strip()
    except Exception:
        return ""


def ai_result(analysis_type, score, confidence, flags, recommendation, summary, extra=None):
    payload = {
        "provider": settings.AI_PROVIDER,
        "model": settings.AI_MODEL,
        "analysis_type": analysis_type,
        "score": score,
        "confidence": confidence,
        "flags": flags,
        "recommendation": recommendation,
        "summary": summary,
    }
    if extra:
        payload.update(extra)
    payload["fingerprint"] = hashlib.sha256(json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()[:16]
    return payload


def as_decimal(value):
    if value in (None, ""):
        return None
    try:
        return Decimal(re.sub(r"[^0-9.]", "", str(value)) or "0")
    except (InvalidOperation, TypeError):
        return None
