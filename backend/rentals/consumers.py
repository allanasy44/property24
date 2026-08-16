from __future__ import annotations

import time

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

from .chat_services import (
    audit_event,
    broadcast_presence,
    conversation_group_name,
    create_call,
    create_text_message,
    end_call,
    get_authorized_conversation,
    mark_conversation_delivered,
    mark_conversation_read,
    touch_user_presence,
    user_conversation_ids,
    user_group_name,
)
from .models import CallSession, SecurityAuditEvent
from .notification_services import send_call_push, send_chat_message_push
from .views import serialize_call_session, serialize_message

ALLOWED_INBOUND_EVENTS = {"message.send", "typing", "delivered", "read", "call.start", "call.end", "call.signal", "presence.ping"}
MAX_EVENTS_PER_MINUTE = 80
MAX_SIGNAL_BYTES = 12000
ALLOWED_SIGNAL_TYPES = {"offer", "answer", "ice-candidate", "ready", "reject", "busy", "mute", "unmute", "camera-off", "camera-on"}


class ConversationConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get("user") or AnonymousUser()
        self.ip_address = client_ip(self.scope)
        self.user_agent = header_value(self.scope, b"user-agent")
        self.event_times = []
        self.conversation_ids = []

        if not self.user.is_authenticated:
            await self.audit("websocket_denied", category=SecurityAuditEvent.Category.AUTHENTICATION, severity=SecurityAuditEvent.Severity.MEDIUM, metadata={"reason": self.scope.get("auth_error")})
            await self.close(code=4401)
            return

        self.conversation_ids = await database_sync_to_async(user_conversation_ids)(self.user)
        for conversation_id in self.conversation_ids:
            await self.channel_layer.group_add(conversation_group_name(conversation_id), self.channel_name)
        await self.channel_layer.group_add(user_group_name(self.user.id), self.channel_name)

        last_seen_at = await database_sync_to_async(touch_user_presence)(self.user)
        await self.accept()
        await self.audit("websocket_connected", category=SecurityAuditEvent.Category.PRESENCE, metadata={"conversation_count": len(self.conversation_ids)})
        await database_sync_to_async(broadcast_presence)(self.user, True, self.conversation_ids)
        await self.send_json({
            "type": "connection.ready",
            "payload": {
                "user_id": str(self.user.id),
                "conversation_ids": [str(item) for item in self.conversation_ids],
                "last_seen_at": last_seen_at.isoformat() if last_seen_at else None,
            },
        })

    async def disconnect(self, close_code):
        if not getattr(self, "user", None) or not self.user.is_authenticated:
            return
        await database_sync_to_async(touch_user_presence)(self.user)
        await database_sync_to_async(broadcast_presence)(self.user, False, self.conversation_ids)
        await self.audit("websocket_disconnected", category=SecurityAuditEvent.Category.PRESENCE, metadata={"close_code": close_code})
        for conversation_id in self.conversation_ids:
            await self.channel_layer.group_discard(conversation_group_name(conversation_id), self.channel_name)
        await self.channel_layer.group_discard(user_group_name(self.user.id), self.channel_name)

    async def receive_json(self, content, **kwargs):
        if not await self.within_rate_limit():
            await self.audit("websocket_rate_limited", category=SecurityAuditEvent.Category.RATE_LIMIT, severity=SecurityAuditEvent.Severity.HIGH)
            await self.send_error("Too many chat events. Please slow down.")
            await self.close(code=4408)
            return

        event_type = str(content.get("type") or "")
        if event_type not in ALLOWED_INBOUND_EVENTS:
            await self.audit("websocket_invalid_event", severity=SecurityAuditEvent.Severity.LOW, metadata={"event_type": event_type})
            await self.send_error("Unsupported chat event")
            return

        if event_type == "presence.ping":
            await database_sync_to_async(touch_user_presence)(self.user)
            await self.send_json({"type": "presence.pong", "payload": {"server_time": int(time.time())}})
            return

        conversation_id = content.get("conversation_id")
        conversation = await database_sync_to_async(get_authorized_conversation)(self.user, conversation_id)
        if conversation is None:
            await self.audit("conversation_access_denied", category=SecurityAuditEvent.Category.AUTHORIZATION, severity=SecurityAuditEvent.Severity.HIGH, metadata={"conversation_id": conversation_id, "event_type": event_type})
            await self.send_error("You cannot access this conversation")
            return

        if event_type == "message.send":
            await self.handle_message_send(conversation, content)
        elif event_type == "typing":
            await self.handle_typing(conversation, content)
        elif event_type == "delivered":
            await self.handle_delivered(conversation)
        elif event_type == "read":
            await self.handle_read(conversation)
        elif event_type == "call.start":
            await self.handle_call_start(conversation, content)
        elif event_type == "call.end":
            await self.handle_call_end(conversation, content)
        elif event_type == "call.signal":
            await self.handle_call_signal(conversation, content)

    async def handle_message_send(self, conversation, content):
        try:
            message = await database_sync_to_async(create_text_message)(conversation, self.user, content.get("body"), content.get("client_id"))
        except ValueError as exc:
            await self.send_error(str(exc))
            return
        payload = await database_sync_to_async(serialize_message)(message)
        payload["client_id"] = str(content.get("client_id") or "")[:80]
        await self.audit("message_created", metadata={"conversation_id": conversation.id, "message_id": message.id})
        await self.channel_layer.group_send(conversation_group_name(conversation.id), {"type": "chat.event", "event": "message.created", "payload": payload})
        await database_sync_to_async(send_chat_message_push)(message)

    async def handle_typing(self, conversation, content):
        is_typing = bool(content.get("is_typing"))
        await self.channel_layer.group_send(conversation_group_name(conversation.id), {
            "type": "chat.event",
            "event": "typing",
            "payload": {
                "conversation_id": str(conversation.id),
                "user_id": str(self.user.id),
                "name": str(self.user),
                "is_typing": is_typing,
            },
        })

    async def handle_delivered(self, conversation):
        message_ids = await database_sync_to_async(mark_conversation_delivered)(conversation, self.user)
        if message_ids:
            await self.audit("messages_delivered", metadata={"conversation_id": conversation.id, "count": len(message_ids)})
            await self.channel_layer.group_send(conversation_group_name(conversation.id), {
                "type": "chat.event",
                "event": "messages.delivered",
                "payload": {
                    "conversation_id": str(conversation.id),
                    "recipient_id": str(self.user.id),
                    "message_ids": [str(item) for item in message_ids],
                },
            })

    async def handle_read(self, conversation):
        message_ids = await database_sync_to_async(mark_conversation_read)(conversation, self.user)
        if message_ids:
            await self.audit("messages_read", metadata={"conversation_id": conversation.id, "count": len(message_ids)})
            await self.channel_layer.group_send(conversation_group_name(conversation.id), {
                "type": "chat.event",
                "event": "messages.read",
                "payload": {
                    "conversation_id": str(conversation.id),
                    "reader_id": str(self.user.id),
                    "message_ids": [str(item) for item in message_ids],
                },
            })

    async def handle_call_start(self, conversation, content):
        try:
            call = await database_sync_to_async(create_call)(conversation, self.user, content.get("mode"))
        except ValueError as exc:
            await self.send_error(str(exc))
            return
        payload = await database_sync_to_async(serialize_call_session)(call)
        await self.audit("call_started", metadata={"conversation_id": conversation.id, "call_id": call.id, "mode": call.mode})
        await self.channel_layer.group_send(conversation_group_name(conversation.id), {"type": "chat.event", "event": "call.started", "payload": payload})
        await database_sync_to_async(send_call_push)(call)

    async def handle_call_signal(self, conversation, content):
        signal_type = str(content.get("signal_type") or "")[:40]
        if signal_type not in ALLOWED_SIGNAL_TYPES:
            await self.send_error("Unsupported call signal")
            return
        try:
            call_id = int(content.get("call_id"))
            call = await database_sync_to_async(CallSession.objects.get)(pk=call_id, conversation=conversation)
        except (TypeError, ValueError, CallSession.DoesNotExist):
            await self.send_error("Call could not be found")
            return
        if call.status != CallSession.Status.RINGING:
            await self.send_error("Call is no longer active")
            return
        signal_payload = content.get("signal") or {}
        if len(str(signal_payload)) > MAX_SIGNAL_BYTES:
            await self.send_error("Call signal is too large")
            return
        target_user_id = str(content.get("target_user_id") or "")[:40]
        payload = {
            "conversation_id": str(conversation.id),
            "call_id": str(call.id),
            "sender_id": str(self.user.id),
            "target_user_id": target_user_id,
            "signal_type": signal_type,
            "signal": signal_payload,
            "sent_at": int(time.time()),
        }
        await self.audit("call_signal", metadata={"conversation_id": conversation.id, "call_id": call.id, "signal_type": signal_type})
        await self.channel_layer.group_send(conversation_group_name(conversation.id), {"type": "chat.event", "event": "call.signal", "payload": payload})

    async def handle_call_end(self, conversation, content):
        try:
            call = await database_sync_to_async(end_call)(conversation, content.get("call_id"), content.get("status") or CallSession.Status.ENDED)
        except (CallSession.DoesNotExist, ValueError):
            await self.send_error("Call could not be updated")
            return
        payload = await database_sync_to_async(serialize_call_session)(call)
        await self.audit("call_ended", metadata={"conversation_id": conversation.id, "call_id": call.id, "status": call.status})
        await self.channel_layer.group_send(conversation_group_name(conversation.id), {"type": "chat.event", "event": "call.ended", "payload": payload})

    async def chat_event(self, event):
        await self.send_json({"type": event["event"], "payload": event.get("payload", {})})

    async def within_rate_limit(self):
        now = time.monotonic()
        self.event_times = [item for item in self.event_times if now - item < 60]
        self.event_times.append(now)
        return len(self.event_times) <= MAX_EVENTS_PER_MINUTE

    async def send_error(self, message):
        await self.send_json({"type": "error", "payload": {"message": message}})

    async def audit(self, event_type, **kwargs):
        kwargs.setdefault("actor", self.user if getattr(self, "user", None) and self.user.is_authenticated else None)
        kwargs.setdefault("ip_address", self.ip_address)
        kwargs.setdefault("user_agent", self.user_agent)
        await database_sync_to_async(audit_event)(event_type, **kwargs)


def client_ip(scope):
    client = scope.get("client")
    if client:
        return client[0]
    return ""


def header_value(scope, name):
    for header_name, value in scope.get("headers", []):
        if header_name == name:
            return value.decode("utf-8", errors="ignore")
    return ""
