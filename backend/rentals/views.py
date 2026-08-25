import hashlib
import hmac
import json
import re
import uuid
from base64 import b64encode
from datetime import timedelta
from decimal import Decimal, InvalidOperation
from urllib import error as urlerror
from urllib import request as urlrequest
from urllib.parse import urlencode

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.files.images import get_image_dimensions
from django.core.mail import send_mail
from django.core.validators import validate_email as validate_email_value
from django.db import IntegrityError
from django.db import connection
from django.db.models import Count, Q, Sum
from django.db.models.functions import Coalesce
from django.http import JsonResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.crypto import get_random_string
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .models import (
    AIAnalysis,
    Application,
    CallSession,
    Commission,
    Conversation,
    DisputeReport,
    EmailVerificationOTP,
    LeaseAgreement,
    MaintenanceRequest,
    MediaAsset,
    Message,
    Payment,
    PendingRegistrationOTP,
    PhoneVerificationOTP,
    Property,
    PropertyComment,
    PropertyPhoto,
    PropertyVideo,
    Review,
    SavedProperty,
    SecurityAuditEvent,
    SupplierFollow,
    VerificationRequest,
    Viewing,
)
from .ai import review_listing_payload, score_application_payload, triage_maintenance_payload
from .auth import issue_token_pair, user_from_authorization_header, user_from_token
from .chat_services import (
    audit_event,
    block_chat_user,
    broadcast_to_conversation,
    create_call,
    create_chat_message,
    default_attachment_body,
    delete_chat_message,
    edit_chat_message,
    list_conversations_for_user,
    mark_conversation_delivered,
    mark_conversation_read,
    open_listing_conversation,
    register_push_device,
    report_chat_message,
)
from .google_auth import GoogleAuthError, verify_google_id_token
from .identity_verification import get_identity_verification_provider
from .media_services import (
    CHAT_MIME_TYPES,
    DOCUMENT_MIME_TYPES,
    IMAGE_MIME_TYPES,
    MAX_CHAT_ATTACHMENT_BYTES,
    MAX_DOCUMENT_BYTES,
    MAX_IMAGE_BYTES,
    MAX_VIDEO_BYTES,
    MediaValidationError,
    VIDEO_MIME_TYPES,
    delete_file,
    optimize_image_upload,
    register_media_asset,
    serialize_media_asset,
    signed_media_url,
    soft_delete_media_asset,
    validate_upload,
)
from .notification_services import send_call_push, send_chat_message_push
from .object_storage import object_storage_status


User = get_user_model()

PUBLIC_ACCOUNT_ROLES = {User.Roles.TENANT, User.Roles.LANDLORD}
VERIFICATION_REQUIRED_ROLES = {User.Roles.TENANT, User.Roles.LANDLORD, User.Roles.AGENT}
VERIFICATION_ALLOWED_PATH_SUFFIXES = ("/auth/me/", "/auth/profile/", "/verifications/", "/verifications/email-otp/", "/verifications/email-otp/verify/", "/verifications/id-extract/")
PASSWORD_MIN_LENGTH = 15
PASSWORD_MAX_LENGTH = 128
USERNAME_MAX_LENGTH = 150
EMAIL_MAX_LENGTH = 254
NAME_MAX_LENGTH = 160
PHONE_MAX_LENGTH = 16
CONTROL_CHAR_RE = re.compile(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]")
PHONE_RE = re.compile(r"^\+?\d{7,15}$")
ACCEPTED_ID_DOCUMENT_TYPES = {"identity_document"}
IDENTITY_IMAGE_MAX_BYTES = 8 * 1024 * 1024
IDENTITY_IMAGE_MIN_WIDTH = 500
IDENTITY_IMAGE_MIN_HEIGHT = 300
IDENTITY_IMAGE_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
IDENTITY_ACTIVE_STATUSES = {"pending", "processing", "ocr_complete", "validation", "verified", "manual_review", "submitted", "reviewing", "approved"}
GENERIC_DOCUMENT_NUMBER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 /-]{4,63}$")
MAX_PROPERTY_PHOTOS = 10

ROLE_CAPABILITIES = {
    User.Roles.TENANT: [
        "search_properties",
        "save_properties",
        "submit_tenant_verification",
        "apply_for_rentals",
        "pay_rent",
        "view_rental_history",
        "report_maintenance",
        "sign_leases",
        "message_landlord_or_agent",
    ],
    User.Roles.LANDLORD: [
        "add_properties",
        "upload_property_media",
        "submit_landlord_verification",
        "approve_tenants",
        "receive_rent",
        "manage_maintenance",
        "view_landlord_reports",
        "message_tenants",
    ],
    User.Roles.AGENT: [
        "list_properties",
        "submit_agent_verification",
        "schedule_viewings",
        "manage_landlords",
        "track_applications",
        "track_commissions",
        "message_clients",
    ],
    User.Roles.ADMIN: [
        "verify_users",
        "remove_fake_listings",
        "resolve_disputes",
        "manage_payments",
        "review_reports",
        "manage_all_accounts",
    ],
}

ROLE_VISIBLE_SECTIONS = {
    User.Roles.TENANT: ["search", "applications", "payments", "leases", "maintenance", "inbox", "profile", "verification"],
    User.Roles.LANDLORD: ["properties", "applications", "payments", "leases", "maintenance", "analytics", "inbox", "verification"],
    User.Roles.AGENT: ["properties", "viewings", "applications", "commissions", "inbox", "verification"],
    User.Roles.ADMIN: ["verifications", "reports", "payments", "users", "properties", "analytics"],
}

ROLE_ONBOARDING_REQUIREMENTS = {
    User.Roles.TENANT: ["email_verification"],
    User.Roles.LANDLORD: ["email_verification"],
    User.Roles.AGENT: ["email_verification"],
    User.Roles.ADMIN: [],
}


def health_check(request):
    database = {"status": "ok"}
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception as exc:
        database = {"status": "error", "detail": str(exc)}

    storage = object_storage_status()
    status = "ok" if database["status"] == "ok" and storage["status"] in {"ok", "disabled"} else "degraded"
    return JsonResponse(
        {
            "status": status,
            "service": "property24-rentals-api",
            "database": database,
            "object_storage": storage,
            "ai": {"provider": settings.AI_PROVIDER, "model": settings.AI_MODEL, "assisted_review": settings.AI_ASSISTED_REVIEW_ENABLED},
            "maps": {"provider": settings.MAP_PROVIDER},
        }
    )


def current_user(request):
    user, error = user_from_authorization_header(request.headers.get("Authorization", ""))
    if user and not error:
        now = timezone.now()
        if not user.last_seen_at or (now - user.last_seen_at).total_seconds() > 20:
            user.last_seen_at = now
            user.save(update_fields=["last_seen_at"])
    return user, error


def verification_access_allowed(request):
    path = request.path.rstrip("/") + "/"
    return any(path.endswith(suffix) for suffix in VERIFICATION_ALLOWED_PATH_SUFFIXES)


def require_authenticated(request):
    user, error = current_user(request)
    if error:
        return None, json_error(error, status=401)
    if request.method != "OPTIONS" and user.role in VERIFICATION_REQUIRED_ROLES and not account_onboarding_complete(user) and not verification_access_allowed(request):
        return None, json_error(
            "Email verification is required before using this feature",
            status=403,
            errors={"account_onboarding_required": True, "next_endpoint": "/api/verifications/email-otp/"},
        )
    return user, None


def require_roles(request, roles):
    user, response = require_authenticated(request)
    if response:
        return None, response
    if user.role not in set(roles):
        return None, json_error("You do not have permission to perform this action", status=403)
    return user, None


def is_admin(user):
    return bool(user) and user.role == User.Roles.ADMIN


def can_manage_property(user, prop):
    return is_admin(user) or prop.owner_id == user.id or prop.agent_id == user.id


def allowed_conversation_participant_ids(user, prop, requested_ids):
    if is_admin(user):
        ids = {int(value) for value in requested_ids if str(value).isdigit()}
        return ids or {prop.agent_id or prop.owner_id}

    if user.role == User.Roles.TENANT:
        if not is_publicly_contactable_listing(prop):
            return None
        return {prop.agent_id or prop.owner_id}

    if can_manage_property(user, prop):
        requested = {int(value) for value in requested_ids if str(value).isdigit()}
        allowed_tenants = set(Application.objects.filter(property=prop).values_list("tenant_id", flat=True))
        allowed_tenants.update(Viewing.objects.filter(property=prop).values_list("tenant_id", flat=True))
        if not requested or not requested.issubset(allowed_tenants):
            return None
        return requested

    return None


def is_publicly_contactable_listing(prop):
    return prop.is_verified and prop.owner.is_verified and (prop.agent_id is None or prop.agent.is_verified)


def public_listings(properties):
    return properties.filter(listing_status=Property.ListingStatus.VERIFIED, owner__is_verified=True).filter(Q(agent__isnull=True) | Q(agent__is_verified=True))


def user_properties(user):
    if is_admin(user):
        return Property.objects.all()
    if user.role == User.Roles.LANDLORD:
        return Property.objects.filter(owner=user)
    if user.role == User.Roles.AGENT:
        return Property.objects.filter(Q(agent=user) | Q(owner=user))
    return Property.objects.none()


def has_completed_viewing(tenant, prop):
    return Viewing.objects.filter(tenant=tenant, property=prop, status=Viewing.Status.COMPLETED).exists()


def has_approved_application(tenant, prop):
    return Application.objects.filter(tenant=tenant, property=prop, status=Application.Status.APPROVED).exists()


def active_lease_for(tenant, prop):
    return LeaseAgreement.objects.filter(tenant=tenant, property=prop, status=LeaseAgreement.Status.ACTIVE).first()


def payment_lifecycle_errors(tenant, prop):
    errors = []
    if not has_completed_viewing(tenant, prop):
        errors.append("Physical viewing must be completed in-app before deposit or rent payment")
    if not has_approved_application(tenant, prop):
        errors.append("Tenant application must be approved before payment")
    if not active_lease_for(tenant, prop):
        errors.append("Both parties must sign an active lease before payment")
    return errors


def maintenance_lifecycle_errors(tenant, prop):
    if active_lease_for(tenant, prop):
        return []
    return ["Maintenance is available only after the tenant has an active lease for this property"]


def application_lifecycle_errors(tenant, prop):
    if has_completed_viewing(tenant, prop):
        return []
    return ["Physical viewing must be completed before a tenant can apply for this property"]


def lease_lifecycle_errors(tenant, prop):
    errors = []
    if not has_completed_viewing(tenant, prop):
        errors.append("Physical viewing must be completed before lease generation")
    if not has_approved_application(tenant, prop):
        errors.append("Tenant application must be approved before lease generation")
    return errors


