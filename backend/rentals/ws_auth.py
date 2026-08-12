from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser

from .auth import user_from_token


class JwtAuthMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        token = token_from_scope(scope)
        user = AnonymousUser()
        auth_error = "Missing token"
        if token:
            user, auth_error = await database_sync_to_async(user_from_token)(token, expected_type="access")
            if user is None:
                user = AnonymousUser()
        scope["user"] = user
        scope["auth_error"] = auth_error
        return await self.app(scope, receive, send)


def token_from_scope(scope):
    query = parse_qs(scope.get("query_string", b"").decode("utf-8"))
    if query.get("token"):
        return query["token"][0]
    for name, value in scope.get("headers", []):
        if name == b"authorization" and value.startswith(b"Bearer "):
            return value.decode("utf-8").removeprefix("Bearer ").strip()
    return ""


def JwtAuthMiddlewareStack(inner):
    return JwtAuthMiddleware(inner)
