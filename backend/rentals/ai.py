import hashlib
import json
import re
from decimal import Decimal, InvalidOperation

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


def triage_maintenance_payload(data):
    text = " ".join(str(data.get(field, "")) for field in ["issue", "category", "description"]).lower()
    urgent_terms = ["fire", "spark", "electric shock", "burst", "flood", "sewage", "roof leak", "no power", "no water"]
    high_terms = ["leak", "blocked", "broken", "security", "gate", "geyser"]
    flags = []
    priority = "normal"
    if any(term in text for term in urgent_terms):
        priority = "urgent"
        flags.append("possible_emergency")
    elif any(term in text for term in high_terms):
        priority = "high"
        flags.append("needs_fast_followup")

    category = data.get("category") or infer_maintenance_category(text)
    return ai_result(
        analysis_type="maintenance_triage",
        score={"normal": 30, "high": 65, "urgent": 90}[priority],
        confidence=0.73,
        flags=flags,
        recommendation=priority,
        summary=f"Suggested priority is {priority}.",
        extra={"suggested_category": category},
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
        history = tenant.digital_rental_history or []
        on_time_payments = sum(1 for item in history if item.get("status") in {"paid_on_time", "received"})
        late_payments = sum(1 for item in history if item.get("status") in {"late", "missed"})
        score += min(25, on_time_payments * 5)
        score -= min(30, late_payments * 10)
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
        summary="Tenant application scored from profile, rental history, and affordability signals.",
    )


def generate_lease_text(lease):
    return (
        "Residential Lease Agreement\n\n"
        f"Landlord: {lease.landlord}\n"
        f"Tenant: {lease.tenant}\n"
        f"Property: {lease.property.address}\n"
        f"Monthly Rent: ${lease.monthly_rent}\n"
        f"Deposit: ${lease.deposit}\n"
        f"Lease: {lease.term}\n"
        f"Start Date: {lease.start_date}\n"
        f"End Date: {lease.end_date}\n\n"
        "Core Terms:\n"
        "1. Rent is due monthly through the recorded payment methods supported by the platform.\n"
        "2. The deposit is held against damages, unpaid rent, and agreed end-of-lease obligations.\n"
        "3. Maintenance requests must be logged digitally with category, description, and photos where available.\n"
        "4. Both parties may sign electronically, and signed activity is retained in the platform audit history.\n"
        "5. This generated draft should be reviewed against local legal requirements before production use."
    )


def infer_maintenance_category(text):
    if re.search(r"pipe|sink|toilet|water|sewage|drain|leak|geyser", text):
        return "plumbing"
    if re.search(r"power|plug|spark|light|electric|breaker", text):
        return "electricity"
    if re.search(r"roof|ceiling|gutter", text):
        return "roofing"
    if re.search(r"paint|wall|ceiling stain", text):
        return "painting"
    return "general_repairs"


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
