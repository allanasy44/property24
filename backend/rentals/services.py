from django.db import transaction
from django.utils import timezone

from .models import Application, Conversation, DisputeReport, LeaseAgreement, MaintenanceRequest, Message, Payment, Property, Review, VerificationRequest, Viewing


@transaction.atomic
def create_property(cleaned_data):
    return Property.objects.create(
        owner=cleaned_data["owner_id"],
        agent=cleaned_data.get("agent_id"),
        title=cleaned_data["title"],
        description=cleaned_data.get("description", ""),
        address=cleaned_data["address"],
        city=cleaned_data["city"],
        suburb=cleaned_data["suburb"],
        latitude=cleaned_data.get("latitude"),
        longitude=cleaned_data.get("longitude"),
        monthly_rent=cleaned_data.get("monthly_rent") or cleaned_data["price"],
        deposit_required=cleaned_data.get("deposit_required") or cleaned_data["deposit"],
        property_type=cleaned_data.get("property_type") or cleaned_data.get("type") or Property.PropertyType.HOUSE,
        bedrooms=cleaned_data["bedrooms"],
        bathrooms=cleaned_data["bathrooms"],
        furnished=cleaned_data.get("furnished", False),
        water_availability=cleaned_data.get("water_availability") or cleaned_data.get("water", ""),
        solar_power=cleaned_data.get("solar_power", False),
        borehole=cleaned_data.get("borehole", False),
        parking=cleaned_data.get("parking", ""),
        pet_friendly=cleaned_data.get("pet_friendly", False),
        has_360_tour=cleaned_data.get("has_360_tour", False),
        listing_status=cleaned_data.get("listing_status") or Property.ListingStatus.PENDING_VERIFICATION,
    )


def update_property(prop, cleaned_data):
    for field, value in cleaned_data.items():
        if value not in (None, ""):
            setattr(prop, field, value)
    prop.save()
    return prop


def record_property_view(prop):
    prop.views_count += 1
    prop.save(update_fields=["views_count"])
    return prop.views_count


def submit_application(cleaned_data):
    application, _ = Application.objects.update_or_create(
        property=cleaned_data["property_id"],
        tenant=cleaned_data["tenant_id"],
        defaults={
            "status": cleaned_data.get("status") or Application.Status.SUBMITTED,
            "score": cleaned_data.get("score") or 0,
            "message": cleaned_data.get("message", ""),
        },
    )
    return application


def record_payment(cleaned_data):
    status = cleaned_data.get("status") or Payment.Status.RECEIVED
    return Payment.objects.create(
        tenant=cleaned_data["tenant_id"],
        property=cleaned_data["property_id"],
        amount=cleaned_data["amount"],
        method=cleaned_data["method"],
        status=status,
        provider_reference=cleaned_data.get("provider_reference", ""),
        receipt_number=cleaned_data.get("receipt_number") or make_receipt_number(),
        reminder_status=cleaned_data.get("reminder_status", "Next reminder scheduled"),
        due_date=cleaned_data.get("due_date"),
        paid_at=timezone.now() if status == Payment.Status.RECEIVED else None,
    )


def create_lease(cleaned_data):
    prop = cleaned_data["property_id"]
    return LeaseAgreement.objects.create(
        property=prop,
        tenant=cleaned_data["tenant_id"],
        landlord=cleaned_data.get("landlord_id") or prop.owner,
        start_date=cleaned_data["start_date"],
        end_date=cleaned_data["end_date"],
        monthly_rent=cleaned_data.get("monthly_rent") or prop.monthly_rent,
        deposit=cleaned_data.get("deposit") or prop.deposit_required,
        term=cleaned_data.get("term") or "12 Months",
        status=cleaned_data.get("status") or LeaseAgreement.Status.AWAITING_SIGNATURES,
    )


def sign_lease(lease, signed_by):
    if signed_by == "tenant":
        lease.signed_by_tenant = True
        lease.tenant_signed_at = timezone.now()
    else:
        lease.signed_by_landlord = True
        lease.landlord_signed_at = timezone.now()
    lease.save()
    return lease


def create_maintenance_request(cleaned_data):
    return MaintenanceRequest.objects.create(
        property=cleaned_data["property_id"],
        tenant=cleaned_data["tenant_id"],
        issue=cleaned_data["issue"],
        category=cleaned_data["category"],
        description=cleaned_data.get("description", ""),
        status=cleaned_data.get("status") or MaintenanceRequest.Status.OPEN,
        priority=cleaned_data.get("priority") or "normal",
    )


def submit_verification(cleaned_data):
    user = cleaned_data["user_id"]
    role = cleaned_data.get("role") or user.role
    return VerificationRequest.objects.create(
        user=user,
        role=role,
        national_id_number=cleaned_data.get("national_id_number", ""),
        phone_verified=cleaned_data.get("phone_verified", False),
        estate_agency_registration=cleaned_data.get("estate_agency_registration", ""),
        agency_name=cleaned_data.get("agency_name", ""),
        contact_details=cleaned_data.get("contact_details", ""),
        checks=cleaned_data.get("checks") or default_checks_for_role(role),
        status=cleaned_data.get("status") or VerificationRequest.Status.SUBMITTED,
    )


def review_verification(verification, cleaned_data):
    reviewer = cleaned_data.get("reviewed_by_id")
    if cleaned_data["status"] == VerificationRequest.Status.APPROVED:
        verification.approve(reviewer)
        return verification
    verification.status = cleaned_data["status"]
    verification.reviewed_by = reviewer
    verification.notes = cleaned_data.get("notes", verification.notes)
    verification.reviewed_at = timezone.now()
    verification.save()
    return verification


def create_viewing(cleaned_data):
    return Viewing.objects.create(
        property=cleaned_data["property_id"],
        tenant=cleaned_data["tenant_id"],
        agent=cleaned_data.get("agent_id"),
        scheduled_for=cleaned_data["scheduled_for"],
        status=cleaned_data.get("status") or Viewing.Status.PENDING,
        notes=cleaned_data.get("notes", ""),
    )


def create_conversation(cleaned_data):
    conversation = Conversation.objects.create(
        property=cleaned_data.get("property_id"),
        title=cleaned_data.get("title", ""),
        phone_numbers_revealed=cleaned_data.get("phone_numbers_revealed", False),
    )
    conversation.participants.set(cleaned_data["participant_ids"])
    return conversation


def create_message(conversation, cleaned_data):
    message = Message.objects.create(conversation=conversation, sender=cleaned_data["sender_id"], body=cleaned_data["body"])
    conversation.save(update_fields=["updated_at"])
    return message


def create_review(cleaned_data):
    return Review.objects.create(
        tenant=cleaned_data["tenant_id"],
        landlord=cleaned_data["landlord_id"],
        rating=cleaned_data["rating"],
        comment=cleaned_data.get("comment", ""),
    )


def create_report(cleaned_data):
    return DisputeReport.objects.create(
        reporter=cleaned_data["reporter_id"],
        property=cleaned_data.get("property_id"),
        subject=cleaned_data["subject"],
        description=cleaned_data["description"],
        status=cleaned_data.get("status") or DisputeReport.Status.OPEN,
    )


def make_receipt_number():
    return f"RCT-{timezone.now().strftime('%Y%m%d%H%M%S%f')}"


def default_checks_for_role(role):
    base_checks = ["Phone OTP verification", "ID front capture", "ID back capture", "Extracted ID confirmation", "Liveness check"]
    if role == "agent":
        return base_checks + ["Estate agency registration", "Agency information", "Contact details"]
    return base_checks
