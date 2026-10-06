from pathlib import Path

from .env import env_bool, env_int, env_list, env_str
from django.core.exceptions import ImproperlyConfigured


BASE_DIR = Path(__file__).resolve().parent.parent

DJANGO_ENV = env_str("DJANGO_ENV", "development").lower()
IS_PRODUCTION = DJANGO_ENV == "production"
SECRET_KEY = env_list("DJANGO_SECRET_KEYS", ["unsafe-local-development-key"])[0]
if IS_PRODUCTION and SECRET_KEY == "unsafe-local-development-key":
    raise ImproperlyConfigured("DJANGO_SECRET_KEYS must be configured in production")
DEBUG = env_bool("DJANGO_DEBUG", not IS_PRODUCTION)
if IS_PRODUCTION and DEBUG:
    raise ImproperlyConfigured("DJANGO_DEBUG must be false in production")
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", ["127.0.0.1", "localhost"])
if DEBUG and "*" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("*")
if IS_PRODUCTION and "*" in ALLOWED_HOSTS:
    raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS cannot contain * in production")
if IS_PRODUCTION and not env_str("DJANGO_ALLOWED_HOSTS", ""):
    raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS must be configured in production")
CORS_ALLOWED_ORIGINS = env_list(
    "DJANGO_CORS_ALLOWED_ORIGINS",
    [
        "http://localhost:8081",
        "http://127.0.0.1:8081",
        "http://localhost:8082",
        "http://127.0.0.1:8082",
        "http://localhost:8091",
        "http://127.0.0.1:8091",
        "http://localhost:8092",
        "http://127.0.0.1:8092",
        "http://192.168.100.34:8093",
        "http://127.0.0.1:8093",
        "http://localhost:8093",
        "http://localhost:19006",
        "http://127.0.0.1:19006",
    ] if DEBUG else [],
)
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS", [])

INSTALLED_APPS = [
    "daphne",
    "channels",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rentals",
]

MIDDLEWARE = [
    "rentals.middleware.SimpleCorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "property24_backend.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "property24_backend.wsgi.application"
ASGI_APPLICATION = "property24_backend.asgi.application"

REDIS_URL = env_str("REDIS_URL", "")
if REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": REDIS_URL,
                    "socket_connect_timeout": 5,
                    "socket_timeout": None,
                    "retry_on_timeout": True,
                }],
            },
        }
    }
elif IS_PRODUCTION:
    raise ImproperlyConfigured("REDIS_URL is required in production for realtime events")
else:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }
DATABASE_ENGINE = env_str("DATABASE_ENGINE", "sqlite").lower()
if DATABASE_ENGINE == "postgresql":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": env_str("POSTGRES_DB", "property24"),
            "USER": env_str("POSTGRES_USER", "property24"),
            "PASSWORD": env_str("POSTGRES_PASSWORD", ""),
            "HOST": env_str("POSTGRES_HOST", "127.0.0.1"),
            "PORT": env_str("POSTGRES_PORT", "5432"),
            "CONN_MAX_AGE": env_int("POSTGRES_CONN_MAX_AGE", 60),
            "CONN_HEALTH_CHECKS": True,
            "ATOMIC_REQUESTS": True,
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": Path(env_list("SQLITE_DATABASE_PATH", [str(BASE_DIR / "db.sqlite3")])[0]),
            "CONN_HEALTH_CHECKS": True,
        }
    }

AUTH_USER_MODEL = "rentals.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 15}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.BCryptSHA256PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Africa/Harare"
USE_I18N = True
USE_L10N = True
USE_TZ = True

STATIC_URL = "/static/"
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

JWT_SECRET = env_str("JWT_SECRET", SECRET_KEY)
JWT_ACCESS_TOKEN_SECONDS = env_int("JWT_ACCESS_TOKEN_SECONDS", 3600)
JWT_REFRESH_TOKEN_SECONDS = env_int("JWT_REFRESH_TOKEN_SECONDS", 60 * 60 * 24 * 30)

