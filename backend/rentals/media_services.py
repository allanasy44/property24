from __future__ import annotations

from io import BytesIO
from pathlib import Path

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.utils import timezone
from PIL import Image, UnidentifiedImageError

from .models import MediaAsset

IMAGE_MIME_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
VIDEO_MIME_TYPES = {"video/mp4", "video/quicktime", "video/webm"}
DOCUMENT_MIME_TYPES = {"application/pdf", "image/jpeg", "image/jpg", "image/png", "image/webp"}
CHAT_MIME_TYPES = IMAGE_MIME_TYPES | VIDEO_MIME_TYPES | DOCUMENT_MIME_TYPES | {"audio/mpeg", "audio/mp4", "audio/aac", "audio/wav", "audio/webm"}
MAX_IMAGE_BYTES = 8 * 1024 * 1024
MAX_VIDEO_BYTES = 80 * 1024 * 1024
MAX_DOCUMENT_BYTES = 12 * 1024 * 1024
MAX_CHAT_ATTACHMENT_BYTES = 25 * 1024 * 1024
IMAGE_MAX_SIDE = 2048
THUMBNAIL_MAX_SIDE = 480
JPEG_QUALITY = 84


class MediaValidationError(ValueError):
    pass


def content_type(uploaded_file):
    return str(getattr(uploaded_file, "content_type", "") or "").lower().split(";", 1)[0].strip()


def media_type_for(uploaded_file, fallback="other"):
    mime = content_type(uploaded_file)
    if mime.startswith("image/"):
        return MediaAsset.MediaType.IMAGE
    if mime.startswith("video/"):
        return MediaAsset.MediaType.VIDEO
    if mime.startswith("audio/"):
        return MediaAsset.MediaType.AUDIO
    if mime == "application/pdf":
        return MediaAsset.MediaType.DOCUMENT
    return fallback


def validate_upload(uploaded_file, *, allowed_types, max_bytes, label="file"):
    if not uploaded_file:
        return None
    size = int(getattr(uploaded_file, "size", 0) or 0)
    mime = content_type(uploaded_file)
    if size <= 0:
        raise MediaValidationError(f"{label} is empty")
    if size > max_bytes:
        raise MediaValidationError(f"{label} must be {max_bytes // (1024 * 1024)}MB or smaller")
    if allowed_types and mime not in allowed_types:
        raise MediaValidationError(f"{label} type is not supported")
    return uploaded_file


def optimize_image_upload(uploaded_file, *, max_side=IMAGE_MAX_SIDE, quality=JPEG_QUALITY):
    if not uploaded_file or media_type_for(uploaded_file) != MediaAsset.MediaType.IMAGE:
        return uploaded_file
    try:
        uploaded_file.seek(0)
    except Exception:
        pass
    try:
        image = Image.open(uploaded_file)
        image.load()
    except UnidentifiedImageError as exc:
        raise MediaValidationError("Image could not be read") from exc

    image = image.convert("RGB")
    image.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    output = BytesIO()
    image.save(output, format="JPEG", optimize=True, quality=quality)
    output.seek(0)
    original = Path(getattr(uploaded_file, "name", "upload.jpg")).stem[:80] or "upload"
    return ContentFile(output.read(), name=f"{original}.jpg")


def register_media_asset(owner, file_field, *, scope, source_model="", source_id="", access=None, original_name="", mime_type="", metadata=None):
    if not file_field:
        return None
    file_name = getattr(file_field, "name", "")
    if not file_name:
        return None
    inferred_type = infer_media_type_from_name(file_name, mime_type)
    asset = MediaAsset.objects.create(
        owner=owner,
        file=file_name,
        media_type=inferred_type,
        scope=scope,
        access=access or default_access_for_scope(scope),
        original_name=(original_name or Path(file_name).name)[:180],
        mime_type=str(mime_type or "")[:120],
        size_bytes=file_size(file_field),
        source_model=source_model[:80],
        source_id=str(source_id or "")[:80],
        metadata=metadata or {},
    )
    process_media_asset(asset)
    return asset


