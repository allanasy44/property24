from channels.db import database_sync_to_async
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator
from django.test import TransactionTestCase, override_settings

from .auth import issue_token_pair
from .models import Conversation, MessageReceipt, User
from .routing import websocket_urlpatterns
from .ws_auth import JwtAuthMiddlewareStack


@override_settings(
    CHANNEL_LAYERS={
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }
)
class ChatRealtimeTests(TransactionTestCase):
    reset_sequences = True

    async def test_new_conversation_join_receives_message_and_receipts(self):
        first_token, second_token = await database_sync_to_async(
            self._create_users_and_tokens
        )()
        application = JwtAuthMiddlewareStack(URLRouter(websocket_urlpatterns))
        first_socket = WebsocketCommunicator(
            application,
            f"/ws/live/?token={first_token}",
        )
        second_socket = WebsocketCommunicator(
            application,
            f"/ws/live/?token={second_token}",
        )

        try:
            first_connected, _ = await first_socket.connect()
            second_connected, _ = await second_socket.connect()
            self.assertTrue(first_connected)
            self.assertTrue(second_connected)
            await first_socket.receive_json_from()
            await second_socket.receive_json_from()

            conversation_id = await database_sync_to_async(
                self._create_conversation
            )()

            for socket in (first_socket, second_socket):
                await socket.send_json_to({
                    "type": "conversation.join",
                    "conversation_id": str(conversation_id),
                })
                joined = await socket.receive_json_from()
                self.assertEqual(joined["type"], "conversation.joined")

            response = await database_sync_to_async(self.client.post)(
                f"/api/conversations/{conversation_id}/messages/",
                data='{"body":"Hello in real time"}',
                content_type="application/json",
                HTTP_AUTHORIZATION=f"Bearer {first_token}",
            )
            self.assertEqual(response.status_code, 201, response.content)

            for socket in (first_socket, second_socket):
                created = await socket.receive_json_from()
                self.assertEqual(created["type"], "message.created")
                self.assertEqual(created["payload"]["body"], "Hello in real time")

            await second_socket.send_json_to({
                "type": "delivered",
                "conversation_id": str(conversation_id),
            })
            for socket in (first_socket, second_socket):
                delivered = await socket.receive_json_from()
                self.assertEqual(delivered["type"], "messages.delivered")
            delivered_at, read_at = await database_sync_to_async(
                self._receipt_timestamps
            )(response.json()["id"])
            self.assertIsNotNone(delivered_at)
            self.assertIsNone(read_at)

            await second_socket.send_json_to({
                "type": "read",
                "conversation_id": str(conversation_id),
            })
            for socket in (first_socket, second_socket):
                read = await socket.receive_json_from()
                self.assertEqual(read["type"], "messages.read")
            delivered_at, read_at = await database_sync_to_async(
                self._receipt_timestamps
            )(response.json()["id"])
            self.assertIsNotNone(delivered_at)
            self.assertIsNotNone(read_at)
        finally:
            await first_socket.disconnect()
            await second_socket.disconnect()

    def _create_users_and_tokens(self):
        first = User.objects.create_user(
            username="live-first",
            email="live-first@example.test",
            password="test-password-123",
            role=User.Roles.TENANT,
        )
        second = User.objects.create_user(
            username="live-second",
            email="live-second@example.test",
            password="test-password-123",
            role=User.Roles.TENANT,
        )
        return issue_token_pair(first)["access"], issue_token_pair(second)["access"]

    def _create_conversation(self):
        conversation = Conversation.objects.create(title="Realtime test")
        conversation.participants.add(
            User.objects.get(username="live-first"),
            User.objects.get(username="live-second"),
        )
        return conversation.id

    def _receipt_timestamps(self, message_id):
        receipt = MessageReceipt.objects.get(
            message_id=message_id,
            user__username="live-second",
        )
        return receipt.delivered_at, receipt.read_at
