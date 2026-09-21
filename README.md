# Property24 Zimbabwe

Mobile-first Flutter rental platform for Zimbabwean property discovery, applications, rent collection, maintenance, messaging, and verification.

## Stack

- Flutter
- Dart
- Provider state management
- Shared preferences for local auth-token persistence
- HTTP client connected to the Django API
- Django 6 backend
- PostgreSQL for the full backend stack
- MinIO / S3-compatible object storage for images, videos, verification files, and lease documents
- JWT auth endpoints
- Local AI-assisted review for listing scam risk, tenant applications, lease drafting, and maintenance triage
- SQLite remains available for lightweight local development and tests

## What’s included

- Tenant, landlord, agent, and administrator journeys
- Advanced property browsing and detail screens
- Trust and verification-first rental workflows
- Inbox, analytics, and account management surfaces
- Django rentals API for listings, verification, payments, leases, maintenance, messaging, reports, and analytics

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
To customize secrets or service addresses, copy `backend/.env.example` to `backend/.env` and pass it to your deployment/runtime environment.

## Identity verification runtime

Verification performs upload validation, image quality checks, optional OCR, ID-number reuse detection, document-image reuse detection, and manual-review routing. Install the Python dependencies and the Tesseract binary for OCR extraction:

```bash
sudo apt-get install tesseract-ocr
cd backend
.venv/bin/pip install -r requirements.txt
```

Without Tesseract, submissions remain explicitly marked for manual review; they are never auto-approved from the user-entered ID number alone. Verification files use randomized storage paths and should be served only through authenticated, signed storage in production.

## Django API

The local Django backend and Docker expose JSON endpoints under `http://localhost:8010/api/`.

- `GET /api/properties/` with filters for `city`, `suburb`, `rent_min`, `rent_max`, `bedrooms_min`, `type`, and `verified_only`
- `POST /api/auth/login/`, `POST /api/auth/refresh/`, and `GET /api/auth/me/` for JWT authentication
- `POST /api/auth/google/` for Google ID-token sign-in when `GOOGLE_SIGN_IN_ENABLED=true` and `GOOGLE_CLIENT_IDS` is configured
- `POST /api/ai/listing-review/`, `POST /api/ai/application-score/`, and `POST /api/ai/maintenance-triage/` for AI-assisted review utilities
- `POST /api/properties/` for landlords or agents adding listings
- `POST /api/verifications/` and `POST /api/verifications/:id/review/` for tenant, landlord, and agent verification. Submissions require phone confirmation, national ID, selfie evidence, and role-specific landlord ownership or agent agency proof before administrator approval.
- `POST /api/applications/` for tenant rental applications
- `POST /api/payments/` for EcoCash, ZIPIT, bank transfer, and Visa/Mastercard payment records
- `POST /api/leases/` and `POST /api/leases/:id/sign/` for generated lease agreements and e-signing
- `POST /api/maintenance/` for tenant repair requests
- `POST /api/conversations/` and `/api/conversations/:id/messages/` for in-app messaging
- `GET /api/analytics/landlords/:user_id/` for listing views, saves, applications, occupancy, and rental income

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
- The Flutter data layer hydrates from the Django API and does not inject demo listings, payments, leases, or conversations.
- Payment provider callbacks for EcoCash, ZIPIT, bank transfer reconciliation, and cards are still modeled as recorded payment events; production provider integrations should be added behind those endpoints before launch.
