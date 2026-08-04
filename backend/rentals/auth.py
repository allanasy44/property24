import base64
import hashlib
import hmac
import json
import time

from django.conf import settings
from django.contrib.auth import get_user_model


def issue_token_pair(user):
    return {
        "access": make_token(user, "access", settings.JWT_ACCESS_TOKEN_SECONDS),
        "refresh": make_token(user, "refresh", settings.JWT_REFRESH_TOKEN_SECONDS),
        "token_type": "Bearer",
        "expires_in": settings.JWT_ACCESS_TOKEN_SECONDS,
    }


def make_token(user, token_type, lifetime_seconds):
    now = int(time.time())
    payload = {
        "sub": str(user.id),
        "username": user.get_username(),
        "role": user.role,
        "type": token_type,
        "iat": now,
        "exp": now + lifetime_seconds,
    }
    header = {"alg": "HS256", "typ": "JWT"}
    signing_input = f"{b64_json(header)}.{b64_json(payload)}"
    signature = sign(signing_input)
    return f"{signing_input}.{signature}"


def user_from_authorization_header(header):
    if not header or not header.startswith("Bearer "):
        return None, "Authorization header must be Bearer token"
    return user_from_token(header.removeprefix("Bearer ").strip(), expected_type="access")


def user_from_token(token, expected_type="access"):
    try:
        payload = decode_token(token)
    except ValueError as exc:
        return None, str(exc)
    if payload.get("type") != expected_type:
        return None, f"{expected_type} token required"
    User = get_user_model()
    try:
        return User.objects.get(pk=payload["sub"], is_active=True), ""
    except User.DoesNotExist:
        return None, "Token user was not found"


def decode_token(token):
    try:
        header_b64, payload_b64, signature = token.split(".", 2)
    except ValueError as exc:
        raise ValueError("Malformed token") from exc

    signing_input = f"{header_b64}.{payload_b64}"
    expected = sign(signing_input)
    if not hmac.compare_digest(signature, expected):
        raise ValueError("Invalid token signature")

    payload = json.loads(b64_decode(payload_b64).decode("utf-8"))
    if int(payload.get("exp", 0)) < int(time.time()):
        raise ValueError("Token has expired")
    return payload


def sign(value):
    digest = hmac.new(settings.JWT_SECRET.encode("utf-8"), value.encode("utf-8"), hashlib.sha256).digest()
    return b64_encode(digest)


def b64_json(value):
    return b64_encode(json.dumps(value, separators=(",", ":")).encode("utf-8"))


def b64_encode(value):
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def b64_decode(value):
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)
