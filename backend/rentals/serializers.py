def serialize_user(user):
    return {
        "id": user.id,
        "name": str(user),
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
        "verified": user.is_verified,
        "profile_picture": account_media_url(user, "profile_picture"),
        "cover_photo": account_media_url(user, "cover_photo"),
        "bio": user.bio,
        "last_seen_at": user.last_seen_at.isoformat() if user.last_seen_at else None,
    }


def account_media_url(user, field_name):
    external_url = getattr(user, f"{field_name}_url", "")
    if external_url:
        return external_url
    media_file = getattr(user, field_name, None)
    if media_file:
        try:
            return media_file.url
        except ValueError:
            return ""
    return ""


def serialize_property(prop):
    return {
        "id": prop.id,
        "owner": serialize_user(prop.owner),
        "agent": serialize_user(prop.agent) if prop.agent else None,
        "title": prop.title,
        "description": prop.description,
        "address": prop.address,
        "city": prop.city,
        "suburb": prop.suburb,
        "gps": f"{prop.latitude}, {prop.longitude}" if prop.latitude is not None and prop.longitude is not None else "",
        "monthly_rent": str(prop.monthly_rent),
        "deposit_required": str(prop.deposit_required),
        "property_type": prop.property_type,
        "bedrooms": prop.bedrooms,
        "bathrooms": str(prop.bathrooms),
        "furnished": prop.furnished,
        "water_availability": prop.water_availability,
        "solar_power": prop.solar_power,
        "borehole": prop.borehole,
        "parking": prop.parking,
        "pet_friendly": prop.pet_friendly,
        "has_360_tour": prop.has_360_tour,
        "verified": prop.is_verified and prop.owner.is_verified,
        "listing_status": prop.listing_status,
        "photos": [photo.image.url if photo.image else photo.caption for photo in prop.photos.all()],
        "videos": [video.external_url or (video.video.url if video.video else video.caption) for video in prop.videos.all()],
        "listing_views": prop.views_count,
        "saved_count": prop.saved_count or prop.saved_by.count(),
        "applications_count": getattr(prop, "application_total", prop.applications.count()),
    }


def serialize_application(application):
    return {
        "id": application.id,
        "property_id": application.property_id,
        "property": application.property.title,
        "tenant_id": application.tenant_id,
        "tenant": str(application.tenant),
        "status": application.status,
        "score": application.score,
        "message": application.message,
        "created_at": application.created_at.isoformat(),
    }


def serialize_payment(payment):
    return {
        "id": payment.id,
        "tenant_id": payment.tenant_id,
        "tenant": str(payment.tenant),
        "property_id": payment.property_id,
        "property": payment.property.title,
        "amount": str(payment.amount),
        "method": payment.method,
        "status": payment.status,
        "provider_reference": payment.provider_reference,
        "receipt_number": payment.receipt_number,
        "reminder_status": payment.reminder_status,
        "paid_at": payment.paid_at.isoformat() if payment.paid_at else None,
    }


def serialize_lease(lease):
    return {
        "id": lease.id,
        "property_id": lease.property_id,
        "property": lease.property.address,
        "tenant_id": lease.tenant_id,
        "tenant": str(lease.tenant),
        "landlord_id": lease.landlord_id,
        "landlord": str(lease.landlord),
        "start_date": serialize_date(lease.start_date),
        "end_date": serialize_date(lease.end_date),
        "monthly_rent": str(lease.monthly_rent),
        "deposit": str(lease.deposit),
        "term": lease.term,
        "contract_text": lease.contract_text,
        "pdf": lease.pdf.url if lease.pdf else "",
        "status": lease.status,
        "signed_by_tenant": lease.signed_by_tenant,
        "signed_by_landlord": lease.signed_by_landlord,
    }


def serialize_maintenance(ticket):
    return {
        "id": ticket.id,
        "property_id": ticket.property_id,
        "property": ticket.property.title,
        "tenant_id": ticket.tenant_id,
        "tenant": str(ticket.tenant),
        "issue": ticket.issue,
        "category": ticket.category,
        "description": ticket.description,
        "photo": ticket.photo.url if ticket.photo else "",
        "status": ticket.status,
        "priority": ticket.priority,
        "updated_at": ticket.updated_at.isoformat(),
    }


def serialize_verification(verification):
    return {
        "id": verification.id,
        "user_id": verification.user_id,
        "name": str(verification.user),
        "role": verification.role,
        "checks": verification.checks,
        "phone_verified": verification.phone_verified,
        "status": verification.status,
        "reviewed_by": str(verification.reviewed_by) if verification.reviewed_by else "",
        "submitted_at": verification.submitted_at.isoformat(),
        "reviewed_at": verification.reviewed_at.isoformat() if verification.reviewed_at else None,
    }


def serialize_viewing(viewing):
    return {
        "id": viewing.id,
        "property_id": viewing.property_id,
        "property": viewing.property.title,
        "tenant_id": viewing.tenant_id,
        "tenant": str(viewing.tenant),
        "agent_id": viewing.agent_id,
        "agent": str(viewing.agent) if viewing.agent else "",
        "scheduled_for": serialize_date(viewing.scheduled_for),
        "status": viewing.status,
        "notes": viewing.notes,
    }


def serialize_conversation(conversation):
    messages = list(conversation.messages.all())
    return {
        "id": conversation.id,
        "property_id": conversation.property_id,
        "title": conversation.title,
        "participants": [serialize_user(user) for user in conversation.participants.all()],
        "phone_numbers_revealed": conversation.phone_numbers_revealed,
        "last_message": serialize_message(messages[-1]) if messages else None,
        "updated_at": conversation.updated_at.isoformat(),
    }


def serialize_message(message):
    return {
        "id": message.id,
        "conversation_id": message.conversation_id,
        "sender_id": message.sender_id,
        "sender": str(message.sender),
        "body": message.body,
        "created_at": message.created_at.isoformat(),
    }


def serialize_review(review):
    return {
        "id": review.id,
        "tenant_id": review.tenant_id,
        "tenant": str(review.tenant),
        "landlord_id": review.landlord_id,
        "landlord": str(review.landlord),
        "rating": review.rating,
        "comment": review.comment,
        "created_at": review.created_at.isoformat(),
    }


def serialize_report(report):
    return {
        "id": report.id,
        "reporter_id": report.reporter_id,
        "reporter": str(report.reporter),
        "property_id": report.property_id,
        "subject": report.subject,
        "description": report.description,
        "status": report.status,
        "assigned_admin": str(report.assigned_admin) if report.assigned_admin else "",
        "created_at": report.created_at.isoformat(),
    }


def serialize_date(value):
    return value.isoformat() if hasattr(value, "isoformat") else str(value)
