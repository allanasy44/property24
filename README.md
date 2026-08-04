# Property24 Zimbabwe

Mobile-first React Native rental platform for Zimbabwean property discovery, applications, rent collection, maintenance, messaging, and verification.

## Stack

- Expo 57
- Expo Router
- TypeScript
- React Native
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
npm install
npm run start
```

To hydrate the mobile app from Django instead of the local seed store:

```bash
EXPO_PUBLIC_API_URL=http://127.0.0.1:8000/api npm run web
```

For Google sign-in, set `EXPO_PUBLIC_GOOGLE_CLIENT_ID` for web and `EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID` / `EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID` for native builds.

Backend:

```bash
cd backend
python3 -m venv venv
venv/bin/pip install -r requirements.txt
python3 manage.py migrate
python3 manage.py seed_initial_data
python3 manage.py runserver 0.0.0.0:8000
```

Local admin login:

- Email/username: `admin@property24.test`
- Password: `admin12345`

Or from the project root:

```bash
npm run backend:migrate
npm run backend:seed
npm run backend
```

Full backend stack with PostgreSQL and MinIO:

```bash
docker compose up --build backend
```

The Docker API will be available at `http://localhost:8010/api/`, PostgreSQL on `localhost:5433`, MinIO on `localhost:9010`, and the MinIO console on `http://localhost:9011`.
To customize secrets or service addresses, copy `backend/.env.example` to `backend/.env` and pass it to your deployment/runtime environment.

## Django API

The backend exposes JSON endpoints under `http://localhost:8000/api/`.

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
- Google sign-in must send a verified Google ID token to the backend. Use `EXPO_PUBLIC_GOOGLE_CLIENT_ID` on the frontend, and put the same client ID in backend `GOOGLE_CLIENT_IDS`.
- `GET /api/health/` reports database, object storage, AI provider, and map provider status.
- The mobile data layer includes local seed state for offline use; the Django API provides the production backend shape.
- Payment provider callbacks for EcoCash, ZIPIT, bank transfer reconciliation, and cards are still modeled as recorded payment events; production provider integrations should be added behind those endpoints before launch.
