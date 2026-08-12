import os

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

from rentals.routing import websocket_urlpatterns
from rentals.ws_auth import JwtAuthMiddlewareStack


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "property24_backend.settings")

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": AllowedHostsOriginValidator(JwtAuthMiddlewareStack(URLRouter(websocket_urlpatterns))),
})
