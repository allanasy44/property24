"""Phone number login backed exclusively by Twilio Verify."""
import hashlib
import hmac
import re
import uuid
from datetime import timedelta

import phonenumbers
import requests
from django.conf import settings
from django.db import transaction
from django.db.models import Sum
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .auth import issue_token_pair
from .models import PhoneLoginChallenge, User
from .views import json_error, normalize_phone, phone_lookup_values, request_json, serialize_account_context, serialize_user


def _normalize_phone(raw, region):
    raw = str(raw or "").strip()
    region = str(region or "ZW").upper()
    if len(raw) > 40 or not re.fullmatch(r"[+0-9 ().-]+", raw):
        raise ValueError
    parsed = phonenumbers.parse(raw, region)
    if not phonenumbers.is_valid_number(parsed):
        raise ValueError
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


def _client_ip(request):
    # Trust only REMOTE_ADDR; forwarded headers require deployment proxy configuration.
    return request.META.get("REMOTE_ADDR", "")[:64]


def _ip_hash(ip):
    return hmac.new(settings.SECRET_KEY.encode(), ip.encode(), hashlib.sha256).hexdigest()


def _challenge_uuid(value):
    try:
        return uuid.UUID(str(value))
    except (ValueError, TypeError, AttributeError):
        return None


def _provider(path, payload):
    sid = getattr(settings, "TWILIO_VERIFY_SERVICE_SID", "")
    username = getattr(settings, "TWILIO_API_KEY_SID", "") or getattr(settings, "TWILIO_ACCOUNT_SID", "")
    password = getattr(settings, "TWILIO_API_KEY_SECRET", "") or getattr(settings, "TWILIO_AUTH_TOKEN", "")
    if not (sid and username and password):
        return None
    try:
        response = requests.post(
            f"https://verify.twilio.com/v2/Services/{sid}/{path}",
            data=payload, auth=(username, password), timeout=(3.05, 8),
        )
    except requests.RequestException:
        return None
    if response.status_code >= 500 or response.status_code in (401, 403, 404, 429):
        return None
    if response.status_code >= 400:
        return {}
    try:
        return response.json()
    except ValueError:
        return None


def _eligible_user(phone):
    candidates = User.objects.filter(phone__in=phone_lookup_values(phone)).only("id", "phone", "is_active", "phone_verified", "role")
    matches = [candidate for candidate in candidates if normalize_phone(candidate.phone) == phone]
    if len(matches) != 1:
        return None
    user = matches[0]
    if not user or not user.is_active or not user.phone_verified or user.role == User.Roles.ADMIN:
        return None
    return user