REGISTRATION_OTP_TTL_MINUTES = env_int("REGISTRATION_OTP_TTL_MINUTES", 10)
OTP_DELIVERY_CHANNEL = env_str("OTP_DELIVERY_CHANNEL", "email").lower()
OTP_SMS_PROVIDER = env_str("OTP_SMS_PROVIDER", "twilio").lower()
OTP_SMS_WEBHOOK_URL = env_str("OTP_SMS_WEBHOOK_URL", "")
OTP_SMS_API_KEY = env_str("OTP_SMS_API_KEY", "")
OTP_SMS_SENDER = env_str("OTP_SMS_SENDER", "Property24")
TWILIO_ACCOUNT_SID = env_str("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = env_str("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM_NUMBER = env_str("TWILIO_FROM_NUMBER", "")
TWILIO_MESSAGING_SERVICE_SID = env_str("TWILIO_MESSAGING_SERVICE_SID", "")

EMAIL_BACKEND = env_str("EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend" if DEBUG else "django.core.mail.backends.smtp.EmailBackend")
EMAIL_HOST = env_str("EMAIL_HOST", "smtp.gmail.com")
EMAIL_PORT = env_int("EMAIL_PORT", 587)
EMAIL_HOST_USER = env_str("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = env_str("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = env_bool("EMAIL_USE_TLS", True)
DEFAULT_FROM_EMAIL = env_str("DEFAULT_FROM_EMAIL", EMAIL_HOST_USER or "Property24 <no-reply@property24.local>")

PUSH_NOTIFICATIONS_ENABLED = env_bool("PUSH_NOTIFICATIONS_ENABLED", True)
EXPO_PUSH_API_URL = env_str("EXPO_PUSH_API_URL", "https://exp.host/--/api/v2/push/send")
PUSH_NOTIFICATION_TIMEOUT_SECONDS = env_int("PUSH_NOTIFICATION_TIMEOUT_SECONDS", 8)

OBJECT_STORAGE_PROVIDER = env_str("OBJECT_STORAGE_PROVIDER", "local").lower()
OBJECT_STORAGE_ENDPOINT_URL = env_str("OBJECT_STORAGE_ENDPOINT_URL", "")
OBJECT_STORAGE_REGION = env_str("OBJECT_STORAGE_REGION", "us-east-1")
OBJECT_STORAGE_BUCKET = env_str("OBJECT_STORAGE_BUCKET", "")
OBJECT_STORAGE_ACCESS_KEY_ID = env_str("OBJECT_STORAGE_ACCESS_KEY_ID", "")
OBJECT_STORAGE_SECRET_ACCESS_KEY = env_str("OBJECT_STORAGE_SECRET_ACCESS_KEY", "")
OBJECT_STORAGE_PUBLIC_BASE_URL = env_str("OBJECT_STORAGE_PUBLIC_BASE_URL", "")
OBJECT_STORAGE_FORCE_PATH_STYLE = env_bool("OBJECT_STORAGE_FORCE_PATH_STYLE", True)
OBJECT_STORAGE_QUERYSTRING_AUTH = env_bool("OBJECT_STORAGE_QUERYSTRING_AUTH", False)
OBJECT_STORAGE_UPLOAD_EXPIRY_SECONDS = env_int("OBJECT_STORAGE_UPLOAD_EXPIRY_SECONDS", 900)

if OBJECT_STORAGE_PROVIDER in {"minio", "s3", "r2"}:
    STORAGES = {
        "default": {
            "BACKEND": "rentals.storage_backends.MinioStorage",
            "OPTIONS": {
                "access_key": OBJECT_STORAGE_ACCESS_KEY_ID,
                "secret_key": OBJECT_STORAGE_SECRET_ACCESS_KEY,
                "bucket_name": OBJECT_STORAGE_BUCKET,
                "endpoint_url": OBJECT_STORAGE_ENDPOINT_URL or None,
                "region_name": OBJECT_STORAGE_REGION,
                "addressing_style": "path" if OBJECT_STORAGE_FORCE_PATH_STYLE else "virtual",
                "signature_version": "s3v4",
                "file_overwrite": False,
                "querystring_auth": OBJECT_STORAGE_QUERYSTRING_AUTH,
                "default_acl": None,
            },
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }

MAP_PROVIDER = env_str("MAP_PROVIDER", "openstreetmap").lower()
GOOGLE_MAPS_API_KEY = env_str("GOOGLE_MAPS_API_KEY", "")
GOOGLE_SIGN_IN_ENABLED = env_bool("GOOGLE_SIGN_IN_ENABLED", False)
GOOGLE_CLIENT_IDS = env_list("GOOGLE_CLIENT_IDS", [])

AI_PROVIDER = env_str("AI_PROVIDER", "local").lower()
AI_MODEL = env_str("AI_MODEL", "property24-rules-v1")
AI_ASSISTED_REVIEW_ENABLED = env_bool("AI_ASSISTED_REVIEW_ENABLED", True)
OPENAI_API_KEY = env_str("OPENAI_API_KEY", "")
GEMINI_API_KEY = env_str("GEMINI_API_KEY", "")
GEMINI_MODEL = env_str("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT_SECONDS = env_int("GEMINI_TIMEOUT_SECONDS", 20)
PROPERTY_SEARCH_MATCH_WEIGHTS = {
    "budget": 30,
    "location": 25,
    "property": 20,
    "amenities": 20,
    "availability": 5,
}
IDENTITY_LOCAL_AUTO_VERIFY = env_bool("IDENTITY_LOCAL_AUTO_VERIFY", not IS_PRODUCTION)

STATIC_ROOT = BASE_DIR / "staticfiles"
DATA_UPLOAD_MAX_MEMORY_SIZE = env_int("DATA_UPLOAD_MAX_MEMORY_SIZE", 30 * 1024 * 1024)
FILE_UPLOAD_MAX_MEMORY_SIZE = env_int("FILE_UPLOAD_MAX_MEMORY_SIZE", 30 * 1024 * 1024)

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env_bool("SECURE_SSL_REDIRECT", IS_PRODUCTION)
SESSION_COOKIE_SECURE = env_bool("SESSION_COOKIE_SECURE", IS_PRODUCTION)
CSRF_COOKIE_SECURE = env_bool("CSRF_COOKIE_SECURE", IS_PRODUCTION)
SECURE_HSTS_SECONDS = env_int("SECURE_HSTS_SECONDS", 31536000 if IS_PRODUCTION else 0)
SECURE_HSTS_INCLUDE_SUBDOMAINS = IS_PRODUCTION
SECURE_HSTS_PRELOAD = IS_PRODUCTION
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"

if IS_PRODUCTION:
    if IDENTITY_LOCAL_AUTO_VERIFY:
        raise ImproperlyConfigured("Local OCR auto-verification is not permitted in production")
    if not env_str("JWT_SECRET", "") or JWT_SECRET == SECRET_KEY:
        raise ImproperlyConfigured("JWT_SECRET must be configured separately in production")
    if OBJECT_STORAGE_PROVIDER == "local":
        raise ImproperlyConfigured("OBJECT_STORAGE_PROVIDER must be minio, s3, or r2 in production")
    if EMAIL_BACKEND.endswith("console.EmailBackend"):
        raise ImproperlyConfigured("A real EMAIL_BACKEND is required in production")
    if not CORS_ALLOWED_ORIGINS:
        raise ImproperlyConfigured("DJANGO_CORS_ALLOWED_ORIGINS must be configured in production")
