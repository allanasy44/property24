from django.conf import settings
from django.core.files.storage import default_storage


def object_storage_status():
    provider = settings.OBJECT_STORAGE_PROVIDER
    if provider == "local":
        return {
            "provider": provider,
            "status": "ok",
            "bucket": None,
            "detail": "Using Django local media storage.",
        }

    if provider not in {"minio", "s3", "r2"}:
        return {
            "provider": provider,
            "status": "disabled",
            "bucket": settings.OBJECT_STORAGE_BUCKET,
            "detail": "Unknown object storage provider.",
        }

    if not settings.OBJECT_STORAGE_BUCKET:
        return {
            "provider": provider,
            "status": "error",
            "bucket": "",
            "detail": "OBJECT_STORAGE_BUCKET is required.",
        }

    try:
        storage = default_storage
        exists = storage.exists("__property24_healthcheck__")
        return {
            "provider": provider,
            "status": "ok",
            "bucket": settings.OBJECT_STORAGE_BUCKET,
            "detail": "Object storage is reachable.",
            "healthcheck_object_exists": exists,
        }
    except Exception as exc:
        return {
            "provider": provider,
            "status": "error",
            "bucket": settings.OBJECT_STORAGE_BUCKET,
            "detail": str(exc),
        }
