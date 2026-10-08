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
flutter run -d chrome --web-port 8093 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8010/api
```

For Google sign-in on web, create a Web OAuth client in Google Cloud Console
and add `http://localhost:8093` as an authorized JavaScript origin (also add
`http://127.0.0.1:8093` if you open the app using that host). The web app reads
the public client ID from `GOOGLE_CLIENT_IDS` through the backend's
`/api/auth/google/config/` endpoint when Google sign-in starts. Set
`GOOGLE_SIGN_IN_ENABLED=true` and include the Web OAuth client ID in
`GOOGLE_CLIENT_IDS` in `backend/.env`. Client IDs are public identifiers; never
put an OAuth client secret in the Flutter app.

If this checkout does not have Flutter platform runner folders yet, generate them once from the project root:

```bash
flutter create . --platforms=android,ios,web
```

For Android emulator builds, point Flutter at the host machine backend:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010/api
```

For iOS simulator, desktop, and web builds, `http://127.0.0.1:8010/api` is usually correct when the backend runs on the same machine.

## Voice and video calls

Calls use the authenticated live websocket for offer/answer/ICE signaling and WebRTC for media. The foreground app prompts for microphone access for voice calls and microphone plus camera access for video calls. Web builds must be served from HTTPS (or localhost) for browser media permissions.

This checkout does not include generated Android or iOS runner folders. For native builds, generate them with the command above and add `android.permission.RECORD_AUDIO` / `android.permission.CAMERA` to the Android manifest, plus `NSMicrophoneUsageDescription` / `NSCameraUsageDescription` to the iOS Info.plist. Native background incoming-call UI and push-token registration are not included in the Flutter client; the backend push endpoint currently needs registered device tokens and platform credentials for that flow.

STUN is enabled by default. For reliable calls across restrictive NATs and corporate/mobile networks, provide a TURN service and build with all of:

```bash
flutter run \
  --dart-define=WEBRTC_TURN_URLS=turn:turn.example.com:3478,turns:turn.example.com:5349 \
  --dart-define=WEBRTC_TURN_USERNAME=ephemeral-username \
  --dart-define=WEBRTC_TURN_CREDENTIAL=ephemeral-credential
```

Use short-lived TURN credentials from a trusted service for production; do not put permanent TURN secrets in client builds. Without TURN, some network combinations will not connect even when both clients and signaling are working.

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
- `GET /api/admin/dashboard/` and `/api/users/` for private support-admin insights and account management

### Private support administration

Support-admin accounts are not available through public signup. Provision one on the server with `python3 manage.py create_support_admin` from `backend/`; the command prompts for account details and a password without echoing it. After migration, open the app's private `/support/login` route to sign in. The admin workspace provides platform insights, user account management, listings, reports, and verification review. Removing a user deactivates their account and retains their records. Admin accounts cannot access private chat or call contents.

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