def process_media_asset(asset):
    if asset.media_type != MediaAsset.MediaType.IMAGE:
        asset.processing_status = MediaAsset.ProcessingStatus.SKIPPED
        asset.save(update_fields=["processing_status", "updated_at"])
        return asset
    try:
        with default_storage.open(asset.file.name, "rb") as raw_file:
            image = Image.open(raw_file)
            image.load()
        asset.width, asset.height = image.size
        image = image.convert("RGB")
        image.thumbnail((THUMBNAIL_MAX_SIDE, THUMBNAIL_MAX_SIDE), Image.Resampling.LANCZOS)
        output = BytesIO()
        image.save(output, format="JPEG", optimize=True, quality=78)
        output.seek(0)
        thumb_name = f"media/thumbnails/{Path(asset.file.name).stem[:80]}-{asset.id}.jpg"
        saved_name = default_storage.save(thumb_name, ContentFile(output.read()))
        asset.thumbnail = saved_name
        asset.processing_status = MediaAsset.ProcessingStatus.READY
        asset.save(update_fields=["width", "height", "thumbnail", "processing_status", "updated_at"])
    except Exception:
        asset.processing_status = MediaAsset.ProcessingStatus.FAILED
        asset.save(update_fields=["processing_status", "updated_at"])
    return asset


def signed_media_url(file_field_or_name, *, expires=None):
    name = getattr(file_field_or_name, "name", file_field_or_name) or ""
    if not name:
        return ""
    expires = expires or settings.OBJECT_STORAGE_UPLOAD_EXPIRY_SECONDS
    storage = default_storage
    try:
        if hasattr(storage, "presigned_url") and settings.OBJECT_STORAGE_QUERYSTRING_AUTH:
            return storage.presigned_url(name, expires=expires)
        if hasattr(storage, "url"):
            return storage.url(name)
    except Exception:
        return ""
    return ""


def serialize_media_asset(asset, *, include_private_url=False):
    return {
        "id": str(asset.id),
        "scope": asset.scope,
        "media_type": asset.media_type,
        "access": asset.access,
        "status": asset.status,
        "processing_status": asset.processing_status,
        "original_name": asset.original_name,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "width": asset.width,
        "height": asset.height,
        "duration_seconds": asset.duration_seconds,
        "source_model": asset.source_model,
        "source_id": asset.source_id,
        "url": signed_media_url(asset.file) if include_private_url else "",
        "thumbnail_url": signed_media_url(asset.thumbnail) if asset.thumbnail and include_private_url else "",
        "created_at": asset.created_at.isoformat(),
        "updated_at": asset.updated_at.isoformat(),
    }


def soft_delete_media_asset(asset, *, delete_object=True):
    if asset.status == MediaAsset.Status.DELETED:
        return asset
    if delete_object:
        delete_file(asset.file)
        delete_file(asset.thumbnail)
    asset.status = MediaAsset.Status.DELETED
    asset.deleted_at = timezone.now()
    asset.save(update_fields=["status", "deleted_at", "updated_at"])
    return asset


def delete_file(file_field_or_name):
    name = getattr(file_field_or_name, "name", file_field_or_name) or ""
    if not name:
        return
    try:
        default_storage.delete(name)
    except Exception:
        pass


def file_size(file_field):
    try:
        return int(file_field.size or 0)
    except Exception:
        try:
            return int(default_storage.size(file_field.name) or 0)
        except Exception:
            return 0


def infer_media_type_from_name(name, mime_type=""):
    mime = str(mime_type or "").lower()
    if mime.startswith("image/"):
        return MediaAsset.MediaType.IMAGE
    if mime.startswith("video/"):
        return MediaAsset.MediaType.VIDEO
    if mime.startswith("audio/"):
        return MediaAsset.MediaType.AUDIO
    if mime == "application/pdf":
        return MediaAsset.MediaType.DOCUMENT
    suffix = Path(str(name)).suffix.lower()
    if suffix in {".jpg", ".jpeg", ".png", ".webp"}:
        return MediaAsset.MediaType.IMAGE
    if suffix in {".mp4", ".mov", ".webm"}:
        return MediaAsset.MediaType.VIDEO
    if suffix in {".pdf"}:
        return MediaAsset.MediaType.DOCUMENT
    return MediaAsset.MediaType.OTHER


def default_access_for_scope(scope):
    if scope == MediaAsset.Scope.PROPERTY:
        return MediaAsset.Access.PUBLIC
    return MediaAsset.Access.PRIVATE
