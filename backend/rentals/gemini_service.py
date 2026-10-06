import json
from urllib import error, request

from django.conf import settings


class GeminiConfigurationError(Exception):
    pass


class GeminiServiceError(Exception):
    pass


class GeminiService:
    PROPERTY_TYPE_VALUES = [
        "house",
        "flat",
        "cottage",
        "student_accommodation",
        "commercial_property",
        "land",
        "unspecified",
    ]
    AMENITY_VALUES = [
        "solar_power",
        "borehole",
        "parking",
        "water",
        "furnished",
        "pet_friendly",
        "electricity",
        "title_deed",
        "serviced",
        "security",
    ]

    @classmethod
    def parse_property_search(cls, query, previous_requirements=None):
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            raise GeminiConfigurationError("GEMINI_API_KEY is not configured")

        schema = {
            "type": "OBJECT",
            "properties": {
                "listing_intent": {
                    "type": "STRING",
                    "enum": ["rent", "sale"],
                },
                "property_type": {
                    "type": "STRING",
                    "enum": cls.PROPERTY_TYPE_VALUES,
                },
                "locations": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "min_bedrooms": {"type": "INTEGER", "nullable": True},
                "max_bedrooms": {"type": "INTEGER", "nullable": True},
                "min_price": {"type": "NUMBER", "nullable": True},
                "max_price": {"type": "NUMBER", "nullable": True},
                "currency": {"type": "STRING", "enum": ["USD"]},
                "move_in_date": {"type": "STRING"},
                "required_amenities": {
                    "type": "ARRAY",
                    "items": {"type": "STRING", "enum": cls.AMENITY_VALUES},
                },
                "preferred_amenities": {
                    "type": "ARRAY",
                    "items": {"type": "STRING", "enum": cls.AMENITY_VALUES},
                },
                "required_keywords": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "keywords": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "flexibility": {
                    "type": "OBJECT",
                    "properties": {
                        "budget": {"type": "BOOLEAN"},
                        "location": {"type": "BOOLEAN"},
                        "bedrooms": {"type": "BOOLEAN"},
                        "property_type": {"type": "BOOLEAN"},
                    },
                    "required": [
                        "budget",
                        "location",
                        "bedrooms",
                        "property_type",
                    ],
                },
                "clarification_question": {"type": "STRING"},
            },
            "required": [
                "listing_intent",
                "property_type",
                "locations",
                "min_bedrooms",
                "max_bedrooms",
                "min_price",
                "max_price",
                "currency",
                "move_in_date",
                "required_amenities",
                "preferred_amenities",
                "required_keywords",
                "keywords",
                "flexibility",
                "clarification_question",
            ],
        }
        system_instruction = (
            "Convert the user's property request into search requirements for a "
            "Zimbabwe property marketplace. Return only schema-conforming JSON. "
            "Use only the supplied property categories and amenities. Map "
            "apartment/flat to flat, stand/plot to land. Do not invent "
            "neighborhood relationships, property facts, or search results. "
            "Use USD for prices when no currency is stated. Treat explicit "
            "must-have, need, required, only-show, and non-negotiable features "
            "as required_amenities; softer preference language belongs in "
            "preferred_amenities. If a requested property category is not in "
            "the supplied enums, use unspecified and add that category to "
            "required_keywords. For a follow-up, revise the previous "
            "requirements and preserve fields the user did not change. Leave "
            "unspecified numeric values null, property_type as unspecified, "
            "move_in_date and clarification_question empty when not applicable. "
            "Only ask one concise clarification when a useful search cannot "
            "reasonably be run."
        )
        content = {
            "systemInstruction": {
                "parts": [{"text": system_instruction}],
            },
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {
                            "text": json.dumps(
                                {
                                    "query": query,
                                    "previous_requirements": previous_requirements,
                                },
                                ensure_ascii=False,
                            ),
                        }
                    ],
                }
            ],
            "generationConfig": {
                "temperature": 0,
                "responseMimeType": "application/json",
                "responseSchema": schema,
            },
        }
        endpoint = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.GEMINI_MODEL}:generateContent"
        )
        req = request.Request(
            endpoint,
            data=json.dumps(content).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": api_key,
            },
            method="POST",
        )
        try:
            with request.urlopen(
                req,
                timeout=settings.GEMINI_TIMEOUT_SECONDS,
            ) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            raise GeminiServiceError(
                f"Gemini returned HTTP {exc.code}"
            ) from None
        except (error.URLError, TimeoutError, OSError) as exc:
            raise GeminiServiceError(
                "Gemini could not be reached; try again shortly"
            ) from exc
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise GeminiServiceError("Gemini returned an invalid response") from exc

        try:
            text = payload["candidates"][0]["content"]["parts"][0]["text"]
            parsed = json.loads(text)
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            raise GeminiServiceError(
                "Gemini returned an incomplete property-search response"
            ) from exc
        if not isinstance(parsed, dict):
            raise GeminiServiceError("Gemini returned invalid search requirements")
        return parsed
