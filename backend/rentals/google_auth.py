from django.conf import settings


class GoogleAuthError(ValueError):
    pass


def verify_google_id_token(id_token_value):
    if not settings.GOOGLE_SIGN_IN_ENABLED:
        raise GoogleAuthError("Google sign-in is not enabled")
    if not settings.GOOGLE_CLIENT_IDS:
        raise GoogleAuthError("Google client IDs are not configured")

    try:
        from google.auth.transport import requests
        from google.oauth2 import id_token
    except ImportError as exc:
        raise GoogleAuthError("google-auth is required for Google sign-in") from exc

    try:
        claims = id_token.verify_oauth2_token(id_token_value, requests.Request())
    except ValueError as exc:
        raise GoogleAuthError("Invalid Google ID token") from exc

    if claims.get("aud") not in settings.GOOGLE_CLIENT_IDS:
        raise GoogleAuthError("Google token audience is not allowed")
    if claims.get("iss") not in {"accounts.google.com", "https://accounts.google.com"}:
        raise GoogleAuthError("Google token issuer is not allowed")
    if not claims.get("sub"):
        raise GoogleAuthError("Google token subject is missing")
    if not claims.get("email"):
        raise GoogleAuthError("Google token email is missing")

    return claims
