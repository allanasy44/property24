from ipaddress import ip_address
from urllib.parse import urlparse

from django.conf import settings


class SimpleCorsMiddleware:
    """CORS support for the mobile client during local and staging API use."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "OPTIONS":
            from django.http import HttpResponse

            response = HttpResponse()
        else:
            response = self.get_response(request)

        origin = request.headers.get("Origin")
        allowed_origins = getattr(settings, "CORS_ALLOWED_ORIGINS", [])
        if origin in allowed_origins or is_debug_local_origin(origin):
            response["Access-Control-Allow-Origin"] = origin
            response["Vary"] = "Origin"
        response["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-CSRFToken"
        return response


def is_debug_local_origin(origin):
    if not origin or not getattr(settings, "DEBUG", False):
        return False
    try:
        hostname = urlparse(origin).hostname
    except ValueError:
        return False
    if hostname in {"localhost", "127.0.0.1"}:
        return True
    try:
        return ip_address(hostname).is_private
    except ValueError:
        return False
