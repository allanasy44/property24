# Property24 Zimbabwe

Mobile-first Flutter property platform for Zimbabwean property discovery, applications, messaging, and verification.

## Stack

- Flutter
- Dart
- Provider state management
- Shared preferences for local auth-token persistence
- HTTP client connected to the Django API
- Django 6 backend
- PostgreSQL for the full backend stack
- MinIO / S3-compatible object storage for images, videos, and verification files
- JWT auth endpoints
- Local AI-assisted review for listing scam risk and tenant applications
- SQLite remains available for lightweight local development and tests

## What’s included

- Tenant, landlord, agent, and administrator journeys
- Advanced property browsing and detail screens
- Trust and verification-first rental workflows
- Inbox, analytics, and account management surfaces
- Django rentals API for listings, verification, applications, messaging, reports, and analytics

## Run locally

Frontend:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8010/api
```

If this checkout does not have Flutter platform runner folders yet, generate them once from the project root:

```bash
flutter create . --platforms=android,ios,web
```

For Android emulator builds, point Flutter at the host machine backend:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010/api
```

For iOS simulator, desktop, and web builds, `http://127.0.0.1:8010/api` is usually correct when the backend runs on the same machine.

Backend:

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
python3 manage.py migrate
python3 manage.py runserver 0.0.0.0:8010
```

Local admin login:

- Email/username: `admin@property24.test`
- Password: `admin12345`

Full backend stack with PostgreSQL and MinIO:

```bash
docker compose up --build backend
```

The Docker API will be available at `http://localhost:8010/api/`, PostgreSQL on `localhost:5433`, MinIO on `localhost:9010`, and the MinIO console on `http://localhost:9011`.
Configure local secrets or service addresses directly in `backend/.env`; do not commit that file.

## Production deployment

Set `DJANGO_ENV=production` and provide unique values for `DJANGO_SECRET_KEYS` and `JWT_SECRET`. Production also requires explicit `DJANGO_ALLOWED_HOSTS`, `DJANGO_CORS_ALLOWED_ORIGINS`, `DJANGO_CSRF_TRUSTED_ORIGINS`, PostgreSQL, Redis, SMTP, and S3-compatible object storage settings. The backend refuses to start when these realtime, security, or storage requirements are missing.

Run migrations and static collection as a release step, then serve `property24_backend.asgi:application` with Daphne or another ASGI server. Expose `/api/health/live/` for liveness and `/api/health/ready/` for database, object-storage, and Redis readiness. Do not commit `backend/.env`; rotate any credentials that have previously appeared in repository history.

## Identity verification runtime

Identity verification requires a contact phone number, the entered Zimbabwe national ID number, and front/back ID images. The phone number is not OTP-verified by this flow. The backend checks image quality, OCR number/name consistency, reused ID numbers, and duplicate images. The Docker image includes Tesseract; local Python installs need the binary:

```bash
sudo apt-get install tesseract-ocr
cd backend
.venv/bin/pip install -r requirements.txt
```

In non-production environments, a readable image pair can be marked verified only when OCR matches the submitted ID number and account name and all image checks pass. Mismatches are rejected; unreadable or uncertain documents require manual review. OCR checks text consistency only and does not authenticate an ID against a Zimbabwean government registry. Production defaults to manual review (`IDENTITY_LOCAL_AUTO_VERIFY=false`); use an authoritative identity provider before enabling automatic production approval. The separate phone OTP endpoint remains available for other flows and requires a configured SMS provider. Verification files use randomized storage paths and should be served only through authenticated, signed storage in production.

## Django API

The local Django backend and Docker expose JSON endpoints under `http://localhost:8010/api/`.

- `GET /api/properties/` with filters for `city`, `suburb`, `rent_min`, `rent_max`, `bedrooms_min`, `type`, and `verified_only`
- `POST /api/auth/login/`, `POST /api/auth/refresh/`, and `GET /api/auth/me/` for JWT authentication
- `POST /api/auth/google/` for Google ID-token sign-in when `GOOGLE_SIGN_IN_ENABLED=true` and `GOOGLE_CLIENT_IDS` is configured
- `POST /api/ai/listing-review/` and `POST /api/ai/application-score/` for AI-assisted review utilities
- `POST /api/properties/` for landlords or agents adding listings
- `POST /api/verifications/` and `POST /api/verifications/:id/review/` for phone and national ID verification using ID front/back images; uncertain OCR matches can be reviewed by an administrator.
- `POST /api/applications/` for tenant rental applications
- `POST /api/conversations/` and `/api/conversations/:id/messages/` for in-app messaging
- `GET /api/analytics/landlords/:user_id/` for listing views, saves, and applications

## Backend checks

```bash
cd backend
python3 manage.py test
python3 manage.py makemigrations --check --dry-run
```

## Notes

- When `OBJECT_STORAGE_PROVIDER=minio`, Django file fields use the MinIO bucket configured in `backend/.env`.
- The backend still exposes `POST /api/auth/google/` for Google ID-token sign-in when `GOOGLE_SIGN_IN_ENABLED=true`; the Flutter frontend currently ships password registration/sign-in and can add a Google identity-provider package against that endpoint later.
- `GET /api/health/` reports database, object storage, AI provider, and map provider status.
- The Flutter data layer hydrates from the Django API and does not inject demo listings or conversations.