def forbidden():
    return json_error("You do not have permission to perform this action", status=403)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def auth_login(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    username = data.get("username") or data.get("email")
    password = data.get("password")
    if not username or not password:
        return json_error("username/email and password are required")

    user = authenticate(request, username=username, password=password)
    if user is None:
        candidate_query = Q(email__iexact=username)
        normalized_phone = normalize_phone(username)
        if normalized_phone:
            candidate_query |= phone_identity_query(normalized_phone)
        candidate = User.objects.filter(candidate_query).first()
        if candidate and candidate.check_password(password):
            user = candidate
    if user is None or not user.is_active:
        return json_error("Invalid credentials", status=401)

    return JsonResponse({"user": serialize_user(user), "tokens": issue_token_pair(user)})


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def auth_refresh(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    user, error = user_from_token(data.get("refresh", ""), expected_type="refresh")
    if error:
        return json_error(error, status=401)
    return JsonResponse({"user": serialize_user(user), "tokens": issue_token_pair(user)})


@require_http_methods(["GET", "OPTIONS"])
def auth_me(request):
    user, error = user_from_authorization_header(request.headers.get("Authorization", ""))
    if error:
        return json_error(error, status=401)
    return JsonResponse({"user": serialize_user(user), "account": serialize_account_context(user)})


@csrf_exempt
@require_http_methods(["POST", "PATCH", "OPTIONS"])
def auth_profile(request):
    user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")

    changed_fields = []
    text_updates = {
        "full_name": data.get("name") or data.get("full_name"),
        "bio": data.get("bio"),
        "profile_picture_url": data.get("profile_picture_url") or data.get("profile_picture"),
        "cover_photo_url": data.get("cover_photo_url") or data.get("cover_photo"),
    }
    for field, value in text_updates.items():
        if value is not None and getattr(user, field) != value:
            setattr(user, field, value)
            changed_fields.append(field)

    if to_bool(data.get("remove_profile_picture")):
        remove_media_assets("user", user.id, "profile_picture")
        if user.profile_picture:
            delete_file(user.profile_picture)
        user.profile_picture = ""
        user.profile_picture_url = ""
        changed_fields.extend(["profile_picture", "profile_picture_url"])
    if to_bool(data.get("remove_cover_photo")):
        remove_media_assets("user", user.id, "cover_photo")
        if user.cover_photo:
            delete_file(user.cover_photo)
        user.cover_photo = ""
        user.cover_photo_url = ""
        changed_fields.extend(["cover_photo", "cover_photo_url"])

    files = request.FILES if hasattr(request, "FILES") else {}
    try:
        if files.get("profile_picture"):
            upload = validate_upload(files["profile_picture"], allowed_types=IMAGE_MIME_TYPES, max_bytes=MAX_IMAGE_BYTES, label="Profile photo")
            remove_media_assets("user", user.id, "profile_picture")
            if user.profile_picture:
                delete_file(user.profile_picture)
            user.profile_picture = optimize_image_upload(upload)
            user.profile_picture_url = ""
            changed_fields.extend(["profile_picture", "profile_picture_url"])
        if files.get("cover_photo"):
            upload = validate_upload(files["cover_photo"], allowed_types=IMAGE_MIME_TYPES, max_bytes=MAX_IMAGE_BYTES, label="Cover photo")
            remove_media_assets("user", user.id, "cover_photo")
            if user.cover_photo:
                delete_file(user.cover_photo)
            user.cover_photo = optimize_image_upload(upload)
            user.cover_photo_url = ""
            changed_fields.extend(["cover_photo", "cover_photo_url"])
    except MediaValidationError as exc:
        return json_error(str(exc))

    if changed_fields:
        user.save(update_fields=sorted(set(changed_fields)))
        if "profile_picture" in changed_fields and user.profile_picture:
            register_media_asset(user, user.profile_picture, scope=MediaAsset.Scope.PROFILE, source_model="user", source_id=user.id, original_name="profile_picture", mime_type="image/jpeg", metadata={"slot": "profile_picture"})
        if "cover_photo" in changed_fields and user.cover_photo:
            register_media_asset(user, user.cover_photo, scope=MediaAsset.Scope.PROFILE, source_model="user", source_id=user.id, original_name="cover_photo", mime_type="image/jpeg", metadata={"slot": "cover_photo"})
    return JsonResponse({"user": serialize_user(user), "account": serialize_account_context(user)})


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def auth_register(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    user, error = create_public_account(data)
    if error:
        return json_error(error)

    return JsonResponse({"user": serialize_user(user), "account": serialize_account_context(user), "requires_sign_in": True}, status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def auth_register_verify(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    challenge_id = data.get("challenge_id") or data.get("registration_id")
    code = str(data.get("otp") or data.get("code") or "").strip()
    if not challenge_id or not code:
        return json_error("challenge_id and otp are required")

    challenge = PendingRegistrationOTP.objects.filter(pk=challenge_id, status=PendingRegistrationOTP.Status.PENDING).first()
    if challenge is None:
        return json_error("OTP challenge was not found or has already been used", status=404)
    if challenge.is_expired:
        challenge.status = PendingRegistrationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return json_error("OTP has expired. Create the account again to receive a new code")
    if challenge.attempts >= 5:
        challenge.status = PendingRegistrationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return json_error("Too many OTP attempts. Create the account again to receive a new code")
    if challenge.code_hash != hash_otp(code):
        challenge.attempts += 1
        challenge.save(update_fields=["attempts", "updated_at"])
        return json_error("Invalid OTP code")

    user, error = create_public_account_from_otp(challenge)
    if error:
        return json_error(error)

    challenge.status = PendingRegistrationOTP.Status.CONSUMED
    challenge.consumed_at = timezone.now()
    challenge.save(update_fields=["status", "consumed_at", "updated_at"])
    return JsonResponse({"user": serialize_user(user), "account": serialize_account_context(user), "tokens": issue_token_pair(user)}, status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def auth_google(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    token = data.get("id_token") or data.get("credential")
    if not token:
        return json_error("Google id_token is required")

    try:
        claims = verify_google_id_token(token)
    except GoogleAuthError as exc:
        return json_error(str(exc), status=401)

    user, error = create_google_account(claims, data)
    if error:
        return json_error(error)
    return JsonResponse({"user": serialize_user(user), "account": serialize_account_context(user), "tokens": issue_token_pair(user)})



@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def landlord_agents_collection(request):
    acting_user, auth_response = require_roles(request, {User.Roles.LANDLORD})
    if auth_response:
        return auth_response
    if not acting_user.is_verified:
        return json_error("Landlord verification is required before creating agents", status=403)

    if request.method == "GET":
        agents = User.objects.filter(role=User.Roles.AGENT).order_by("full_name", "email")
        return JsonResponse({"results": [serialize_user(agent) for agent in agents]})

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")

    email = normalize_email(data.get("email"))
    username = str(data.get("username") or email).strip()
    full_name = str(data.get("name") or data.get("full_name") or "").strip()
    phone = normalize_phone(data.get("phone"))
    password = data.get("password") or get_random_string(24)
    for error in (
        validate_text_field(username, "Username", USERNAME_MAX_LENGTH, required=True),
        validate_email_field(email, required=True),
        validate_text_field(full_name, "Full name", NAME_MAX_LENGTH, required=True),
        validate_phone_field(phone, required=False),
        validate_account_password(password),
    ):
        if error:
            return json_error(error)
    if User.objects.filter(Q(email__iexact=email) | Q(username__iexact=username) | Q(phone__in=phone_lookup_values(phone))).exists():
        return json_error("An account with these details already exists")

    try:
        agent = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            full_name=full_name,
            phone=phone,
            role=User.Roles.AGENT,
            is_verified=False,
        )
    except IntegrityError:
        return json_error("An account with these details already exists")
    return JsonResponse({"user": serialize_user(agent), "temporary_password_created": not bool(data.get("password"))}, status=201)

@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def users_collection(request):
    acting_user, auth_response = require_roles(request, {User.Roles.ADMIN})
    if auth_response:
        return auth_response

    if request.method == "GET":
        role = request.GET.get("role")
        users = User.objects.all().order_by("id")
        if role:
            users = users.filter(role=role)
        return JsonResponse({"results": [serialize_user(user) for user in users]})

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")

    username = data.get("username") or data.get("email")
    if not username:
        return json_error("username or email is required")

    user, error = create_public_account(data, require_password=False)
    if error:
        return json_error(error)
    return JsonResponse(serialize_user(user), status=201)


def user_rental_history(request, user_id):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or acting_user.id == user_id):
        return forbidden()

    user = get_object_or_404(User, pk=user_id)
    payments = Payment.objects.filter(tenant=user).select_related("property").order_by("-created_at")
    leases = LeaseAgreement.objects.filter(tenant=user).select_related("property", "landlord").order_by("-created_at")
    reviews = Review.objects.filter(tenant=user).select_related("landlord").order_by("-created_at")

    return JsonResponse(
        {
            "user": serialize_user(user),
            "payments": [serialize_payment(payment) for payment in payments],
            "leases": [serialize_lease(lease) for lease in leases],
            "reviews": [serialize_review(review) for review in reviews],
        }
    )


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def properties_collection(request):
    if request.method == "GET":
        properties = Property.objects.select_related("owner", "agent").prefetch_related("photos", "videos")
        acting_user = None
        if request.headers.get("Authorization"):
            acting_user, _ = current_user(request)
        if acting_user is None or acting_user.role == User.Roles.TENANT or to_bool(request.GET.get("public_only")):
            properties = public_listings(properties)
        properties = apply_property_filters(properties, request.GET)
        return JsonResponse({"results": [serialize_property(item) for item in properties.order_by("-created_at")]})

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")

    acting_user, auth_response = require_roles(request, {User.Roles.LANDLORD, User.Roles.AGENT, User.Roles.ADMIN})
    if auth_response:
        return auth_response

    if acting_user.role == User.Roles.LANDLORD:
        owner = acting_user
        agent = User.objects.filter(pk=data.get("agent_id"), role=User.Roles.AGENT).first() if data.get("agent_id") else None
    elif acting_user.role == User.Roles.AGENT:
        owner = User.objects.filter(pk=data.get("owner_id")).first() if data.get("owner_id") else acting_user
        if owner is None:
            return json_error("owner_id was not found")
        agent = acting_user
    else:
        owner = get_object_or_404(User, pk=data.get("owner_id"))
        agent = User.objects.filter(pk=data.get("agent_id")).first() if data.get("agent_id") else None
    if len(data.get("photos") or []) > MAX_PROPERTY_PHOTOS:
        return json_error(f"A property can have a maximum of {MAX_PROPERTY_PHOTOS} photos", status=400)

    listing_status = data.get("listing_status", Property.ListingStatus.PENDING_VERIFICATION) if is_admin(acting_user) else Property.ListingStatus.PENDING_VERIFICATION
    validation_error = validate_listing_participants(owner, agent, listing_status)
    if validation_error:
        return json_error(validation_error)

    ai_review = review_listing_payload(data, owner) if settings.AI_ASSISTED_REVIEW_ENABLED else None
    if ai_review and listing_status == Property.ListingStatus.VERIFIED and ai_review["score"] >= 70:
        return json_error("AI listing review flagged this listing for administrator review before verification")

    latitude, longitude = parse_coordinates(data)

    prop = Property.objects.create(
        owner=owner,
        agent=agent,
        title=data.get("title", ""),
        description=data.get("description", ""),
        address=data.get("address", ""),
        city=data.get("city", ""),
        suburb=data.get("suburb", ""),
        latitude=latitude,
        longitude=longitude,
        monthly_rent=parse_decimal(data.get("monthly_rent") or data.get("price"), "monthly_rent"),
        deposit_required=parse_decimal(data.get("deposit_required") or data.get("deposit"), "deposit_required"),
        property_type=normalise_choice(data.get("property_type") or data.get("type"), Property.PropertyType, Property.PropertyType.HOUSE),
        bedrooms=int(data.get("bedrooms", 0)),
        bathrooms=parse_decimal(data.get("bathrooms", 1), "bathrooms"),
        furnished=to_bool(data.get("furnished")),
        water_availability=data.get("water_availability") or data.get("water", ""),
        solar_power=to_bool(data.get("solar_power") or data.get("solarPower")),
        borehole=to_bool(data.get("borehole")),
        parking=data.get("parking", ""),
        pet_friendly=to_bool(data.get("pet_friendly") or data.get("petFriendly")),
        has_360_tour=to_bool(data.get("has_360_tour") or data.get("tourAvailable")),
        listing_status=listing_status,
    )

    create_property_media(prop, data)
    payload = serialize_property(prop)
    if ai_review:
        analysis = record_ai_analysis(ai_review, "property", prop.id)
        payload["ai_review"] = serialize_ai_analysis(analysis)
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["GET", "PATCH", "OPTIONS"])
def property_detail(request, property_id):
    prop = get_object_or_404(Property.objects.select_related("owner", "agent"), pk=property_id)
    if request.method == "GET":
        return JsonResponse(serialize_property(prop))

    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not can_manage_property(acting_user, prop):
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    owner = prop.owner
    agent = prop.agent
    if data.get("owner_id") and is_admin(acting_user):
        owner = get_object_or_404(User, pk=data["owner_id"])
    if data.get("agent_id") and is_admin(acting_user):
        agent = get_object_or_404(User, pk=data["agent_id"])

    listing_status = data.get("listing_status", prop.listing_status) if is_admin(acting_user) else prop.listing_status
    validation_error = validate_listing_participants(owner, agent, listing_status)
    if validation_error:
        return json_error(validation_error)

    apply_property_updates(prop, data, owner, agent)
    prop.save()
    payload = serialize_property(prop)
    if settings.AI_ASSISTED_REVIEW_ENABLED:
        ai_review = review_listing_payload(
            {
                "title": prop.title,
                "description": prop.description,
                "address": prop.address,
                "city": prop.city,
                "suburb": prop.suburb,
                "monthly_rent": prop.monthly_rent,
                "deposit_required": prop.deposit_required,
                "latitude": prop.latitude,
                "longitude": prop.longitude,
                "photos": list(prop.photos.values_list("id", flat=True)),
            },
            owner,
        )
        payload["ai_review"] = serialize_ai_analysis(record_ai_analysis(ai_review, "property", prop.id))
    return JsonResponse(payload)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def property_view(request, property_id):
    prop = get_object_or_404(Property, pk=property_id)
    prop.views_count += 1
    prop.save(update_fields=["views_count"])
    return JsonResponse({"views_count": prop.views_count})


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def property_comments_collection(request, property_id):
    prop = get_object_or_404(Property.objects.select_related("owner", "agent"), pk=property_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_publicly_contactable_listing(prop) or can_manage_property(acting_user, prop)):
        return forbidden()

    if request.method == "GET":
        comments = PropertyComment.objects.filter(property=prop, parent__isnull=True).select_related("author").order_by("-created_at")[:100]
        return JsonResponse({"results": [serialize_property_comment(comment) for comment in comments]})

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    body = str(data.get("body") or "").strip()
    if not body:
        return json_error("Comment body is required")
    if len(body) > 1200:
        return json_error("Comment body must be 1200 characters or fewer")

    parent = None
    parent_id = data.get("parent_id")
    if parent_id:
        parent = get_object_or_404(PropertyComment, pk=parent_id, property=prop)

    comment = PropertyComment.objects.create(
        property=prop,
        author=acting_user,
        parent=parent,
        body=body,
        media_url=str(data.get("media_url") or data.get("mediaUri") or "").strip()[:500],
    )
    return JsonResponse(serialize_property_comment(comment), status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def property_photos_collection(request, property_id):
    prop = get_object_or_404(Property, pk=property_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not can_manage_property(acting_user, prop):
        return forbidden()
    data = request_data(request)
    if prop.photos.count() >= MAX_PROPERTY_PHOTOS:
        return json_error(f"A property can have a maximum of {MAX_PROPERTY_PHOTOS} photos", status=400)
    image_file = request.FILES.get("image") if hasattr(request, "FILES") else None
    try:
        image_file = optimize_image_upload(validate_upload(image_file, allowed_types=IMAGE_MIME_TYPES, max_bytes=MAX_IMAGE_BYTES, label="Property photo")) if image_file else None
    except MediaValidationError as exc:
        return json_error(str(exc))
    photo = PropertyPhoto.objects.create(
        property=prop,
        image=image_file,
        caption=data.get("caption", ""),
        sort_order=int(data.get("sort_order", prop.photos.count())),
    )
    asset = register_media_asset(acting_user, photo.image, scope=MediaAsset.Scope.PROPERTY, source_model="property_photo", source_id=photo.id, access=MediaAsset.Access.PUBLIC, original_name=data.get("caption") or "property_photo", mime_type="image/jpeg") if photo.image else None
    payload = serialize_property_photo(photo)
    if asset:
        payload["media_asset"] = serialize_media_asset(asset, include_private_url=True)
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def property_videos_collection(request, property_id):
    prop = get_object_or_404(Property, pk=property_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not can_manage_property(acting_user, prop):
        return forbidden()
    data = request_data(request)
    video_file = request.FILES.get("video") if hasattr(request, "FILES") else None
    try:
        validate_upload(video_file, allowed_types=VIDEO_MIME_TYPES, max_bytes=MAX_VIDEO_BYTES, label="Property video") if video_file else None
    except MediaValidationError as exc:
        return json_error(str(exc))
    video = PropertyVideo.objects.create(
        property=prop,
        video=video_file,
        external_url=data.get("external_url", ""),
        caption=data.get("caption", ""),
    )
    asset = register_media_asset(acting_user, video.video, scope=MediaAsset.Scope.PROPERTY, source_model="property_video", source_id=video.id, access=MediaAsset.Access.PUBLIC, original_name=data.get("caption") or "property_video", mime_type=getattr(video_file, "content_type", "")) if video.video else None
    payload = serialize_property_video(video)
    if asset:
        payload["media_asset"] = serialize_media_asset(asset, include_private_url=True)
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def saved_properties_collection(request, property_id):
    prop = get_object_or_404(Property, pk=property_id)
    acting_user, auth_response = require_roles(request, {User.Roles.TENANT})
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    tenant = acting_user
    saved, _ = SavedProperty.objects.get_or_create(property=prop, tenant=tenant)
    prop.saved_count = prop.saved_by.count()
    prop.save(update_fields=["saved_count"])
    return JsonResponse({"id": saved.id, "property_id": prop.id, "tenant_id": tenant.id, "saved_count": prop.saved_count}, status=201)


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def applications_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        applications = Application.objects.select_related("property", "tenant").order_by("-created_at")
        if acting_user.role == User.Roles.TENANT:
            applications = applications.filter(tenant=acting_user)
        elif acting_user.role in {User.Roles.LANDLORD, User.Roles.AGENT}:
            applications = applications.filter(property__in=user_properties(acting_user))
        elif not is_admin(acting_user):
            return forbidden()
        return JsonResponse({"results": [serialize_application(item) for item in applications]})

    if acting_user.role != User.Roles.TENANT:
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    prop = get_object_or_404(Property, pk=data.get("property_id"))
    tenant = acting_user
    lifecycle_errors = application_lifecycle_errors(tenant, prop)
    if lifecycle_errors:
        return json_error("Applications unlock after the physical viewing is completed", status=409, errors=lifecycle_errors)
    ai_score = None
    score = data.get("score")
    if score is None and settings.AI_ASSISTED_REVIEW_ENABLED:
        ai_score = score_application_payload({**data, "monthly_rent": prop.monthly_rent}, tenant)
        score = ai_score["score"]
    application, _ = Application.objects.update_or_create(
        property=prop,
        tenant=tenant,
        defaults={
            "status": data.get("status", Application.Status.SUBMITTED),
            "score": int(score or 0),
            "message": data.get("message", ""),
        },
    )
    payload = serialize_application(application)
    if ai_score:
        payload["ai_score"] = serialize_ai_analysis(record_ai_analysis(ai_score, "application", application.id))
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["GET", "PATCH", "OPTIONS"])
def application_detail(request, application_id):
    application = get_object_or_404(Application.objects.select_related("property", "tenant"), pk=application_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or application.tenant_id == acting_user.id or can_manage_property(acting_user, application.property)):
        return forbidden()

    if request.method == "GET":
        return JsonResponse(serialize_application(application))

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    if acting_user.role == User.Roles.TENANT:
        allowed = {"message", "status"}
        if set(data.keys()) - allowed:
            return forbidden()
        if data.get("status") and normalise_choice(data["status"], Application.Status, application.status) != Application.Status.WITHDRAWN:
            return json_error("Tenants can only withdraw their own applications")
    if data.get("status"):
        application.status = normalise_choice(data["status"], Application.Status, application.status)
    if data.get("score") is not None:
        application.score = int(data["score"])
    if data.get("message") is not None:
        application.message = data["message"]
    application.save()
    return JsonResponse(serialize_application(application))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def payments_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        payments = Payment.objects.select_related("tenant", "property").order_by("-created_at")
        if acting_user.role == User.Roles.TENANT:
            payments = payments.filter(tenant=acting_user)
        elif acting_user.role in {User.Roles.LANDLORD, User.Roles.AGENT}:
            payments = payments.filter(property__in=user_properties(acting_user))
        elif not is_admin(acting_user):
            return forbidden()
        return JsonResponse({"results": [serialize_payment(item) for item in payments]})

    if acting_user.role not in {User.Roles.TENANT, User.Roles.ADMIN}:
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    prop = get_object_or_404(Property, pk=data.get("property_id"))
    tenant = get_object_or_404(User, pk=data.get("tenant_id") if is_admin(acting_user) else acting_user.id)
    if acting_user.role == User.Roles.TENANT and tenant.id != acting_user.id:
        return forbidden()
    if acting_user.role == User.Roles.TENANT:
        lifecycle_errors = payment_lifecycle_errors(tenant, prop)
        if lifecycle_errors:
            return json_error("Payments unlock after physical viewing, approved application, and signed active lease", status=409, errors=lifecycle_errors)

    now = timezone.now()
    payment = Payment.objects.create(
        tenant=tenant,
        property=prop,
        amount=parse_decimal(data.get("amount"), "amount"),
        method=normalise_choice(data.get("method"), Payment.Method, Payment.Method.ECOCASH),
        status=data.get("status", Payment.Status.RECEIVED) if is_admin(acting_user) else Payment.Status.PENDING,
        provider_reference=data.get("provider_reference", ""),
        receipt_number=data.get("receipt_number") or make_receipt_number(),
        reminder_status=data.get("reminder_status", "Next reminder scheduled"),
        due_date=data.get("due_date") or None,
        paid_at=now if is_admin(acting_user) and data.get("status", Payment.Status.RECEIVED) == Payment.Status.RECEIVED else None,
    )
    return JsonResponse(serialize_payment(payment), status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def payment_reminder(request, payment_id):
    payment = get_object_or_404(Payment.objects.select_related("tenant", "property"), pk=payment_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or can_manage_property(acting_user, payment.property)):
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    payment.reminder_status = data.get("reminder_status") or f"Reminder sent on {timezone.localdate().isoformat()}"
    payment.save(update_fields=["reminder_status"])
    return JsonResponse(serialize_payment(payment))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def leases_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        leases = LeaseAgreement.objects.select_related("property", "tenant", "landlord").order_by("-created_at")
        if acting_user.role == User.Roles.TENANT:
            leases = leases.filter(tenant=acting_user)
        elif acting_user.role in {User.Roles.LANDLORD, User.Roles.AGENT}:
            leases = leases.filter(property__in=user_properties(acting_user))
        elif not is_admin(acting_user):
            return forbidden()
        return JsonResponse({"results": [serialize_lease(item) for item in leases]})

    if acting_user.role not in {User.Roles.LANDLORD, User.Roles.AGENT, User.Roles.ADMIN}:
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    prop = get_object_or_404(Property, pk=data.get("property_id"))
    if not can_manage_property(acting_user, prop):
        return forbidden()
    tenant = get_object_or_404(User, pk=data.get("tenant_id"))
    lifecycle_errors = lease_lifecycle_errors(tenant, prop)
    if lifecycle_errors:
        return json_error("Lease generation unlocks after completed viewing and approved application", status=409, errors=lifecycle_errors)
    lease = LeaseAgreement.objects.create(
        property=prop,
        tenant=tenant,
        landlord_id=data.get("landlord_id") or prop.owner_id,
        start_date=data.get("start_date"),
        end_date=data.get("end_date"),
        monthly_rent=parse_decimal(data.get("monthly_rent") or prop.monthly_rent, "monthly_rent"),
        deposit=parse_decimal(data.get("deposit") or prop.deposit_required, "deposit"),
        term=data.get("term", "12 Months"),
        status=data.get("status", LeaseAgreement.Status.AWAITING_SIGNATURES),
    )
    return JsonResponse(serialize_lease(lease), status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def lease_sign(request, lease_id):
    lease = get_object_or_404(LeaseAgreement, pk=lease_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")

    signer = data.get("signed_by")
    if signer == "tenant":
        if acting_user.id != lease.tenant_id and not is_admin(acting_user):
            return forbidden()
        lease.signed_by_tenant = True
        lease.tenant_signed_at = timezone.now()
    elif signer == "landlord":
        if acting_user.id != lease.landlord_id and not is_admin(acting_user):
            return forbidden()
        lease.signed_by_landlord = True
        lease.landlord_signed_at = timezone.now()
    else:
        return json_error("signed_by must be tenant or landlord")
    lease.save()
    return JsonResponse(serialize_lease(lease))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def maintenance_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        requests = MaintenanceRequest.objects.select_related("property", "tenant").order_by("-created_at")
        if acting_user.role == User.Roles.TENANT:
            requests = requests.filter(tenant=acting_user)
        elif acting_user.role in {User.Roles.LANDLORD, User.Roles.AGENT}:
            requests = requests.filter(property__in=user_properties(acting_user))
        elif not is_admin(acting_user):
            return forbidden()
        return JsonResponse({"results": [serialize_maintenance(item) for item in requests]})

    if acting_user.role != User.Roles.TENANT:
        return forbidden()

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")

    prop = get_object_or_404(Property, pk=data.get("property_id"))
    lifecycle_errors = maintenance_lifecycle_errors(acting_user, prop)
    if lifecycle_errors:
        return json_error("Maintenance unlocks after move-in is confirmed by an active lease", status=409, errors=lifecycle_errors)

    ai_triage = triage_maintenance_payload(data) if settings.AI_ASSISTED_REVIEW_ENABLED else None
    category = data.get("category") or (ai_triage or {}).get("suggested_category")
    photo_file = request.FILES.get("photo") if hasattr(request, "FILES") else None
    try:
        photo_file = optimize_image_upload(validate_upload(photo_file, allowed_types=IMAGE_MIME_TYPES, max_bytes=MAX_IMAGE_BYTES, label="Maintenance photo")) if photo_file else None
    except MediaValidationError as exc:
        return json_error(str(exc))
    ticket = MaintenanceRequest.objects.create(
        property=prop,
        tenant=acting_user,
        issue=data.get("issue", ""),
        category=normalise_choice(category, MaintenanceRequest.Category, MaintenanceRequest.Category.GENERAL),
        description=data.get("description", ""),
        photo=photo_file,
        status=data.get("status", MaintenanceRequest.Status.OPEN),
        priority=data.get("priority") or (ai_triage or {}).get("recommendation", "normal"),
    )
    if ticket.photo:
        register_media_asset(acting_user, ticket.photo, scope=MediaAsset.Scope.MAINTENANCE, source_model="maintenance_request", source_id=ticket.id, original_name="maintenance_photo", mime_type="image/jpeg")
    payload = serialize_maintenance(ticket)
    if ai_triage:
        payload["ai_triage"] = serialize_ai_analysis(record_ai_analysis(ai_triage, "maintenance_request", ticket.id))
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def ai_listing_review(request):
    acting_user, auth_response = require_roles(request, {User.Roles.LANDLORD, User.Roles.AGENT, User.Roles.ADMIN})
    if auth_response:
        return auth_response
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    owner = User.objects.filter(pk=data.get("owner_id")).first() if data.get("owner_id") else None
    result = review_listing_payload(data, owner)
    return JsonResponse({"result": result})


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def ai_maintenance_triage(request):
    acting_user, auth_response = require_roles(request, {User.Roles.TENANT, User.Roles.ADMIN})
    if auth_response:
        return auth_response
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    return JsonResponse({"result": triage_maintenance_payload(data)})


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def ai_application_score(request):
    acting_user, auth_response = require_roles(request, {User.Roles.LANDLORD, User.Roles.AGENT, User.Roles.ADMIN})
    if auth_response:
        return auth_response
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    tenant = User.objects.filter(pk=data.get("tenant_id")).first() if data.get("tenant_id") else None
    return JsonResponse({"result": score_application_payload(data, tenant)})


@csrf_exempt
@require_http_methods(["GET", "PATCH", "OPTIONS"])
def maintenance_detail(request, maintenance_id):
    ticket = get_object_or_404(MaintenanceRequest.objects.select_related("property", "tenant"), pk=maintenance_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or ticket.tenant_id == acting_user.id or can_manage_property(acting_user, ticket.property)):
        return forbidden()

    if request.method == "GET":
        return JsonResponse(serialize_maintenance(ticket))

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    if data.get("issue") is not None:
        ticket.issue = data["issue"]
    if data.get("category"):
        ticket.category = normalise_choice(data["category"], MaintenanceRequest.Category, ticket.category)
    if data.get("description") is not None:
        ticket.description = data["description"]
    if data.get("status"):
        ticket.status = normalise_choice(data["status"], MaintenanceRequest.Status, ticket.status)
    if data.get("priority"):
        ticket.priority = data["priority"]
    if hasattr(request, "FILES") and request.FILES.get("photo"):
        try:
            photo_file = optimize_image_upload(validate_upload(request.FILES["photo"], allowed_types=IMAGE_MIME_TYPES, max_bytes=MAX_IMAGE_BYTES, label="Maintenance photo"))
        except MediaValidationError as exc:
            return json_error(str(exc))
        remove_media_assets("maintenance_request", ticket.id)
        if ticket.photo:
            delete_file(ticket.photo)
        ticket.photo = photo_file
    ticket.save()
    if ticket.photo and hasattr(request, "FILES") and request.FILES.get("photo"):
        register_media_asset(acting_user, ticket.photo, scope=MediaAsset.Scope.MAINTENANCE, source_model="maintenance_request", source_id=ticket.id, original_name="maintenance_photo", mime_type="image/jpeg")
    return JsonResponse(serialize_maintenance(ticket))


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def verification_email_otp(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    email = normalize_email(data.get("email"))
    email_error = validate_email_field(email, required=True)
    if email_error:
        return json_error(email_error)
    if User.objects.exclude(pk=acting_user.pk).filter(email__iexact=email).exists():
        return json_error("An account with this email already exists")
    EmailVerificationOTP.objects.filter(user=acting_user, email=email, status=EmailVerificationOTP.Status.PENDING).update(status=EmailVerificationOTP.Status.EXPIRED)
    otp_code = get_random_string(6, allowed_chars="0123456789")
    challenge = EmailVerificationOTP.objects.create(
        user=acting_user,
        email=email,
        code_hash=hash_otp(otp_code),
        sent_to=email,
        expires_at=timezone.now() + timedelta(seconds=30),
    )
    delivered = send_verification_otp_email(email, otp_code)
    if not delivered:
        challenge.status = EmailVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return json_error("OTP email delivery is not configured", status=503)
    return JsonResponse(
        {
            "otp_required": True,
            "challenge_id": str(challenge.id),
            "email": mask_email(email),
            "delivery_channel": "email",
            "expires_in_seconds": 30,
            "message": "OTP sent to your email",
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def verification_email_otp_verify(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    challenge_id = data.get("challenge_id")
    code = str(data.get("otp") or data.get("code") or "").strip()
    if not challenge_id or not code:
        return json_error("challenge_id and otp are required")
    challenge = EmailVerificationOTP.objects.filter(pk=challenge_id, user=acting_user, status=EmailVerificationOTP.Status.PENDING).first()
    if not challenge:
        return json_error("OTP challenge was not found or has already been used", status=404)
    if challenge.is_expired:
        challenge.status = EmailVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status"])
        return json_error("OTP has expired")
    if challenge.attempts >= 5:
        challenge.status = EmailVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status"])
        return json_error("Too many OTP attempts")
    if challenge.code_hash != hash_otp(code):
        challenge.attempts += 1
        challenge.save(update_fields=["attempts"])
        return json_error("Invalid OTP")
    if User.objects.exclude(pk=acting_user.pk).filter(email__iexact=challenge.email).exists():
        challenge.status = EmailVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return json_error("An account with this email already exists")
    challenge.status = EmailVerificationOTP.Status.VERIFIED
    challenge.verified_at = timezone.now()
    challenge.save(update_fields=["status", "verified_at"])
    update_fields = []
    if str(acting_user.email or "").lower() != challenge.email.lower():
        acting_user.email = challenge.email
        update_fields.append("email")
    if not acting_user.email_verified:
        acting_user.email_verified = True
        update_fields.append("email_verified")
    if update_fields:
        acting_user.save(update_fields=update_fields)
    return JsonResponse({"email_verified": True, "email": mask_email(challenge.email), "user": serialize_user(acting_user), "account": serialize_account_context(acting_user)})


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def verification_phone_otp(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    phone = normalize_phone(data.get("phone"))
    phone_error = validate_phone_field(phone, required=True)
    if phone_error:
        return json_error(phone_error)
    if User.objects.exclude(pk=acting_user.pk).filter(phone_identity_query(phone)).exists():
        return json_error("An account with this phone number already exists")

    PhoneVerificationOTP.objects.filter(user=acting_user, phone=phone, status=PhoneVerificationOTP.Status.PENDING).update(status=PhoneVerificationOTP.Status.EXPIRED)
    otp_code = get_random_string(6, allowed_chars="0123456789")
    challenge = PhoneVerificationOTP.objects.create(
        user=acting_user,
        phone=phone,
        code_hash=hash_otp(otp_code),
        sent_to=phone,
        expires_at=timezone.now() + timedelta(seconds=30),
    )
    delivery_channel = "configured_provider_required"
    message = ""
    delivered = False
    if settings.OTP_DELIVERY_CHANNEL in {"sms", "phone", "twilio"}:
        delivered = send_phone_otp(phone, otp_code)
        if delivered:
            delivery_channel = "sms"
            message = "OTP sent to your phone"
    if not delivered:
        challenge.status = PhoneVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return json_error("Phone OTP delivery is not configured", status=503)
    return JsonResponse(
        {
            "otp_required": True,
            "challenge_id": str(challenge.id),
            "phone": phone,
            "delivery_channel": delivery_channel,
            "expires_in_seconds": 30,
            "message": message,
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def verification_phone_otp_verify(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    challenge_id = data.get("challenge_id")
    code = str(data.get("otp") or data.get("code") or "").strip()
    if not challenge_id or not code:
        return json_error("challenge_id and otp are required")
    challenge = PhoneVerificationOTP.objects.filter(pk=challenge_id, user=acting_user, status=PhoneVerificationOTP.Status.PENDING).first()
    if not challenge:
        return json_error("OTP challenge was not found or has already been used", status=404)
    if challenge.is_expired:
        challenge.status = PhoneVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status"])
        return json_error("OTP has expired")
    if challenge.attempts >= 5:
        challenge.status = PhoneVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status"])
        return json_error("Too many OTP attempts")
    if challenge.code_hash != hash_otp(code):
        challenge.attempts += 1
        challenge.save(update_fields=["attempts"])
        return json_error("Invalid OTP")
    if User.objects.exclude(pk=acting_user.pk).filter(phone_identity_query(challenge.phone)).exists():
        challenge.status = PhoneVerificationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return json_error("An account with this phone number already exists")
    challenge.status = PhoneVerificationOTP.Status.VERIFIED
    challenge.verified_at = timezone.now()
    challenge.save(update_fields=["status", "verified_at"])
    update_fields = []
    if acting_user.phone != challenge.phone:
        acting_user.phone = challenge.phone
        update_fields.append("phone")
    if not acting_user.phone_verified:
        acting_user.phone_verified = True
        update_fields.append("phone_verified")
    if update_fields:
        acting_user.save(update_fields=update_fields)
    return JsonResponse({"phone_verified": True, "phone": challenge.phone, "user": serialize_user(acting_user), "account": serialize_account_context(acting_user)})


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def verification_id_extract(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    files = request.FILES if hasattr(request, "FILES") else {}
    if not files.get("id_front_document"):
        return json_error("ID front image is required")
    if not files.get("id_back_document"):
        return json_error("ID back image is required")
    upload_errors = validate_identity_document_uploads(files, require_back=True)
    if upload_errors:
        audit_identity_event("identity_document_upload_rejected", acting_user, metadata={"reason": "upload_validation_failed"})
        return json_error("We couldn't read the document images", errors=upload_errors)
    provider = get_identity_verification_provider()
    extraction = provider.extract_document_data(files=files, data=data)
    audit_identity_event("identity_document_ocr_completed", acting_user, metadata={"provider": provider.provider_name, "confidence": extraction.confidence})
    return JsonResponse({
        "extracted_national_id_number": extraction.document_number,
        "confidence": extraction.confidence,
        "requires_confirmation": True,
    })


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def verifications_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        verifications = VerificationRequest.objects.select_related("user", "reviewed_by").order_by("-submitted_at")
        if is_admin(acting_user):
            pass
        else:
            verifications = verifications.filter(user=acting_user)
        return JsonResponse({"results": [serialize_verification(item, acting_user=acting_user) for item in verifications]})

    data = request_data(request)
    if data is None:
        return json_error("Invalid request body")
    user = acting_user if not is_admin(acting_user) else get_object_or_404(User, pk=data.get("user_id"))
    requested_role = data.get("role", user.role)
    if not is_admin(acting_user) and requested_role != user.role:
        return forbidden()
    verification_errors = validate_verification_submission(request, data, requested_role, user)
    if verification_errors:
        return json_error("Verification submission is incomplete", errors=verification_errors)
    profile_updates = []
    full_name = str(data.get("name") or data.get("full_name") or "").strip()
    phone = normalize_phone(data.get("phone"))
    if full_name and user.full_name != full_name:
        user.full_name = full_name
        profile_updates.append("full_name")
    if phone and user.phone != phone:
        if User.objects.exclude(pk=user.pk).filter(phone_identity_query(phone)).exists():
            return json_error("An account with this phone number already exists")
        user.phone = phone
        profile_updates.append("phone")
    if profile_updates:
        user.save(update_fields=profile_updates)
    files = request.FILES if hasattr(request, "FILES") else {}
    provider_result = run_identity_verification_provider(data, files)
    confirmed_document_number = str(data.get("national_id_number") or "").strip()
    id_number_hash = hash_identity_number(confirmed_document_number)
    verification_status = provider_result_to_status(provider_result)
    verification = VerificationRequest.objects.create(
        user=user,
        role=requested_role,
        national_id_number=mask_identity_number(confirmed_document_number),
        id_number_hash=id_number_hash,
        verification_method="local_ocr",
        verification_provider=provider_result.provider,
        provider_reference=provider_result.provider_reference,
        verification_score=provider_result.score,
        failure_reason=provider_result.failure_reason,
        document_retention_until=timezone.now() + timedelta(days=int(getattr(settings, "IDENTITY_DOCUMENT_RETENTION_DAYS", 30))),
        phone_verified=to_bool(data.get("phone_verified")),
        email_verified=to_bool(data.get("email_verified")),
        country_of_residence="",
        privacy_notice_accepted=to_bool(data.get("privacy_notice_accepted")),
        document_issue_country="",
        document_type=data.get("document_type", "identity_document") or "identity_document",
        residential_address=data.get("residential_address", ""),
        address_gps_confirmed=to_bool(data.get("address_gps_confirmed")),
        proof_of_address_document=request.FILES.get("proof_of_address_document") if hasattr(request, "FILES") else None,
        proof_of_address_confirmed=to_bool(data.get("proof_of_address_confirmed")),
        politically_exposed_person=to_bool(data.get("politically_exposed_person")),
        declaration_accepted=to_bool(data.get("declaration_accepted")),
        id_front_document=files.get("id_front_document"),
        id_back_document=files.get("id_back_document"),
        extracted_national_id_number=mask_identity_number(provider_result.extracted_document_number or data.get("extracted_national_id_number", "")),
        identity_confirmed=to_bool(data.get("identity_confirmed")),
        liveness_document=files.get("liveness_document"),
        selfie_document=files.get("selfie_document"),
        ownership_or_authorization_document=files.get("ownership_or_authorization_document"),
        estate_agency_registration=data.get("estate_agency_registration", ""),
        agency_name=data.get("agency_name", ""),
        contact_details=data.get("contact_details", ""),
        checks=default_checks_for_role(data.get("role", user.role)),
        status=verification_status,
    )
    if verification.status == VerificationRequest.Status.VERIFIED:
        user.is_verified = True
        user.save(update_fields=["is_verified"])
        audit_identity_event("identity_verification_completed", user, verification=verification)
    elif verification.status == VerificationRequest.Status.REJECTED:
        audit_identity_event("identity_verification_failed", user, verification=verification, metadata={"reason": provider_result.failure_reason})
    else:
        audit_identity_event("identity_verification_manual_review", user, verification=verification, metadata={"provider": provider_result.provider})
    return JsonResponse(serialize_verification(verification, acting_user=acting_user), status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def verification_review(request, verification_id):
    acting_user, auth_response = require_roles(request, {User.Roles.ADMIN})
    if auth_response:
        return auth_response
    verification = get_verification_for_review(verification_id)
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    reviewer = acting_user
    status = data.get("status")
    if status in {VerificationRequest.Status.APPROVED, VerificationRequest.Status.VERIFIED}:
        verification.approve(reviewer)
        audit_identity_event("identity_verification_admin_approved", verification.user, verification=verification, actor=reviewer)
    else:
        verification.status = status or VerificationRequest.Status.REVIEWING
        verification.reviewed_by = reviewer
        verification.notes = data.get("notes", verification.notes)
        verification.reviewed_at = timezone.now()
        verification.save()
    return JsonResponse(serialize_verification(verification, acting_user=acting_user))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def viewings_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        viewings = Viewing.objects.select_related("property", "tenant", "agent").order_by("-scheduled_for")
        if acting_user.role == User.Roles.TENANT:
            viewings = viewings.filter(tenant=acting_user)
        elif acting_user.role in {User.Roles.LANDLORD, User.Roles.AGENT}:
            viewings = viewings.filter(property__in=user_properties(acting_user))
        elif not is_admin(acting_user):
            return forbidden()
        return JsonResponse({"results": [serialize_viewing(item) for item in viewings]})

    if acting_user.role != User.Roles.TENANT:
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    viewing = Viewing.objects.create(
        property_id=data.get("property_id"),
        tenant=acting_user,
        agent_id=data.get("agent_id") or None,
        scheduled_for=data.get("scheduled_for"),
        status=data.get("status", Viewing.Status.PENDING),
        notes=data.get("notes", ""),
    )
    return JsonResponse(serialize_viewing(viewing), status=201)


@csrf_exempt
@require_http_methods(["GET", "PATCH", "OPTIONS"])
def viewing_detail(request, viewing_id):
    viewing = get_object_or_404(Viewing.objects.select_related("property", "tenant", "agent"), pk=viewing_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or viewing.tenant_id == acting_user.id or can_manage_property(acting_user, viewing.property)):
        return forbidden()

    if request.method == "GET":
        return JsonResponse(serialize_viewing(viewing))

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    if data.get("scheduled_for"):
        viewing.scheduled_for = data["scheduled_for"]
    if data.get("status"):
        viewing.status = normalise_choice(data["status"], Viewing.Status, viewing.status)
    if data.get("notes") is not None:
        viewing.notes = data["notes"]
    if data.get("agent_id") is not None:
        viewing.agent_id = data.get("agent_id") or None
    viewing.save()
    return JsonResponse(serialize_viewing(viewing))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def conversations_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        conversations = list_conversations_for_user(acting_user)
        return JsonResponse({"results": [serialize_conversation(item) for item in conversations]})

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    property_id = data.get("property_id")
    if not property_id:
        return json_error("property_id is required so chats stay attached to a real listing")

    prop = get_object_or_404(Property.objects.select_related("owner", "agent"), pk=property_id)
    participant_ids = allowed_conversation_participant_ids(acting_user, prop, data.get("participant_ids", []))
    if participant_ids is None:
        return forbidden()

    conversation, created = open_listing_conversation(acting_user, prop, participant_ids, data.get("title") or "")
    return JsonResponse(serialize_conversation(conversation), status=201 if created else 200)


@csrf_exempt
@require_http_methods(["GET", "PATCH", "OPTIONS"])
def conversation_detail(request, conversation_id):
    conversation = get_object_or_404(Conversation.objects.prefetch_related("participants", "messages"), pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    if request.method == "GET":
        return JsonResponse(serialize_conversation(conversation))

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    if data.get("title") is not None:
        conversation.title = data["title"]
    if data.get("phone_numbers_revealed") is not None:
        conversation.phone_numbers_revealed = to_bool(data["phone_numbers_revealed"])
    conversation.save()
    return JsonResponse(serialize_conversation(conversation))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def conversation_messages(request, conversation_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    if request.method == "GET":
        messages = conversation.messages.select_related("sender")
        message_ids = mark_conversation_read(conversation, acting_user)
        if message_ids:
            broadcast_to_conversation(conversation.id, "messages.read", {
                "conversation_id": str(conversation.id),
                "reader_id": str(acting_user.id),
                "message_ids": [str(item) for item in message_ids],
            })
        return JsonResponse({"results": [serialize_message(item) for item in messages]})

    if request.content_type and request.content_type.startswith("multipart/form-data"):
        data = request.POST
        files = request.FILES
    else:
        data = request_json(request)
        files = {}
    if data is None:
        return json_error("Invalid JSON body")
    attachment_file = files.get("attachment")
    try:
        validate_upload(attachment_file, allowed_types=CHAT_MIME_TYPES, max_bytes=MAX_CHAT_ATTACHMENT_BYTES, label="Chat attachment") if attachment_file else None
        message = create_chat_message(
            conversation,
            acting_user,
            data.get("body"),
            attachment=attachment_file,
            attachment_url=data.get("attachment_url"),
            attachment_type=data.get("attachment_type"),
            attachment_name=data.get("attachment_name"),
            client_message_id=data.get("client_message_id") or data.get("client_id"),
        )
    except (MediaValidationError, ValueError) as exc:
        return json_error(str(exc))
    if message.attachment:
        register_media_asset(acting_user, message.attachment, scope=MediaAsset.Scope.CHAT, source_model="message", source_id=message.id, original_name=message.attachment_name or getattr(attachment_file, "name", "chat_attachment"), mime_type=getattr(attachment_file, "content_type", ""))
    payload = serialize_message(message)
    audit_event("message_created_rest", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, metadata={"conversation_id": conversation.id, "message_id": message.id})
    broadcast_to_conversation(conversation.id, "message.created", payload)
    send_chat_message_push(message)
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["PATCH", "DELETE", "OPTIONS"])
def conversation_message_detail(request, conversation_id, message_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    try:
        if request.method == "DELETE":
            message = delete_chat_message(conversation, message_id, acting_user)
            payload = serialize_message(message)
            audit_event("message_deleted_rest", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, metadata={"conversation_id": conversation.id, "message_id": message.id})
            broadcast_to_conversation(conversation.id, "message.deleted", payload)
            return JsonResponse(payload)

        data = request_json(request)
        if data is None:
            return json_error("Invalid JSON body")
        if data.get("delete") is True:
            message = delete_chat_message(conversation, message_id, acting_user)
            payload = serialize_message(message)
            audit_event("message_deleted_rest", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, metadata={"conversation_id": conversation.id, "message_id": message.id})
            broadcast_to_conversation(conversation.id, "message.deleted", payload)
            return JsonResponse(payload)
        message = edit_chat_message(conversation, message_id, acting_user, data.get("body"))
    except Message.DoesNotExist:
        return json_error("Message not found", status=404)
    except PermissionError:
        return forbidden()
    except ValueError as exc:
        return json_error(str(exc))

    payload = serialize_message(message)
    audit_event("message_edited_rest", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, metadata={"conversation_id": conversation.id, "message_id": message.id})
    broadcast_to_conversation(conversation.id, "message.edited", payload)
    return JsonResponse(payload)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def conversation_delivered(request, conversation_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    message_ids = mark_conversation_delivered(conversation, acting_user)
    payload = {
        "conversation_id": str(conversation.id),
        "recipient_id": str(acting_user.id),
        "message_ids": [str(item) for item in message_ids],
    }
    if message_ids:
        broadcast_to_conversation(conversation.id, "messages.delivered", payload)
    return JsonResponse(payload)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def conversation_block(request, conversation_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not conversation.participants.filter(id=acting_user.id).exists():
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    try:
        block = block_chat_user(conversation, acting_user, data.get("blocked_user_id"))
    except ValueError as exc:
        return json_error(str(exc))
    audit_event("chat_user_blocked", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, severity=SecurityAuditEvent.Severity.MEDIUM, metadata={"conversation_id": conversation.id, "blocked_user_id": block.blocked_id})
    broadcast_to_conversation(conversation.id, "conversation.blocked", {"conversation_id": str(conversation.id), "blocker_id": str(acting_user.id), "blocked_user_id": str(block.blocked_id)})
    return JsonResponse({"blocked_user_id": str(block.blocked_id), "created_at": block.created_at.isoformat()}, status=201)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def conversation_report(request, conversation_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    try:
        report = report_chat_message(
            conversation,
            acting_user,
            message_id=data.get("message_id"),
            reason=data.get("reason"),
            details=data.get("details"),
        )
    except Message.DoesNotExist:
        return json_error("Message not found", status=404)
    except ValueError as exc:
        return json_error(str(exc))
    audit_event("chat_report_created", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, severity=SecurityAuditEvent.Severity.MEDIUM, metadata={"conversation_id": conversation.id, "report_id": report.id})
    return JsonResponse({"id": str(report.id), "status": report.status, "created_at": report.created_at.isoformat()}, status=201)


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def conversation_calls(request, conversation_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    if request.method == "GET":
        calls = conversation.call_sessions.select_related("initiator").order_by("-created_at")[:20]
        return JsonResponse({"results": [serialize_call_session(call) for call in calls]})

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    mode = data.get("mode")
    if mode not in {CallSession.Mode.VOICE, CallSession.Mode.VIDEO}:
        return json_error("mode must be voice or video")
    call = create_call(conversation, acting_user, mode)
    payload = serialize_call_session(call)
    audit_event("call_started_rest", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, metadata={"conversation_id": conversation.id, "call_id": call.id, "mode": mode})
    broadcast_to_conversation(conversation.id, "call.started", payload)
    send_call_push(call)
    return JsonResponse(payload, status=201)


@csrf_exempt
@require_http_methods(["PATCH", "OPTIONS"])
def conversation_call_detail(request, conversation_id, call_id):
    conversation = get_object_or_404(Conversation, pk=conversation_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
        return forbidden()

    call = get_object_or_404(CallSession, pk=call_id, conversation=conversation)
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    status = data.get("status")
    if status not in {CallSession.Status.ENDED, CallSession.Status.MISSED}:
        return json_error("status must be ended or missed")
    call.status = status
    if call.ended_at is None:
        call.ended_at = timezone.now()
    call.save(update_fields=["status", "ended_at"])
    conversation.save(update_fields=["updated_at"])
    payload = serialize_call_session(call)
    audit_event("call_ended_rest", actor=acting_user, category=SecurityAuditEvent.Category.CHAT, metadata={"conversation_id": conversation.id, "call_id": call.id, "status": status})
    broadcast_to_conversation(conversation.id, "call.ended", payload)
    return JsonResponse(payload)


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def push_devices_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    try:
        device = register_push_device(acting_user, data.get("token"), data.get("platform"))
    except ValueError as exc:
        return json_error(str(exc))
    audit_event("push_device_registered", actor=acting_user, category=SecurityAuditEvent.Category.AUTHENTICATION, metadata={"platform": device.platform})
    return JsonResponse({
        "id": str(device.id),
        "platform": device.platform,
        "enabled": device.enabled,
        "updated_at": device.updated_at.isoformat(),
    }, status=201)


@csrf_exempt
@require_http_methods(["GET", "OPTIONS"])
def media_assets_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    assets = media_asset_queryset_for_user(acting_user)
    scope = request.GET.get("scope")
    source_model = request.GET.get("source_model")
    source_id = request.GET.get("source_id")
    property_id = request.GET.get("property_id")
    conversation_id = request.GET.get("conversation_id")
    if scope:
        assets = assets.filter(scope=scope)
    if source_model:
        assets = assets.filter(source_model=source_model)
    if source_id:
        assets = assets.filter(source_id=str(source_id))
    if property_id:
        photo_ids = PropertyPhoto.objects.filter(property_id=property_id).values_list("id", flat=True)
        video_ids = PropertyVideo.objects.filter(property_id=property_id).values_list("id", flat=True)
        assets = assets.filter(Q(source_model="property_photo", source_id__in=[str(item) for item in photo_ids]) | Q(source_model="property_video", source_id__in=[str(item) for item in video_ids]))
    if conversation_id:
        conversation = get_object_or_404(Conversation, pk=conversation_id)
        if not (is_admin(acting_user) or conversation.participants.filter(id=acting_user.id).exists()):
            return forbidden()
        message_ids = [str(item) for item in conversation.messages.values_list("id", flat=True)]
        assets = assets.filter(source_model="message", source_id__in=message_ids)
    return JsonResponse({"results": [serialize_media_asset(asset, include_private_url=True) for asset in assets.order_by("-created_at")[:200]]})


@csrf_exempt
@require_http_methods(["GET", "DELETE", "OPTIONS"])
def media_asset_detail(request, media_id):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    asset = get_object_or_404(MediaAsset, pk=media_id)
    if not can_access_media_asset(acting_user, asset):
        return forbidden()
    if request.method == "GET":
        return JsonResponse(serialize_media_asset(asset, include_private_url=True))
    if not can_delete_media_asset(acting_user, asset):
        return forbidden()
    clear_media_source(asset)
    soft_delete_media_asset(asset)
    audit_event("media_asset_deleted", actor=acting_user, category=SecurityAuditEvent.Category.CHAT if asset.scope == MediaAsset.Scope.CHAT else SecurityAuditEvent.Category.AUTHORIZATION, metadata={"media_id": asset.id, "scope": asset.scope})
    return JsonResponse(serialize_media_asset(asset, include_private_url=False))


@csrf_exempt
@require_http_methods(["POST", "DELETE", "OPTIONS"])
def supplier_follow(request, supplier_id):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    supplier = get_object_or_404(User, pk=supplier_id)
    if supplier.role not in {User.Roles.LANDLORD, User.Roles.AGENT} or not supplier.is_verified:
        return json_error("Only verified landlords and agents can be followed", status=400)
    if supplier.id == acting_user.id:
        return json_error("You cannot follow your own supplier account", status=400)

    if request.method == "DELETE":
        SupplierFollow.objects.filter(follower=acting_user, supplier=supplier).delete()
        return JsonResponse(serialize_supplier_follow(supplier, False))

    SupplierFollow.objects.get_or_create(follower=acting_user, supplier=supplier)
    return JsonResponse(serialize_supplier_follow(supplier, True), status=201)


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def reviews_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        reviews = Review.objects.select_related("tenant", "landlord").order_by("-created_at")
        if acting_user.role == User.Roles.TENANT:
            reviews = reviews.filter(tenant=acting_user)
        elif acting_user.role == User.Roles.LANDLORD:
            reviews = reviews.filter(landlord=acting_user)
        elif not is_admin(acting_user):
            return forbidden()
        return JsonResponse({"results": [serialize_review(item) for item in reviews]})

    if acting_user.role != User.Roles.TENANT:
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    review = Review.objects.create(
        tenant=acting_user,
        landlord_id=data.get("landlord_id"),
        rating=int(data.get("rating", 5)),
        comment=data.get("comment", ""),
    )
    return JsonResponse(serialize_review(review), status=201)


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def reports_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        reports = DisputeReport.objects.select_related("reporter", "property", "assigned_admin").order_by("-created_at")
        if is_admin(acting_user):
            pass
        else:
            reports = reports.filter(reporter=acting_user)
        return JsonResponse({"results": [serialize_report(item) for item in reports]})

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    report = DisputeReport.objects.create(
        reporter=acting_user,
        property_id=data.get("property_id") or None,
        subject=data.get("subject", ""),
        description=data.get("description", ""),
        status=data.get("status", DisputeReport.Status.OPEN),
    )
    return JsonResponse(serialize_report(report), status=201)


@csrf_exempt
@require_http_methods(["GET", "PATCH", "OPTIONS"])
def report_detail(request, report_id):
    report = get_object_or_404(DisputeReport.objects.select_related("reporter", "property", "assigned_admin"), pk=report_id)
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or report.reporter_id == acting_user.id):
        return forbidden()

    if request.method == "GET":
        return JsonResponse(serialize_report(report))

    if not is_admin(acting_user):
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    if data.get("status"):
        report.status = normalise_choice(data["status"], DisputeReport.Status, report.status)
        if report.status in {DisputeReport.Status.RESOLVED, DisputeReport.Status.DISMISSED}:
            report.resolved_at = timezone.now()
    if data.get("assigned_admin_id") is not None:
        report.assigned_admin_id = data.get("assigned_admin_id") or None
    if data.get("subject") is not None:
        report.subject = data["subject"]
    if data.get("description") is not None:
        report.description = data["description"]
    report.save()
    return JsonResponse(serialize_report(report))


@csrf_exempt
@require_http_methods(["GET", "POST", "OPTIONS"])
def commissions_collection(request):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response

    if request.method == "GET":
        commissions = Commission.objects.select_related("agent", "property", "lease").order_by("-created_at")
        if acting_user.role == User.Roles.AGENT:
            commissions = commissions.filter(agent=acting_user)
        elif is_admin(acting_user):
            pass
        else:
            return forbidden()
        return JsonResponse({"results": [serialize_commission(item) for item in commissions]})

    if acting_user.role not in {User.Roles.AGENT, User.Roles.ADMIN}:
        return forbidden()

    data = request_json(request)
    if data is None:
        return json_error("Invalid JSON body")
    agent = get_object_or_404(User, pk=data.get("agent_id")) if is_admin(acting_user) else acting_user
    if agent.role != User.Roles.AGENT:
        return json_error("agent_id must belong to an estate agent")
    commission = Commission.objects.create(
        agent=agent,
        property_id=data.get("property_id"),
        lease_id=data.get("lease_id") or None,
        amount=parse_decimal(data.get("amount"), "amount"),
        status=data.get("status", "pending"),
    )
    return JsonResponse(serialize_commission(commission), status=201)


def landlord_analytics(request, user_id):
    acting_user, auth_response = require_authenticated(request)
    if auth_response:
        return auth_response
    if not (is_admin(acting_user) or acting_user.id == user_id):
        return forbidden()

    properties = Property.objects.filter(owner_id=user_id)
    property_ids = properties.values_list("id", flat=True)
    total_properties = properties.count()
    active_leases = LeaseAgreement.objects.filter(property_id__in=property_ids, status=LeaseAgreement.Status.ACTIVE).count()
    received_payments = Payment.objects.filter(property_id__in=property_ids, status=Payment.Status.RECEIVED)
    rental_income = received_payments.aggregate(total=Coalesce(Sum("amount"), Decimal("0")))["total"]

    return JsonResponse(
        {
            "listing_views": sum(item.views_count for item in properties),
            "saved_properties": SavedProperty.objects.filter(property_id__in=property_ids).count(),
            "applications": Application.objects.filter(property_id__in=property_ids).count(),
            "occupancy_rate": round((active_leases / total_properties) * 100) if total_properties else 0,
            "rental_income": str(rental_income),
            "properties": [serialize_property(item) for item in properties.annotate(application_total=Count("applications"))],
        }
    )


def apply_property_filters(properties, params):
    q = params.get("q") or params.get("search")
    if q:
        properties = properties.filter(
            Q(title__icontains=q)
            | Q(description__icontains=q)
            | Q(address__icontains=q)
            | Q(city__icontains=q)
            | Q(suburb__icontains=q)
            | Q(property_type__icontains=q)
        )
    if params.get("city"):
        properties = properties.filter(city__iexact=params["city"])
    if params.get("suburb"):
        properties = properties.filter(suburb__iexact=params["suburb"])
    property_type = params.get("property_type") or params.get("type")
    if property_type:
        properties = properties.filter(property_type=normalise_choice(property_type, Property.PropertyType, property_type))
    if params.get("rent_min"):
        properties = properties.filter(monthly_rent__gte=parse_decimal(params["rent_min"], "rent_min"))
    if params.get("rent_max"):
        properties = properties.filter(monthly_rent__lte=parse_decimal(params["rent_max"], "rent_max"))
    if params.get("bedrooms_min"):
        properties = properties.filter(bedrooms__gte=int(params["bedrooms_min"]))
    if to_bool(params.get("verified_only")):
        properties = properties.filter(listing_status=Property.ListingStatus.VERIFIED, owner__is_verified=True).filter(Q(agent__isnull=True) | Q(agent__is_verified=True))
    return properties.filter(is_active=True)


def request_json(request):
    try:
        return json.loads(request.body.decode("utf-8") or "{}")
    except json.JSONDecodeError:
        return None


def request_data(request):
    content_type = request.META.get("CONTENT_TYPE", "")
    if content_type.startswith(("multipart/form-data", "application/x-www-form-urlencoded")):
        return request.POST.dict()
    return request_json(request)


def json_error(message, status=400, errors=None):
    payload = {"error": message}
    if errors:
        payload["errors"] = errors
    return JsonResponse(payload, status=status)


def parse_decimal(value, field):
    if value is None or value == "":
        return Decimal("0")
    try:
        cleaned = re.sub(r"[^0-9.]", "", str(value))
        return Decimal(cleaned or "0")
    except (InvalidOperation, TypeError):
        raise ValueError(f"{field} must be a number")


def parse_coordinates(data):
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    if latitude is not None and longitude is not None:
        return latitude, longitude
    gps = data.get("gps")
    if gps and "," in gps:
        lat, lng = gps.split(",", 1)
        return lat.strip(), lng.strip()
    return None, None


def validate_listing_participants(owner, agent, listing_status):
    if owner.role not in {User.Roles.LANDLORD, User.Roles.AGENT}:
        return "owner_id must belong to a landlord or estate agent"
    if agent and agent.role != User.Roles.AGENT:
        return "agent_id must belong to an estate agent"
    if listing_status == Property.ListingStatus.VERIFIED:
        if not owner.is_verified:
            return "owner must be verified before a listing can be marked verified"
        if agent and not agent.is_verified:
            return "agent must be verified before a listing can be marked verified"
    return None


def validate_verification_submission(request, data, role, user):
    errors = []
    files = request.FILES if hasattr(request, "FILES") else {}
    has_selfie = bool(files.get("selfie_document") or data.get("selfie_document_url") or to_bool(data.get("selfie_uploaded")))

    full_name = str(data.get("name") or data.get("full_name") or "").strip()
    phone = normalize_phone(data.get("phone"))
    for error in (
        validate_text_field(full_name, "Full name", NAME_MAX_LENGTH, required=True),
        validate_phone_field(phone, required=False),
    ):
        if error:
            errors.append(error)
    document_type = str(data.get("document_type") or "identity_document").strip()
    national_id_number = str(data.get("national_id_number") or "").strip()
    extracted_id_number = str(data.get("extracted_national_id_number") or "").strip()
    has_id_front = bool(files.get("id_front_document") or data.get("id_front_document_url") or to_bool(data.get("id_front_uploaded")))
    has_id_back = bool(files.get("id_back_document") or data.get("id_back_document_url") or to_bool(data.get("id_back_uploaded")))
    if document_type not in ACCEPTED_ID_DOCUMENT_TYPES:
        errors.append("document_type must be identity_document")
    if not national_id_number:
        errors.append("document number is required")
    elif not is_valid_generic_document_number(national_id_number):
        errors.append("document number format is invalid")
    if not has_id_front:
        errors.append("id_front_document is required")
    if not has_id_back:
        errors.append("id_back_document is required")
    errors.extend(validate_identity_document_uploads(files, require_back=True))
    document_hash = hash_identity_number(national_id_number)
    if document_hash and VerificationRequest.objects.exclude(user=user).filter(id_number_hash=document_hash, status__in=IDENTITY_ACTIVE_STATUSES).exists():
        errors.append("identity document is already used by another account")
    if extracted_id_number and national_id_number and normalize_identity_number(extracted_id_number) != normalize_identity_number(national_id_number):
        errors.append("confirmed document number must match extracted document number")
    if not to_bool(data.get("identity_confirmed")):
        errors.append("identity_confirmed must be true after confirming the document information")
    if not to_bool(data.get("email_verified")) or not email_otp_verified(user):
        errors.append("email_verified must be completed using OTP")

    if role == User.Roles.LANDLORD and not (files.get("ownership_or_authorization_document") or data.get("ownership_or_authorization_uploaded")):
        errors.append("ownership_or_authorization_document is required for landlord verification")

    if role == User.Roles.AGENT:
        if not data.get("estate_agency_registration"):
            errors.append("estate_agency_registration is required for agent verification")
        if not data.get("agency_name"):
            errors.append("agency_name is required for agent verification")
        if not data.get("contact_details"):
            errors.append("contact_details is required for agent verification")

    return errors


def apply_property_updates(prop, data, owner, agent):
    prop.owner = owner
    prop.agent = agent
    text_fields = ["title", "description", "address", "city", "suburb", "water_availability", "parking"]
    for field in text_fields:
        if data.get(field) is not None:
            setattr(prop, field, data[field])
    if data.get("monthly_rent") is not None:
        prop.monthly_rent = parse_decimal(data["monthly_rent"], "monthly_rent")
    if data.get("deposit_required") is not None:
        prop.deposit_required = parse_decimal(data["deposit_required"], "deposit_required")
    if data.get("property_type") is not None:
        prop.property_type = normalise_choice(data["property_type"], Property.PropertyType, prop.property_type)
    if data.get("bedrooms") is not None:
        prop.bedrooms = int(data["bedrooms"])
    if data.get("bathrooms") is not None:
        prop.bathrooms = parse_decimal(data["bathrooms"], "bathrooms")
    for field in ["furnished", "solar_power", "borehole", "pet_friendly", "has_360_tour", "is_active"]:
        if data.get(field) is not None:
            setattr(prop, field, to_bool(data[field]))
    if data.get("listing_status") is not None and is_admin(acting_user):
        prop.listing_status = normalise_choice(data["listing_status"], Property.ListingStatus, prop.listing_status)
    latitude, longitude = parse_coordinates(data)
    if latitude is not None and longitude is not None:
        prop.latitude = latitude
        prop.longitude = longitude


def create_property_media(prop, data):
    photos = list(data.get("photos") or [])[:MAX_PROPERTY_PHOTOS]
    for index, value in enumerate(photos):
        if isinstance(value, dict):
            PropertyPhoto.objects.create(property=prop, caption=value.get("caption", ""), sort_order=value.get("sort_order", index))
        else:
            PropertyPhoto.objects.create(property=prop, caption=str(value), sort_order=index)
    for value in data.get("videos") or []:
        if isinstance(value, dict):
            PropertyVideo.objects.create(property=prop, external_url=value.get("external_url", ""), caption=value.get("caption", ""))
        elif str(value).startswith(("http://", "https://")):
            PropertyVideo.objects.create(property=prop, external_url=str(value))
        else:
            PropertyVideo.objects.create(property=prop, caption=str(value))


def to_bool(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "verified", "furnished"}


def normalise_choice(value, choices, default):
    if not value:
        return default
    normalized = str(value).strip().lower().replace("/", " ").replace("-", " ").replace(" ", "_")
    for choice_value, choice_label in choices.choices:
        if normalized in {choice_value, choice_label.lower().replace(" ", "_")}:
            return choice_value
    return default


def make_receipt_number():
    return f"RCT-{timezone.now().year}-{Payment.objects.count() + 1:04d}"


def default_checks_for_role(role):
    base_checks = ["Email OTP", "Identity document", "Document number confirmation"]
    if role == User.Roles.LANDLORD:
        return base_checks + ["Estate setup"]
    if role == User.Roles.AGENT:
        return base_checks + ["Estate agency registration", "Agency information", "Contact details"]
    return base_checks



def email_otp_verified(user):
    email = str(getattr(user, "email", "") or "").strip().lower()
    if not user or not email:
        return False
    return EmailVerificationOTP.objects.filter(user_id=user.id, email=email, status=EmailVerificationOTP.Status.VERIFIED).exists()


def mask_email(email):
    value = str(email or "").strip()
    if "@" not in value:
        return value
    local, domain = value.split("@", 1)
    if len(local) <= 2:
        return f"{local[:1]}***@{domain}"
    return f"{local[:2]}***{local[-1:]}@{domain}"


def phone_otp_verified(user, phone):
    if not user or not phone:
        return False
    return PhoneVerificationOTP.objects.filter(user_id=user.id, phone=phone, status=PhoneVerificationOTP.Status.VERIFIED).exists()


def send_verification_otp_email(email, code):
    email = str(email or "").strip()
    if not email:
        return False
    try:
        validate_email_otp_provider()
        sent = send_mail(
            "Your Property24 verification OTP",
            f"Your Property24 verification OTP is {code}. It expires in 30 seconds.",
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False,
        )
        return sent >= 1
    except Exception:
        return False


def send_phone_otp(phone, code):
    if getattr(settings, "OTP_SMS_PROVIDER", "").lower() == "twilio":
        return send_twilio_phone_otp(phone, code)
    webhook_url = getattr(settings, "OTP_SMS_WEBHOOK_URL", "")
    if not webhook_url:
        return False
    payload = json.dumps({"to": phone, "message": f"Your Property24 verification code is {code}", "sender": getattr(settings, "OTP_SMS_SENDER", "Property24")}).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    api_key = getattr(settings, "OTP_SMS_API_KEY", "")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    try:
        req = urlrequest.Request(webhook_url, data=payload, headers=headers, method="POST")
        with urlrequest.urlopen(req, timeout=8) as response:
            return 200 <= response.status < 300
    except (OSError, urlerror.URLError):
        return False


def send_twilio_phone_otp(phone, code):
    account_sid = str(getattr(settings, "TWILIO_ACCOUNT_SID", "") or "").strip()
    auth_token = str(getattr(settings, "TWILIO_AUTH_TOKEN", "") or "").strip()
    from_number = str(getattr(settings, "TWILIO_FROM_NUMBER", "") or "").strip()
    messaging_service_sid = str(getattr(settings, "TWILIO_MESSAGING_SERVICE_SID", "") or "").strip()
    values = [account_sid, auth_token, messaging_service_sid or from_number]
    if any(not value or value.startswith("replace-me") for value in values):
        return False

    payload = {
        "To": phone,
        "Body": f"Your Property24 verification code is {code}. It expires in 30 seconds.",
    }
    if messaging_service_sid:
        payload["MessagingServiceSid"] = messaging_service_sid
    else:
        payload["From"] = from_number

    encoded = urlencode(payload).encode("utf-8")
    credentials = b64encode(f"{account_sid}:{auth_token}".encode("utf-8")).decode("ascii")
    headers = {
        "Authorization": f"Basic {credentials}",
        "Content-Type": "application/x-www-form-urlencoded",
    }
    url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
    try:
        req = urlrequest.Request(url, data=encoded, headers=headers, method="POST")
        with urlrequest.urlopen(req, timeout=10) as response:
            return 200 <= response.status < 300
    except (OSError, urlerror.URLError):
        return False


def get_verification_for_review(identifier):
    queryset = VerificationRequest.objects.select_related("user")
    try:
        parsed_uuid = uuid.UUID(str(identifier))
    except (TypeError, ValueError):
        return get_object_or_404(queryset, pk=identifier)
    return get_object_or_404(queryset, public_id=parsed_uuid)


def audit_identity_event(event_type, user, *, verification=None, actor=None, metadata=None):
    clean_metadata = dict(metadata or {})
    if verification:
        clean_metadata["verification_id"] = verification.id
        clean_metadata["status"] = verification.status
    return audit_event(
        event_type,
        actor=actor or user,
        category=SecurityAuditEvent.Category.AUTHORIZATION,
        metadata=clean_metadata,
    )


def hash_identity_number(value):
    normalized = normalize_identity_number(value)
    if not normalized:
        return ""
    key = str(getattr(settings, "IDENTITY_DOCUMENT_HMAC_KEY", "") or settings.SECRET_KEY)
    return hmac.new(key.encode("utf-8"), normalized.encode("utf-8"), hashlib.sha256).hexdigest()


def mask_identity_number(value):
    normalized = normalize_identity_number(value)
    if not normalized:
        return ""
    if len(normalized) <= 6:
        return "*" * len(normalized)
    return f"{normalized[:2]}{'*' * max(len(normalized) - 4, 2)}{normalized[-2:]}"


def provider_result_to_status(result):
    if result.status == "verified" and getattr(settings, "IDENTITY_LOCAL_AUTO_VERIFY", False):
        return VerificationRequest.Status.VERIFIED
    if result.status == "rejected":
        return VerificationRequest.Status.REJECTED
    if result.status == "failed":
        return VerificationRequest.Status.FAILED
    return VerificationRequest.Status.MANUAL_REVIEW


def run_identity_verification_provider(data, files):
    provider = get_identity_verification_provider()
    return provider.verify_document(
        files=files,
        data=data,
        document_type=str(data.get("document_type") or "identity_document").strip(),
        confirmed_document_number=str(data.get("national_id_number") or "").strip(),
    )


def validate_identity_document_uploads(files, *, require_back):
    errors = []
    errors.extend(validate_identity_document_upload(files.get("id_front_document"), "ID front image"))
    if require_back or files.get("id_back_document"):
        errors.extend(validate_identity_document_upload(files.get("id_back_document"), "ID back image"))
    return errors


def validate_identity_document_upload(upload, label):
    if not upload:
        return [f"{label} is required"]
    errors = []
    if getattr(upload, "size", 0) > IDENTITY_IMAGE_MAX_BYTES:
        errors.append(f"{label} is too large")
    content_type = str(getattr(upload, "content_type", "") or "").lower()
    if content_type and content_type not in IDENTITY_IMAGE_CONTENT_TYPES:
        errors.append(f"{label} must be a JPEG, PNG, or WebP image")
    try:
        position = upload.tell()
        header = upload.read(16)
        upload.seek(position)
    except (OSError, AttributeError):
        header = b""
    jpeg_signature = bytes.fromhex("ffd8ff")
    png_signature = bytes.fromhex("89504e470d0a1a0a")
    if header and not (header.startswith(jpeg_signature) or header.startswith(png_signature) or header.startswith(b"RIFF")):
        errors.append(f"{label} file signature is not a supported image")
    try:
        position = upload.tell()
        width, height = get_image_dimensions(upload)
        upload.seek(position)
        if width and height and (width < IDENTITY_IMAGE_MIN_WIDTH or height < IDENTITY_IMAGE_MIN_HEIGHT):
            errors.append(f"{label} resolution is too low")
    except (OSError, AttributeError, TypeError, ValueError):
        errors.append(f"{label} could not be read as an image")
    return errors


def normalize_identity_number(value):
    return re.sub(r"[^A-Z0-9]", "", str(value or "").upper())



def is_valid_generic_document_number(value):
    return bool(GENERIC_DOCUMENT_NUMBER_RE.fullmatch(str(value or "").strip()))


def normalize_phone(value):
    normalized = re.sub(r"[\s().-]", "", str(value or "").strip())
    if normalized.startswith("+2630"):
        return "+263" + normalized[5:]
    if normalized.startswith("2630"):
        return "+263" + normalized[4:]
    if normalized.startswith("0") and normalized[1:].isdigit() and len(normalized) in {9, 10}:
        return "+263" + normalized[1:]
    if normalized.startswith("263"):
        return "+" + normalized
    return normalized


def phone_lookup_values(phone):
    normalized = normalize_phone(phone)
    if not normalized:
        return []
    values = {normalized}
    if normalized.startswith("+"):
        values.add(normalized[1:])
    else:
        values.add(f"+{normalized}")
    if normalized.startswith("+263") and len(normalized) > 4:
        subscriber = normalized[4:]
        values.add(f"0{subscriber}")
        values.add(f"263{subscriber}")
        values.add(f"+2630{subscriber}")
        values.add(f"2630{subscriber}")
    return list(values)


def phone_identity_query(phone):
    values = phone_lookup_values(phone)
    if not values:
        return Q(pk__isnull=True)
    query = Q(phone__in=values)
    for value in values:
        query |= Q(username__iexact=value) | Q(email__iexact=value)
    return query


def normalize_email(value):
    return str(value or "").strip().lower()


def hash_otp(code):
    return hashlib.sha256(f"{settings.SECRET_KEY}:{str(code).strip()}".encode("utf-8")).hexdigest()


def contains_control_chars(value):
    return bool(CONTROL_CHAR_RE.search(str(value or "")))


def validate_text_field(value, field_name, max_length, required=False):
    text_value = str(value or "").strip()
    if required and not text_value:
        return f"{field_name} is required"
    if len(text_value) > max_length:
        return f"{field_name} must be {max_length} characters or fewer"
    if contains_control_chars(text_value):
        return f"{field_name} cannot contain control characters"
    return ""


def validate_email_field(email, required=False):
    error = validate_text_field(email, "Email address", EMAIL_MAX_LENGTH, required=required)
    if error or not email:
        return error
    try:
        validate_email_value(email)
    except ValidationError:
        return "Enter a valid email address"
    return ""


def validate_phone_field(phone, required=False):
    error = validate_text_field(phone, "Phone number", PHONE_MAX_LENGTH, required=required)
    if error or not phone:
        return error
    if not PHONE_RE.fullmatch(phone):
        return "Phone number must use 7 to 15 digits and may start with +"
    return ""


def validate_account_password(password):
    raw_password = str(password or "")
    if not raw_password:
        return "Password is required"
    if len(raw_password) < PASSWORD_MIN_LENGTH:
        return f"Password must be at least {PASSWORD_MIN_LENGTH} characters"
    if len(raw_password) > PASSWORD_MAX_LENGTH:
        return f"Password must be {PASSWORD_MAX_LENGTH} characters or fewer"
    if not raw_password.strip():
        return "Password must include at least one non-space character"
    if not raw_password.isprintable():
        return "Password cannot contain control characters"
    try:
        validate_password(raw_password)
    except ValidationError as exc:
        return " ".join(str(message) for message in exc.messages)
    return ""


def mask_phone(phone):
    value = str(phone or "")
    if len(value) <= 4:
        return value
    return f"{'*' * max(len(value) - 4, 0)}{value[-4:]}"


def mask_email(email):
    value = str(email or "")
    if "@" not in value:
        return value
    name, domain = value.split("@", 1)
    if len(name) <= 2:
        masked_name = name[:1] + "*"
    else:
        masked_name = f"{name[:1]}{'*' * (len(name) - 2)}{name[-1:]}"
    return f"{masked_name}@{domain}"


def validate_public_registration_payload(data):
    username = str(data.get("username") or data.get("email") or data.get("phone") or "").strip()
    email = normalize_email(data.get("email"))
    phone = normalize_phone(data.get("phone"))
    password = data.get("password") or ""
    role = data.get("account_type") or data.get("role") or User.Roles.TENANT
    role = normalise_choice(role, User.Roles, role)

    if role not in PUBLIC_ACCOUNT_ROLES:
        return None, "Public registration only supports tenant or landlord accounts"
    for error in (
        validate_text_field(username, "Username", USERNAME_MAX_LENGTH, required=True),
        validate_email_field(email, required=True),
        validate_text_field(data.get("name") or data.get("full_name", ""), "Full name", NAME_MAX_LENGTH),
    ):
        if error:
            return None, error
    password_error = validate_account_password(password)
    if password_error:
        return None, password_error
    if email and User.objects.filter(email__iexact=email).exists():
        return None, "An account with this email already exists"
    if User.objects.filter(username__iexact=username).exists():
        return None, "An account with this username already exists"

    return {
        "username": username,
        "email": email,
        "phone": phone,
        "password": password,
        "full_name": data.get("name") or data.get("full_name", ""),
        "role": role,
    }, ""


def create_registration_otp_challenge(data):
    cleaned, error = validate_public_registration_payload(data)
    if error:
        return None, "", error

    pending_match = Q(username__iexact=cleaned["username"])
    if cleaned["email"]:
        pending_match |= Q(email=cleaned["email"])
    PendingRegistrationOTP.objects.filter(status=PendingRegistrationOTP.Status.PENDING).filter(pending_match).update(status=PendingRegistrationOTP.Status.EXPIRED)

    otp_code = get_random_string(6, allowed_chars="0123456789")
    challenge = PendingRegistrationOTP.objects.create(
        username=cleaned["username"],
        email=cleaned["email"],
        phone=cleaned["phone"],
        full_name=cleaned["full_name"],
        role=cleaned["role"],
        password_hash=make_password(cleaned["password"]),
        code_hash=hash_otp(otp_code),
        sent_to=cleaned["email"],
        expires_at=timezone.now() + timedelta(minutes=settings.REGISTRATION_OTP_TTL_MINUTES),
    )
    try:
        send_registration_otp(challenge.email, otp_code)
    except ValueError as exc:
        challenge.status = PendingRegistrationOTP.Status.EXPIRED
        challenge.save(update_fields=["status", "updated_at"])
        return None, "", str(exc)
    return challenge, otp_code, ""


def send_registration_otp(email, code):
    subject = "Your Property24 account OTP"
    message = f"Your Property24 account OTP is {code}. It expires in {settings.REGISTRATION_OTP_TTL_MINUTES} minutes."
    validate_email_otp_provider()
    try:
        sent = send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [email], fail_silently=False)
    except Exception as exc:
        raise ValueError("OTP email could not be sent. Try again later") from exc
    if sent < 1:
        raise ValueError("OTP email could not be sent. Try again later")


def validate_email_otp_provider():
    backend = settings.EMAIL_BACKEND
    if backend.endswith("locmem.EmailBackend"):
        return
    if backend.endswith("console.EmailBackend"):
        raise ValueError("Email OTP provider is not configured")
    if backend.endswith("smtp.EmailBackend"):
        values = [settings.EMAIL_HOST, settings.EMAIL_HOST_USER, settings.EMAIL_HOST_PASSWORD]
        if any(not str(value or "").strip() or str(value).startswith("replace-me") for value in values):
            raise ValueError("Email OTP provider is not configured")


def create_public_account_from_otp(challenge):
    if User.objects.filter(email__iexact=challenge.email).exists() and challenge.email:
        return None, "An account with this email already exists"
    if User.objects.filter(username__iexact=challenge.username).exists():
        return None, "An account with this username already exists"
    if challenge.phone and User.objects.filter(Q(phone=challenge.phone) | Q(username__iexact=challenge.phone) | Q(email__iexact=challenge.phone)).exists():
        return None, "An account with this phone number already exists"


    try:
        user = User(
            username=challenge.username,
            email=challenge.email,
            password=challenge.password_hash,
            full_name=challenge.full_name,
            phone=challenge.phone,
            role=challenge.role,
            is_verified=False,
        )
        user.save()
    except IntegrityError:
        return None, "An account with these details already exists"
    return user, ""

def create_public_account(data, require_password=True):
    username = str(data.get("username") or data.get("email") or data.get("phone") or "").strip()
    if not username:
        return None, "username, email, or phone is required"

    role = data.get("account_type") or data.get("role") or User.Roles.TENANT
    role = normalise_choice(role, User.Roles, role)
    if role not in PUBLIC_ACCOUNT_ROLES:
        return None, "Public registration only supports tenant or landlord accounts"

    email = normalize_email(data.get("email"))
    phone = normalize_phone(data.get("phone"))
    full_name = str(data.get("name") or data.get("full_name", "")).strip()
    password = data.get("password") or ""
    for error in (
        validate_text_field(username, "Username", USERNAME_MAX_LENGTH, required=True),
        validate_email_field(email, required=require_password),
        validate_phone_field(phone, required=False),
        validate_text_field(full_name, "Full name", NAME_MAX_LENGTH),
    ):
        if error:
            return None, error
    if require_password:
        password_error = validate_account_password(password)
        if password_error:
            return None, password_error
    elif password and validate_account_password(password):
        return None, validate_account_password(password)
    if email and User.objects.filter(email__iexact=email).exists():
        return None, "An account with this email already exists"
    if User.objects.filter(username__iexact=username).exists():
        return None, "An account with this username already exists"
    if phone and User.objects.filter(phone_identity_query(phone)).exists():
        return None, "An account with this phone number already exists"
    if normalize_phone(username) and User.objects.filter(phone_identity_query(username)).exists():
        return None, "An account with this username or phone number already exists"

    try:
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password or get_random_string(32),
            full_name=full_name,
            phone=phone,
            role=role,
            is_verified=False,
            profile_picture_url=data.get("profile_picture_url") or data.get("profile_picture", ""),
            cover_photo_url=data.get("cover_photo_url") or data.get("cover_photo", ""),
            bio=data.get("bio", ""),
        )
    except IntegrityError:
        return None, "An account with these details already exists"
    return user, ""


def create_google_account(claims, data):
    requested_role = data.get("account_type") or data.get("role")
    role = normalise_choice(requested_role, User.Roles, requested_role) if requested_role else None
    if requested_role and role not in PUBLIC_ACCOUNT_ROLES:
        return None, "Google registration only supports tenant or landlord accounts"

    subject = claims["sub"]
    email = claims.get("email", "")
    email_verified = bool(claims.get("email_verified"))
    name = data.get("name") or claims.get("name") or email
    picture = claims.get("picture", "")
    phone = normalize_phone(data.get("phone"))

    for error in (
        validate_email_field(email, required=False),
        validate_text_field(name, "Full name", NAME_MAX_LENGTH),
    ):
        if error:
            return None, error

    user = User.objects.filter(google_subject=subject).first()
    if user is None and email:
        user = User.objects.filter(email__iexact=email).first()

    if user is None:
        if not role:
            return None, "Choose an account type before creating a Google account"
        phone_error = validate_phone_field(phone, required=False)
        if phone_error:
            return None, phone_error
        if phone and User.objects.filter(phone_identity_query(phone)).exists():
            return None, "An account with this phone number already exists"
        try:
            return (
                User.objects.create_user(
                    username=f"google:{subject}",
                    email=email,
                    password=get_random_string(32),
                    full_name=name,
                    phone=phone,
                    role=role,
                    is_verified=False,
                    auth_provider="google",
                    google_subject=subject,
                    google_email_verified=email_verified,
                    email_verified=email_verified,
                    profile_picture_url=picture,
                    cover_photo_url=data.get("cover_photo_url") or data.get("cover_photo", ""),
                    bio=data.get("bio", ""),
                ),
                "",
            )
        except IntegrityError:
            return None, "A Google account with these details already exists"

    if requested_role and user.role != role:
        return None, "This Google account is already linked to a different account type"

    changed_fields = []
    updates = {
        "auth_provider": "google",
        "google_subject": subject,
        "google_email_verified": email_verified,
    }
    if email and not user.email:
        updates["email"] = email
    if name and not user.full_name:
        updates["full_name"] = name
    if picture and not user.profile_picture and not user.profile_picture_url:
        updates["profile_picture_url"] = picture
    for field, value in updates.items():
        if getattr(user, field) != value:
            setattr(user, field, value)
            changed_fields.append(field)
    if changed_fields:
        user.save(update_fields=changed_fields)
    return user, ""


def record_ai_analysis(result, target_type="", target_id=None):
    return AIAnalysis.objects.create(
        analysis_type=result["analysis_type"],
        target_type=target_type,
        target_id=target_id,
        provider=result.get("provider", settings.AI_PROVIDER),
        model=result.get("model", settings.AI_MODEL),
        score=result.get("score", {}),
        confidence=Decimal(str(result.get("confidence", 0))),
        flags=result.get("flags", []),
        recommendation=result.get("recommendation", ""),
        summary=result.get("summary", ""),
        result=result,
    )


def serialize_ai_analysis(analysis):
    return {
        "id": analysis.id,
        "analysis_type": analysis.analysis_type,
        "target_type": analysis.target_type,
        "target_id": analysis.target_id,
        "provider": analysis.provider,
        "model": analysis.model,
        "score": analysis.score,
        "confidence": str(analysis.confidence),
        "flags": analysis.flags,
        "recommendation": analysis.recommendation,
        "summary": analysis.summary,
        "result": analysis.result,
        "created_at": analysis.created_at.isoformat(),
    }


def account_onboarding_complete(user):
    if not user or user.role not in VERIFICATION_REQUIRED_ROLES:
        return True
    if user.is_verified:
        return True
    return bool(user.email_verified)


def full_verification_required(user):
    return user.role in PUBLIC_ACCOUNT_ROLES and not user.is_verified


def serialize_user(user):
    return {
        "id": user.id,
        "name": str(user),
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
        "account_type": user.role,
        "verified": user.is_verified,
        "email_verified": user.email_verified,
        "phone_verified": user.phone_verified,
        "account_onboarding_complete": account_onboarding_complete(user),
        "profile_status": "verified" if user.is_verified else "account_ready" if account_onboarding_complete(user) else "onboarding_required",
        "verification_required": full_verification_required(user),
        "auth_provider": user.auth_provider,
        "google_email_verified": user.google_email_verified,
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
            return signed_media_url(media_file)
        except ValueError:
            return ""
    return ""


def serialize_account_context(user):
    return {
        "account_type": user.role,
        "is_verified": user.is_verified,
        "account_onboarding_complete": account_onboarding_complete(user),
        "email_verified": user.email_verified,
        "phone_verified": user.phone_verified,
        "can_switch_account_type": False,
        "visible_sections": ROLE_VISIBLE_SECTIONS.get(user.role, []),
        "capabilities": ROLE_CAPABILITIES.get(user.role, []),
        "hidden_sections": sorted({section for sections in ROLE_VISIBLE_SECTIONS.values() for section in sections} - set(ROLE_VISIBLE_SECTIONS.get(user.role, []))),
        "onboarding": {
            "required": user.role in VERIFICATION_REQUIRED_ROLES and not account_onboarding_complete(user),
            "requirements": [] if account_onboarding_complete(user) else ROLE_ONBOARDING_REQUIREMENTS.get(user.role, []),
            "next_endpoint": "/api/verifications/email-otp/" if user.role in VERIFICATION_REQUIRED_ROLES and not account_onboarding_complete(user) else "",
            "full_verification_required": full_verification_required(user),
            "full_verification_endpoint": "/api/verifications/" if full_verification_required(user) else "",
        },
    }


def media_asset_queryset_for_user(user):
    assets = MediaAsset.objects.filter(status=MediaAsset.Status.ACTIVE)
    if is_admin(user):
        return assets
    property_ids = [str(item) for item in user_properties(user).values_list("id", flat=True)] if user.role in {User.Roles.LANDLORD, User.Roles.AGENT} else []
    visible_property_photo_ids = [str(item) for item in PropertyPhoto.objects.filter(property_id__in=property_ids).values_list("id", flat=True)]
    visible_property_video_ids = [str(item) for item in PropertyVideo.objects.filter(property_id__in=property_ids).values_list("id", flat=True)]
    conversation_message_ids = [str(item) for item in Message.objects.filter(conversation__participants=user).values_list("id", flat=True)]
    maintenance_ids = [str(item) for item in MaintenanceRequest.objects.filter(Q(tenant=user) | Q(property__in=user_properties(user))).values_list("id", flat=True)]
    return assets.filter(
        Q(owner=user)
        | Q(access=MediaAsset.Access.PUBLIC, scope=MediaAsset.Scope.PROPERTY)
        | Q(source_model="message", source_id__in=conversation_message_ids)
        | Q(source_model="maintenance_request", source_id__in=maintenance_ids)
        | Q(source_model="property_photo", source_id__in=visible_property_photo_ids)
        | Q(source_model="property_video", source_id__in=visible_property_video_ids)
    ).distinct()


def can_access_media_asset(user, asset):
    if not user or not user.is_authenticated:
        return asset.access == MediaAsset.Access.PUBLIC and asset.scope == MediaAsset.Scope.PROPERTY and asset.status == MediaAsset.Status.ACTIVE
    return media_asset_queryset_for_user(user).filter(pk=asset.pk).exists()


def can_delete_media_asset(user, asset):
    if not user or not user.is_authenticated:
        return False
    if is_admin(user) or asset.owner_id == user.id:
        return True
    if asset.source_model in {"property_photo", "property_video"}:
        prop = property_for_media_asset(asset)
        return bool(prop and can_manage_property(user, prop))
    return False


def property_for_media_asset(asset):
    if asset.source_model == "property_photo":
        item = PropertyPhoto.objects.select_related("property").filter(pk=asset.source_id).first()
        return item.property if item else None
    if asset.source_model == "property_video":
        item = PropertyVideo.objects.select_related("property").filter(pk=asset.source_id).first()
        return item.property if item else None
    return None


def remove_media_assets(source_model, source_id, slot=None):
    assets = MediaAsset.objects.filter(source_model=source_model, source_id=str(source_id), status=MediaAsset.Status.ACTIVE)
    if slot:
        assets = assets.filter(metadata__slot=slot)
    for asset in assets:
        soft_delete_media_asset(asset)


def clear_media_source(asset):
    if asset.source_model == "property_photo":
        PropertyPhoto.objects.filter(pk=asset.source_id).delete()
    elif asset.source_model == "property_video":
        video = PropertyVideo.objects.filter(pk=asset.source_id).first()
        if video:
            video.video = ""
            video.external_url = ""
            video.save(update_fields=["video", "external_url"])
    elif asset.source_model == "message":
        message = Message.objects.filter(pk=asset.source_id).first()
        if message:
            message.attachment = ""
            message.attachment_url = ""
            message.attachment_type = ""
            message.attachment_name = ""
            message.save(update_fields=["attachment", "attachment_url", "attachment_type", "attachment_name"])
    elif asset.source_model == "maintenance_request":
        MaintenanceRequest.objects.filter(pk=asset.source_id).update(photo="")
    elif asset.source_model == "user":
        user = User.objects.filter(pk=asset.source_id).first()
        if user:
            slot = (asset.metadata or {}).get("slot")
            if slot == "profile_picture":
                user.profile_picture = ""
                user.profile_picture_url = ""
                user.save(update_fields=["profile_picture", "profile_picture_url"])
            elif slot == "cover_photo":
                user.cover_photo = ""
                user.cover_photo_url = ""
                user.save(update_fields=["cover_photo", "cover_photo_url"])


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
        "photos": [signed_media_url(photo.image) if photo.image else photo.caption for photo in prop.photos.all()],
        "videos": [video.external_url or (signed_media_url(video.video) if video.video else video.caption) for video in prop.videos.all()],
        "listing_views": prop.views_count,
        "saved_count": prop.saved_count or prop.saved_by.count(),
        "applications_count": getattr(prop, "application_total", prop.applications.count()),
        "comments_count": getattr(prop, "comment_total", prop.comments.count()),
    }


def serialize_property_photo(photo):
    return {
        "id": photo.id,
        "property_id": photo.property_id,
        "image": signed_media_url(photo.image) if photo.image else "",
        "caption": photo.caption,
        "sort_order": photo.sort_order,
    }


def serialize_property_comment(comment):
    return {
        "id": comment.id,
        "property_id": comment.property_id,
        "author": serialize_user(comment.author),
        "author_id": comment.author_id,
        "parent_id": comment.parent_id,
        "body": comment.body,
        "media_url": comment.media_url,
        "likes_count": comment.likes_count,
        "created_at": comment.created_at.isoformat(),
        "updated_at": comment.updated_at.isoformat(),
    }


def serialize_property_video(video):
    return {
        "id": video.id,
        "property_id": video.property_id,
        "video": signed_media_url(video.video) if video.video else "",
        "external_url": video.external_url,
        "caption": video.caption,
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
        "due_date": serialize_date(payment.due_date) if payment.due_date else None,
        "paid_at": payment.paid_at.isoformat() if payment.paid_at else None,
        "created_at": payment.created_at.isoformat(),
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
        "photo": signed_media_url(ticket.photo) if ticket.photo else "",
        "status": ticket.status,
        "priority": ticket.priority,
        "updated_at": ticket.updated_at.isoformat(),
    }


def serialize_verification(verification, acting_user=None):
    return {
        "id": str(verification.public_id),
        "user_id": verification.user_id,
        "name": str(verification.user),
        "role": verification.role,
        "checks": verification.checks,
        "phone_verified": verification.phone_verified,
        "email_verified": verification.email_verified,
        "privacy_notice_accepted": verification.privacy_notice_accepted,
        "document_type": verification.document_type,
        "residential_address": verification.residential_address,
        "address_gps_confirmed": verification.address_gps_confirmed,
        "proof_of_address_document_uploaded": bool(verification.proof_of_address_document),
        "proof_of_address_confirmed": verification.proof_of_address_confirmed,
        "politically_exposed_person": verification.politically_exposed_person,
        "declaration_accepted": verification.declaration_accepted,
        "id_front_document_uploaded": bool(verification.id_front_document),
        "id_back_document_uploaded": bool(verification.id_back_document),
        "extracted_national_id_number": verification.extracted_national_id_number,
        "verification_method": verification.verification_method,
        "verification_provider": verification.verification_provider,
        "verification_score": str(verification.verification_score) if verification.verification_score is not None else "",
        "failure_reason": verification.failure_reason if is_admin(acting_user) else "",
        "identity_verified": verification.status in {VerificationRequest.Status.VERIFIED, VerificationRequest.Status.APPROVED},
        "identity_confirmed": verification.identity_confirmed,
        "liveness_document_uploaded": bool(verification.liveness_document),
        "selfie_document_uploaded": bool(verification.selfie_document),
        "ownership_or_authorization_document_uploaded": bool(verification.ownership_or_authorization_document),
        "estate_agency_registration": verification.estate_agency_registration,
        "agency_name": verification.agency_name,
        "contact_details": verification.contact_details,
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
    receipts = [serialize_message_receipt(receipt) for receipt in message.receipts.select_related("user").all()]
    active_receipts = [receipt for receipt in receipts if str(receipt["user_id"]) != str(message.sender_id)]
    if active_receipts and all(receipt.get("read_at") for receipt in active_receipts):
        delivery_status = "read"
    elif active_receipts and all(receipt.get("delivered_at") for receipt in active_receipts):
        delivery_status = "delivered"
    else:
        delivery_status = "sent"
    is_deleted = bool(message.deleted_at)
    return {
        "id": message.id,
        "conversation_id": message.conversation_id,
        "sender_id": message.sender_id,
        "sender": str(message.sender),
        "body": "This message was deleted" if is_deleted else message.body,
        "client_message_id": message.client_message_id,
        "attachment_url": "" if is_deleted else message_attachment_url(message),
        "attachment_type": "" if is_deleted else message.attachment_type,
        "attachment_name": "" if is_deleted else message.attachment_name,
        "created_at": message.created_at.isoformat(),
        "read_at": message.read_at.isoformat() if message.read_at else None,
        "edited_at": message.edited_at.isoformat() if message.edited_at else None,
        "deleted_at": message.deleted_at.isoformat() if message.deleted_at else None,
        "deleted": is_deleted,
        "delivery_status": delivery_status,
        "receipts": receipts,
    }


def serialize_message_receipt(receipt):
    return {
        "user_id": receipt.user_id,
        "delivered_at": receipt.delivered_at.isoformat() if receipt.delivered_at else None,
        "read_at": receipt.read_at.isoformat() if receipt.read_at else None,
    }


def message_attachment_url(message):
    if message.attachment:
        try:
            return signed_media_url(message.attachment)
        except Exception:
            return ""
    return message.attachment_url


def serialize_call_session(call):
    return {
        "id": call.id,
        "conversation_id": call.conversation_id,
        "initiator_id": call.initiator_id,
        "mode": call.mode,
        "status": call.status,
        "created_at": call.created_at.isoformat(),
        "ended_at": call.ended_at.isoformat() if call.ended_at else None,
    }


def serialize_supplier_follow(supplier, following):
    return {
        "supplier_id": supplier.id,
        "following": following,
        "followers_count": supplier.supplier_followers.count(),
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
        "assigned_admin_id": report.assigned_admin_id,
        "assigned_admin": str(report.assigned_admin) if report.assigned_admin else "",
        "created_at": report.created_at.isoformat(),
        "resolved_at": report.resolved_at.isoformat() if report.resolved_at else None,
    }


def serialize_commission(commission):
    return {
        "id": commission.id,
        "agent_id": commission.agent_id,
        "agent": str(commission.agent),
        "property_id": commission.property_id,
        "property": commission.property.title,
        "lease_id": commission.lease_id,
        "amount": str(commission.amount),
        "status": commission.status,
        "created_at": commission.created_at.isoformat(),
    }


def serialize_date(value):
    return value.isoformat() if hasattr(value, "isoformat") else str(value)
    if acting_user.role == User.Roles.TENANT and ticket.tenant_id == acting_user.id:
        allowed = {"issue", "category", "description", "photo"}
        if set(data.keys()) - allowed:
            return forbidden()