@csrf_exempt
@require_POST
def phone_login_send(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid request")
    ip = _client_ip(request)
    ip_hash = _ip_hash(ip)
    prior_id = _challenge_uuid(data.get("challenge_id"))
    now = timezone.now()
    try:
        phone = _normalize_phone(data.get("phone"), data.get("country", "ZW"))
    except (ValueError, phonenumbers.NumberParseException):
        return json_error("Enter a valid phone number")

    # Shared database limits: rolling hour and day per destination/IP.
    if PhoneLoginChallenge.objects.filter(ip_hash=ip_hash, created_at__gte=now-timedelta(hours=1)).count() >= settings.PHONE_LOGIN_SEND_LIMIT_IP_HOUR:
        return JsonResponse({"error": "Please wait before trying again."}, status=429)
    if PhoneLoginChallenge.objects.filter(destination=phone, created_at__gte=now-timedelta(hours=1)).count() >= settings.PHONE_LOGIN_SEND_LIMIT_PHONE_HOUR:
        return JsonResponse({"error": "Please wait before trying again."}, status=429)
    recent = PhoneLoginChallenge.objects.filter(destination=phone, created_at__gte=now-timedelta(hours=1)).order_by("-created_at").first()
    if recent and recent.last_sent_at:
        delay = min(30 * (2 ** max(recent.send_count-1, 0)), 300)
        remaining = delay - int((now-recent.last_sent_at).total_seconds())
        if remaining > 0:
            return JsonResponse({"error": "Please wait before requesting another code.", "resend_after": remaining}, status=429)
    if prior_id:
        PhoneLoginChallenge.objects.filter(pk=prior_id, status="pending").update(status="replaced")
    # Invalidate earlier active challenges for this destination before issuing a newer one.
    PhoneLoginChallenge.objects.filter(destination=phone, status="pending").update(status="replaced")
    user = _eligible_user(phone)
    challenge = PhoneLoginChallenge.objects.create(
        destination=phone, user=user, purpose="login", created_at=now,
        expires_at=now+timedelta(seconds=settings.TWILIO_VERIFY_VALIDITY_SECONDS), last_sent_at=now, send_count=1,
        ip_hash=ip_hash,
    )
    sent = _provider("Verifications", {"To": phone, "Channel": "sms"})
    if not sent or not sent.get("sid"):
        challenge.status = "unavailable"
        challenge.save(update_fields=["status"])
        return JsonResponse({"error": "We couldn't send a code right now. Please try again later."}, status=503)
    return JsonResponse({"challenge_id": str(challenge.pk), "destination": _mask(phone), "resend_after": 30})


def _mask(phone):
    return phone[:4] + "••••" + phone[-2:]


@csrf_exempt
@require_POST
def phone_login_cancel(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid request")
    PhoneLoginChallenge.objects.filter(
        pk=_challenge_uuid(data.get("challenge_id")), status="pending", purpose="login"
    ).update(status="replaced")
    return JsonResponse({"ok": True})


@csrf_exempt
@require_POST
def phone_login_resend(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid request")
    now = timezone.now()
    challenge_id = _challenge_uuid(data.get("challenge_id"))
    with transaction.atomic():
        challenge = PhoneLoginChallenge.objects.select_for_update().filter(pk=challenge_id, status="pending", purpose="login").first()
        if not challenge or challenge.expires_at <= now or challenge.send_count >= settings.PHONE_LOGIN_MAX_SENDS_PER_CHALLENGE:
            return JsonResponse({"error": "This verification has expired. Start again."}, status=400)
        delay = min(30 * (2 ** (challenge.send_count-1)), 300)
        if challenge.last_sent_at and (now-challenge.last_sent_at).total_seconds() < delay:
            remaining = delay - int((now-challenge.last_sent_at).total_seconds())
            return JsonResponse({"error": "Please wait before requesting another code.", "resend_after": remaining}, status=429)
        challenge.send_count += 1
        challenge.last_sent_at = now
        challenge.save(update_fields=["send_count", "last_sent_at"])
    sent = _provider("Verifications", {"To": challenge.destination, "Channel": "sms"})
    if not sent or not sent.get("sid"):
        return JsonResponse({"error": "We couldn't send a code right now. Please try again later."}, status=503)
    return JsonResponse({"challenge_id": str(challenge_id), "destination": _mask(challenge.destination), "resend_after": min(30 * 2 ** (challenge.send_count-1), 300)})


@csrf_exempt
@require_POST
def phone_login_check(request):
    data = request_json(request)
    if data is None:
        return json_error("Invalid request")
    challenge_id = _challenge_uuid(data.get("challenge_id"))
    code = str(data.get("code") or "").strip()
    if not re.fullmatch(r"[0-9]{4,10}", code):
        return JsonResponse({"error": "Enter the verification code."}, status=400)
    now = timezone.now()
    with transaction.atomic():
        challenge = PhoneLoginChallenge.objects.select_for_update().filter(pk=challenge_id, status="pending", purpose="login").first()
        if not challenge or challenge.expires_at <= now or challenge.checking or challenge.check_count >= settings.PHONE_LOGIN_MAX_CHECKS_PER_CHALLENGE:
            return JsonResponse({"error": "The code is incorrect or expired. Request a new code."}, status=400)
        recent_checks = PhoneLoginChallenge.objects.filter(created_at__gte=now-timedelta(hours=1))
        ip_total = recent_checks.filter(ip_hash=challenge.ip_hash).aggregate(total=Sum("check_count"))["total"] or 0
        phone_total = recent_checks.filter(destination=challenge.destination).aggregate(total=Sum("check_count"))["total"] or 0
        if ip_total >= settings.PHONE_LOGIN_CHECK_LIMIT_IP_HOUR or phone_total >= settings.PHONE_LOGIN_CHECK_LIMIT_PHONE_HOUR:
            return JsonResponse({"error": "Please wait before trying another code."}, status=429)
        challenge.check_count += 1
        challenge.checking = True
        challenge.save(update_fields=["check_count", "checking"])
        destination = challenge.destination
    result = _provider("VerificationCheck", {"To": destination, "Code": code})
    with transaction.atomic():
        challenge = PhoneLoginChallenge.objects.select_for_update().filter(pk=challenge_id).first()
        if not challenge or challenge.status != "pending":
            return JsonResponse({"error": "The code is incorrect or expired. Request a new code."}, status=400)
        challenge.checking = False
        if not result:
            challenge.save(update_fields=["checking"])
            return JsonResponse({"error": "Verification is temporarily unavailable. Please try again."}, status=503)
        if result.get("status") != "approved":
            challenge.save(update_fields=["checking"])
            return JsonResponse({"error": "The code is incorrect or expired. Request a new code."}, status=400)
        challenge.status = "consumed"
        challenge.save(update_fields=["checking", "status"])
        user = challenge.user
        if not user or not user.is_active or not user.phone_verified or user.role == User.Roles.ADMIN:
            return JsonResponse({"error": "No eligible account was found. Use the existing registration or sign-in options."}, status=400)
        return JsonResponse({"user": serialize_user(user), "account": serialize_account_context(user), "tokens": issue_token_pair(user)})
