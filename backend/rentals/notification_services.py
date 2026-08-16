from __future__ import annotations

import json
from urllib import error as urlerror
from urllib import request as urlrequest

from django.conf import settings

from .models import Conversation, Message, PushDevice, SecurityAuditEvent
from .chat_services import audit_event, safe_metadata

MAX_PUSH_BODY_LENGTH = 180
EXPO_ERROR_TOKEN_INVALID = {"DeviceNotRegistered", "InvalidCredentials"}


def send_chat_message_push(message: Message):
    conversation = message.conversation
    title = conversation.property.title if conversation.property_id else "Property24 chat"
    body = message.body[:MAX_PUSH_BODY_LENGTH]
    recipient_ids = conversation.participants.exclude(id=message.sender_id).values_list("id", flat=True)
    return send_push_to_users(
        recipient_ids,
        title=str(title),
        body=f"{message.sender}: {body}",
        data={
            "kind": "chat_message",
            "conversation_id": str(conversation.id),
            "message_id": str(message.id),
            "property_id": str(conversation.property_id or ""),
            "sender_id": str(message.sender_id),
        },
        actor=message.sender,
        event_type="push_chat_message_sent",
    )


def send_call_push(call):
    conversation = call.conversation
    title = "Incoming video call" if call.mode == "video" else "Incoming voice call"
    recipient_ids = conversation.participants.exclude(id=call.initiator_id).values_list("id", flat=True)
    return send_push_to_users(
        recipient_ids,
        title=title,
        body=f"{call.initiator} is calling about {conversation.property.title if conversation.property_id else 'a rental chat'}",
        data={
            "kind": "call",
            "conversation_id": str(conversation.id),
            "call_id": str(call.id),
            "mode": call.mode,
            "property_id": str(conversation.property_id or ""),
            "initiator_id": str(call.initiator_id),
        },
        actor=call.initiator,
        event_type="push_call_sent",
    )


def send_push_to_users(user_ids, *, title, body, data=None, actor=None, event_type="push_sent"):
    if not settings.PUSH_NOTIFICATIONS_ENABLED:
        return {"sent": 0, "disabled": True}
    devices = list(PushDevice.objects.filter(user_id__in=list(user_ids), enabled=True))
    if not devices:
        return {"sent": 0, "devices": 0}
    messages = [expo_message(device.token, title=title, body=body, data=data or {}) for device in devices]
    response = send_expo_push_messages(messages)
    disable_invalid_tokens(devices, response)
    audit_event(
        event_type,
        actor=actor,
        category=SecurityAuditEvent.Category.CHAT,
        metadata=safe_metadata({"device_count": len(devices), "sent": len(messages), "response_status": response.get("status", "unknown")}),
    )
    return {"sent": len(messages), "devices": len(devices), "response": response}


def expo_message(token, *, title, body, data):
    return {
        "to": token,
        "sound": "default",
        "title": str(title or "Property24")[:80],
        "body": str(body or "")[:MAX_PUSH_BODY_LENGTH],
        "data": data,
        "priority": "high",
        "channelId": "messages",
    }


def send_expo_push_messages(messages):
    if not messages:
        return {"status": "empty", "data": []}
    body = json.dumps(messages).encode("utf-8")
    request = urlrequest.Request(
        settings.EXPO_PUSH_API_URL,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urlrequest.urlopen(request, timeout=settings.PUSH_NOTIFICATION_TIMEOUT_SECONDS) as response:
            payload = response.read().decode("utf-8", errors="ignore")
            return json.loads(payload or "{}") | {"status": "ok"}
    except (urlerror.URLError, TimeoutError, json.JSONDecodeError) as exc:
        audit_event(
            "push_delivery_failed",
            category=SecurityAuditEvent.Category.SYSTEM,
            severity=SecurityAuditEvent.Severity.MEDIUM,
            metadata={"error": str(exc)[:300]},
        )
        return {"status": "error", "error": str(exc)[:300]}


def disable_invalid_tokens(devices, response):
    data = response.get("data") if isinstance(response, dict) else None
    if not isinstance(data, list):
        return
    for device, item in zip(devices, data):
        details = item.get("details") if isinstance(item, dict) else None
        error = details.get("error") if isinstance(details, dict) else ""
        if error in EXPO_ERROR_TOKEN_INVALID:
            device.enabled = False
            device.save(update_fields=["enabled", "updated_at"])
