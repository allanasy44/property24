from __future__ import annotations

from collections.abc import Iterable
from ipaddress import ip_address

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.contrib.auth import get_user_model
from django.utils import timezone

from .models import CallSession, Conversation, Message, SecurityAuditEvent

MAX_CHAT_BODY_LENGTH = 2000
MAX_TYPING_LENGTH = 120
CHAT_GROUP_PREFIX = "conversation"
USER_GROUP_PREFIX = "user"

User = get_user_model()


def conversation_group_name(conversation_id):
    return f"{CHAT_GROUP_PREFIX}.{conversation_id}"


def user_group_name(user_id):
    return f"{USER_GROUP_PREFIX}.{user_id}"


def is_conversation_participant(user, conversation):
    return bool(user and user.is_authenticated and (is_admin(user) or conversation.participants.filter(id=user.id).exists()))


def is_admin(user):
    return getattr(user, "role", "") == User.Roles.ADMIN


def user_conversation_ids(user):
    if not user or not user.is_authenticated:
        return []
    conversations = Conversation.objects.all() if is_admin(user) else Conversation.objects.filter(participants=user)
    return list(conversations.values_list("id", flat=True))


def get_authorized_conversation(user, conversation_id):
    try:
        conversation = Conversation.objects.get(pk=conversation_id)
    except (Conversation.DoesNotExist, ValueError, TypeError):
        return None
    return conversation if is_conversation_participant(user, conversation) else None


def validate_message_body(body):
    value = str(body or "").strip()
    if not value:
        raise ValueError("Message body is required")
    if len(value) > MAX_CHAT_BODY_LENGTH:
        raise ValueError(f"Message body must be {MAX_CHAT_BODY_LENGTH} characters or fewer")
    return value


def create_text_message(conversation, sender, body):
    clean_body = validate_message_body(body)
    message = Message.objects.create(conversation=conversation, sender=sender, body=clean_body)
    conversation.save(update_fields=["updated_at"])
    return message


def mark_conversation_read(conversation, reader):
    if is_admin(reader):
        return []
    now = timezone.now()
    queryset = conversation.messages.filter(read_at__isnull=True).exclude(sender=reader)
    message_ids = list(queryset.values_list("id", flat=True))
    if message_ids:
        queryset.update(read_at=now)
    return message_ids


def create_call(conversation, initiator, mode):
    if mode not in {CallSession.Mode.VOICE, CallSession.Mode.VIDEO}:
        raise ValueError("mode must be voice or video")
    call = CallSession.objects.create(conversation=conversation, initiator=initiator, mode=mode)
    conversation.save(update_fields=["updated_at"])
    return call


def end_call(conversation, call_id, status=CallSession.Status.ENDED):
    if status not in {CallSession.Status.ENDED, CallSession.Status.MISSED}:
        raise ValueError("status must be ended or missed")
    call = CallSession.objects.get(pk=call_id, conversation=conversation)
    call.status = status
    if call.ended_at is None:
        call.ended_at = timezone.now()
    call.save(update_fields=["status", "ended_at"])
    conversation.save(update_fields=["updated_at"])
    return call


def touch_user_presence(user):
    user.last_seen_at = timezone.now()
    user.save(update_fields=["last_seen_at"])
    return user.last_seen_at


def broadcast_to_conversation(conversation_id, event_type, payload):
    channel_layer = get_channel_layer()
    if not channel_layer:
        return
    async_to_sync(channel_layer.group_send)(
        conversation_group_name(conversation_id),
        {"type": "chat.event", "event": event_type, "payload": payload},
    )


def broadcast_to_user(user_id, event_type, payload):
    channel_layer = get_channel_layer()
    if not channel_layer:
        return
    async_to_sync(channel_layer.group_send)(
        user_group_name(user_id),
        {"type": "chat.event", "event": event_type, "payload": payload},
    )


def broadcast_presence(user, online, conversation_ids: Iterable[int] | None = None):
    payload = {
        "user_id": str(user.id),
        "name": str(user),
        "role": user.role,
        "online": bool(online),
        "last_seen_at": user.last_seen_at.isoformat() if user.last_seen_at else None,
    }
    for conversation_id in conversation_ids or user_conversation_ids(user):
        broadcast_to_conversation(conversation_id, "presence.changed", payload)


def audit_event(event_type, *, actor=None, category=SecurityAuditEvent.Category.CHAT, severity=SecurityAuditEvent.Severity.INFO, ip_address=None, user_agent="", metadata=None):
    return SecurityAuditEvent.objects.create(
        actor=actor if getattr(actor, "is_authenticated", False) else None,
        category=category,
        event_type=event_type[:80],
        severity=severity,
        ip_address=clean_ip(ip_address),
        user_agent=str(user_agent or "")[:255],
        metadata=safe_metadata(metadata or {}),
    )


def safe_metadata(value):
    safe = {}
    for key, item in dict(value).items():
        key = str(key)[:80]
        if key.lower() in {"token", "authorization", "password", "secret", "api_key"}:
            safe[key] = "[redacted]"
        elif isinstance(item, (str, int, float, bool)) or item is None:
            safe[key] = item if not isinstance(item, str) else item[:500]
        else:
            safe[key] = str(item)[:500]
    return safe


def clean_ip(value):
    if not value:
        return None
    try:
        return str(ip_address(str(value).split(",", 1)[0].strip()))
    except ValueError:
        return None
