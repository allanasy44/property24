from django.urls import path

from .consumers import ConversationConsumer

websocket_urlpatterns = [
    path("ws/conversations/", ConversationConsumer.as_asgi()),
    path("ws/live/", ConversationConsumer.as_asgi()),
]
