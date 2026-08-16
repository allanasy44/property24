from __future__ import annotations

from collections.abc import Iterable
from ipaddress import ip_address

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from .models import CallSession, ChatBlock, ChatReport, Conversation, Message, MessageReceipt, PushDevice, SecurityAuditEvent

MAX_CHAT_BODY_LENGTH = 2000
MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024
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


def user_conversations(user):
    queryset = Conversation.objects.prefetch_related("participants", "messages").order_by("-updated_at")
    if not user or not user.is_authenticated:
        return queryset.none()
    if is_admin(user):
        return queryset
    return queryset.filter(participants=user)


def list_conversations_for_user(user):
    return user_conversations(user)


def user_conversation_ids(user):
    return list(user_conversations(user).values_list("id", flat=True))


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


def open_listing_conversation(actor, prop, participant_ids, title=""):
    participants = set(int(value) for value in participant_ids)
    existing = Conversation.objects.filter(property=prop, participants=actor).filter(participants__id__in=participants).distinct().first()
    if existing:
        return existing, False

    contact_names = list(User.objects.filter(id__in=participants).values_list("full_name", "username"))
    readable_contacts = ", ".join(full_name or username for full_name, username in contact_names)
    conversation = Conversation.objects.create(
        property=prop,
        title=title or f"{prop.title} · {readable_contacts}",
        phone_numbers_revealed=False,
    )
    conversation.participants.set(User.objects.filter(id__in={actor.id, *participants}))
    return conversation, True


def default_attachment_body(attachment_type, attachment_name):
    label = attachment_type or "attachment"
    name = f" {attachment_name}" if attachment_name else ""
    return f"Shared {label}{name}".strip()


def conversation_blocked_for_user(conversation, sender):
    if is_admin(sender):
        return False
    participant_ids = list(conversation.participants.values_list("id", flat=True))
    other_ids = [item for item in participant_ids if item != sender.id]
    if not other_ids:
        return False
    return ChatBlock.objects.filter(
        Q(blocker_id=sender.id, blocked_id__in=other_ids) | Q(blocker_id__in=other_ids, blocked_id=sender.id)
    ).exists()


def create_message_receipts(message):
    now = timezone.now()
    receipts = []
    for participant_id in message.conversation.participants.values_list("id", flat=True):
        is_sender = participant_id == message.sender_id
        receipts.append(MessageReceipt(
            message=message,
            user_id=participant_id,
            delivered_at=now if is_sender else None,
            read_at=now if is_sender else None,
        ))
    MessageReceipt.objects.bulk_create(receipts, ignore_conflicts=True)


def ensure_message_receipts(conversation):
    for message in conversation.messages.select_related("conversation", "sender").prefetch_related("conversation__participants"):
        existing_user_ids = set(message.receipts.values_list("user_id", flat=True))
        missing_user_ids = [item for item in message.conversation.participants.values_list("id", flat=True) if item not in existing_user_ids]
        if not missing_user_ids:
            continue
        now = timezone.now()
        MessageReceipt.objects.bulk_create([
            MessageReceipt(
                message=message,
                user_id=user_id,
                delivered_at=now if user_id == message.sender_id else None,
                read_at=message.read_at if user_id != message.sender_id else now,
            )
            for user_id in missing_user_ids
        ], ignore_conflicts=True)


def create_chat_message(conversation, sender, body="", *, attachment=None, attachment_url="", attachment_type="", attachment_name="", client_message_id=""):
    if conversation_blocked_for_user(conversation, sender):
        raise ValueError("Messaging is blocked for this conversation")

    clean_body = str(body or "").strip()
    clean_client_message_id = str(client_message_id or "").strip()[:80]
    clean_attachment_url = str(attachment_url or "").strip()[:500]
    clean_attachment_type = str(attachment_type or "").strip()[:32]
    clean_attachment_name = str(attachment_name or "").strip()[:180]

    if clean_client_message_id:
        existing = Message.objects.filter(conversation=conversation, sender=sender, client_message_id=clean_client_message_id).first()
        if existing:
            return existing
    if not clean_body and not attachment and not clean_attachment_url:
        raise ValueError("Message body or attachment is required")
    if clean_body and len(clean_body) > MAX_CHAT_BODY_LENGTH:
        raise ValueError(f"Message body must be {MAX_CHAT_BODY_LENGTH} characters or fewer")
    if attachment and getattr(attachment, "size", 0) > MAX_ATTACHMENT_BYTES:
        raise ValueError("Attachment must be 25MB or smaller")

    with transaction.atomic():
        message = Message.objects.create(
            conversation=conversation,
            sender=sender,
            body=clean_body or default_attachment_body(clean_attachment_type, clean_attachment_name),
            client_message_id=clean_client_message_id,
            attachment=attachment,
            attachment_url=clean_attachment_url,
            attachment_type=clean_attachment_type,
            attachment_name=clean_attachment_name or getattr(attachment, "name", "")[:180],
        )
        create_message_receipts(message)
        conversation.save(update_fields=["updated_at"])
    return message


def create_text_message(conversation, sender, body, client_message_id=""):
    clean_body = validate_message_body(body)
    return create_chat_message(conversation, sender, clean_body, client_message_id=client_message_id)


def mark_conversation_delivered(conversation, recipient):
    if is_admin(recipient):
        return []
    ensure_message_receipts(conversation)
    now = timezone.now()
    queryset = MessageReceipt.objects.filter(
        message__conversation=conversation,
        user=recipient,
        delivered_at__isnull=True,
    ).exclude(message__sender=recipient)
    message_ids = list(queryset.values_list("message_id", flat=True))
    if message_ids:
        queryset.update(delivered_at=now)
    return message_ids


def mark_conversation_read(conversation, reader):
    if is_admin(reader):
        return []
    ensure_message_receipts(conversation)
    now = timezone.now()
    queryset = MessageReceipt.objects.filter(
        message__conversation=conversation,
        user=reader,
        read_at__isnull=True,
    ).exclude(message__sender=reader)
    message_ids = list(queryset.values_list("message_id", flat=True))
    if message_ids:
        queryset.filter(delivered_at__isnull=True).update(delivered_at=now)
        queryset.update(read_at=now)
        conversation.messages.filter(id__in=message_ids, read_at__isnull=True).update(read_at=now)
    return message_ids


def edit_chat_message(conversation, message_id, editor, body):
    message = Message.objects.get(pk=message_id, conversation=conversation)
    if not (is_admin(editor) or message.sender_id == editor.id):
        raise PermissionError("Only the sender can edit this message")
    if message.deleted_at:
        raise ValueError("Deleted messages cannot be edited")
    message.body = validate_message_body(body)
    message.edited_at = timezone.now()
    message.save(update_fields=["body", "edited_at"])
    conversation.save(update_fields=["updated_at"])
    return message


def delete_chat_message(conversation, message_id, actor):
    message = Message.objects.get(pk=message_id, conversation=conversation)
    if not (is_admin(actor) or message.sender_id == actor.id):
        raise PermissionError("Only the sender can delete this message")
    if message.deleted_at is None:
        message.deleted_at = timezone.now()
        message.save(update_fields=["deleted_at"])
        conversation.save(update_fields=["updated_at"])
    return message


def block_chat_user(conversation, blocker, blocked_id):
    if is_admin(blocker):
        raise ValueError("Administrators cannot block from a rental chat")
    try:
        blocked_id = int(blocked_id)
    except (TypeError, ValueError):
        raise ValueError("blocked_user_id is required")
    if blocked_id == blocker.id:
        raise ValueError("You cannot block yourself")
    if not conversation.participants.filter(id=blocked_id).exists():
        raise ValueError("That user is not in this conversation")
    block, _ = ChatBlock.objects.get_or_create(blocker=blocker, blocked_id=blocked_id)
    return block


def report_chat_message(conversation, reporter, *, message_id=None, reason="", details=""):
    clean_reason = str(reason or "").strip()[:80]
    clean_details = str(details or "").strip()[:1000]
    if not clean_reason:
        raise ValueError("Report reason is required")
    message = None
    if message_id:
        message = Message.objects.get(pk=message_id, conversation=conversation)
    return ChatReport.objects.create(
        reporter=reporter,
        conversation=conversation,
        message=message,
        reason=clean_reason,
        details=clean_details,
    )


def register_push_device(user, token, platform):
    clean_token = str(token or "").strip()[:255]
    clean_platform = str(platform or "").strip().lower()[:24]
    if not clean_token:
        raise ValueError("Push token is required")
    if clean_platform not in {"ios", "android", "web", "expo"}:
        raise ValueError("Platform must be ios, android, web, or expo")
    device, _ = PushDevice.objects.update_or_create(
        token=clean_token,
        defaults={"user": user, "platform": clean_platform, "enabled": True},
    )
    return device


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
