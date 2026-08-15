import json
from io import BytesIO
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core import mail
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from django.test import override_settings
from asgiref.sync import async_to_sync
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from django.test import Client, TestCase, TransactionTestCase
from PIL import Image

from .auth import issue_token_pair
from .views import hash_otp, normalize_phone, phone_lookup_values
from property24_backend.asgi import application

from .models import AIAnalysis, Application, CallSession, Conversation, DisputeReport, EmailVerificationOTP, LeaseAgreement, MaintenanceRequest, Message, Payment, PendingRegistrationOTP, PhoneVerificationOTP, Property, PropertyComment, PropertyPhoto, SecurityAuditEvent, VerificationRequest, Viewing


class RentalApiTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.client = Client()
        self.landlord = User.objects.create_user(username="landlord", password="secret12345", full_name="John Doe", phone="0771111111", role=User.Roles.LANDLORD, is_verified=True)
        self.tenant = User.objects.create_user(username="tenant", password="secret12345", full_name="Jane Smith", role=User.Roles.TENANT, is_verified=True)
        self.agent = User.objects.create_user(username="agent", password="secret12345", full_name="Tariro Moyo", role=User.Roles.AGENT, is_verified=True)
        self.admin = User.objects.create_user(username="admin", password="secret12345", full_name="Admin", role=User.Roles.ADMIN, is_verified=True)
        self.property = Property.objects.create(
            owner=self.landlord,
            agent=self.agent,
            title="Borrowdale family house",
            address="123 Borrowdale Road",
            city="Harare",
            suburb="Borrowdale",
            monthly_rent="450.00",
            deposit_required="450.00",
            property_type=Property.PropertyType.HOUSE,
            bedrooms=3,
            bathrooms="2.0",
            listing_status=Property.ListingStatus.VERIFIED,
        )

    def auth_header(self, user):
        return {"HTTP_AUTHORIZATION": f"Bearer {issue_token_pair(user)['access']}"}

    def post_json(self, path, payload, user=None):
        return self.client.post(path, data=json.dumps(payload), content_type="application/json", **(self.auth_header(user) if user else {}))

    def patch_json(self, path, payload, user=None):
        return self.client.patch(path, data=json.dumps(payload), content_type="application/json", **(self.auth_header(user) if user else {}))

    def mark_phone_otp_verified(self, user, phone):
        user.phone = phone
        user.phone_verified = True
        user.save(update_fields=["phone", "phone_verified"])
        return PhoneVerificationOTP.objects.create(
            user=user,
            phone=phone,
            code_hash="verified-in-test",
            sent_to=phone,
            status=PhoneVerificationOTP.Status.VERIFIED,
            verified_at=timezone.now(),
            expires_at=timezone.now() + timedelta(minutes=10),
        )

    def mark_email_otp_verified(self, user):
        return EmailVerificationOTP.objects.create(
            user=user,
            email=user.email.lower(),
            code_hash="verified-in-test",
            sent_to=user.email.lower(),
            status=EmailVerificationOTP.Status.VERIFIED,
            verified_at=timezone.now(),
            expires_at=timezone.now() + timedelta(minutes=10),
        )

    def identity_image_upload(self, name="identity.jpg"):
        image = Image.new("RGB", (720, 480), "white")
        output = BytesIO()
        image.save(output, format="JPEG")
        output.seek(0)
        return SimpleUploadedFile(name, output.read(), content_type="image/jpeg")

    def test_property_search_filters_by_city_rent_bedrooms_and_verified(self):
        response = self.client.get("/api/properties/?city=Harare&rent_max=500&bedrooms_min=2&verified_only=true")

        self.assertEqual(response.status_code, 200)
        data = response.json()["results"]
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["title"], "Borrowdale family house")

    def test_health_reports_database_storage_and_ai_stack(self):
        response = self.client.get("/api/health/")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["database"]["status"], "ok")
        self.assertEqual(payload["object_storage"]["provider"], "local")
        self.assertEqual(payload["ai"]["provider"], "local")

    def test_jwt_login_refresh_and_me(self):
        login = self.post_json("/api/auth/login/", {"username": "landlord", "password": "secret12345"})
        phone_login = self.post_json("/api/auth/login/", {"username": "0771111111", "password": "secret12345"})

        self.assertEqual(login.status_code, 200)
        self.assertEqual(phone_login.status_code, 200)
        tokens = login.json()["tokens"]
        self.assertIn("access", tokens)

        me = self.client.get("/api/auth/me/", HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        self.assertEqual(me.json()["user"]["role"], "landlord")

        refreshed = self.post_json("/api/auth/refresh/", {"refresh": tokens["refresh"]})
        self.assertEqual(refreshed.status_code, 200)
        self.assertIn("access", refreshed.json()["tokens"])

    def test_user_create_without_password_generates_usable_account(self):
        response = self.post_json(
            "/api/users/",
            {"username": "generated-password-user", "email": "generated@property24.test", "name": "Generated User", "role": "tenant"},
            user=self.admin,
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["email"], "generated@property24.test")

    def test_public_registration_creates_role_scoped_account_without_otp(self):
        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "new-landlord",
                "email": "new-landlord@property24.test",
                "password": "CorrectHorseRental2026",
                "name": "New Landlord",
                "account_type": "landlord",
                "phone": "+263771123456",
            },
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["user"]["role"], "landlord")
        self.assertIn("add_properties", payload["account"]["capabilities"])
        self.assertNotIn("proof_of_ownership_or_authorization", payload["account"]["onboarding"]["requirements"])
        self.assertEqual(payload["account"]["onboarding"]["requirements"], ["email_verification", "phone_verification"])
        self.assertTrue(payload["requires_sign_in"])
        self.assertNotIn("tokens", payload)
        self.assertTrue(get_user_model().objects.filter(username="new-landlord").exists())
        self.assertFalse(PendingRegistrationOTP.objects.filter(username="new-landlord").exists())

    def test_public_registration_rejects_weak_passwords(self):
        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "weak-password",
                "email": "weak-password@property24.test",
                "password": "short123",
                "name": "Weak Password",
                "account_type": "tenant",
                "phone": "+263771555555",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("Password", response.json()["error"])
        self.assertFalse(get_user_model().objects.filter(username="weak-password").exists())

    def test_public_registration_accepts_printable_symbols_in_password(self):
        password = "Safe<script>';--2026"
        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "symbol-password",
                "email": "symbol-password@property24.test",
                "password": password,
                "name": "Symbol Password",
                "account_type": "tenant",
                "phone": "+263771777777",
            },
        )

        self.assertEqual(response.status_code, 201)
        user = get_user_model().objects.get(username="symbol-password")
        self.assertTrue(user.password.startswith("argon2$"))
        self.assertTrue(user.check_password(password))

    def test_public_registration_rejects_password_control_characters(self):
        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "control-password",
                "email": "control-password@property24.test",
                "password": "CorrectHorse\nRental2026",
                "name": "Control Password",
                "account_type": "tenant",
                "phone": "+263771888888",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("control characters", response.json()["error"])

    def test_public_registration_rejects_invalid_identity_fields(self):
        bad_email = self.post_json(
            "/api/auth/register/",
            {
                "username": "bad-email",
                "email": "not-an-email",
                "password": "CorrectHorseRental2030",
                "name": "Bad Email",
                "account_type": "tenant",
                "phone": "+263771999999",
            },
        )
        bad_phone = self.post_json(
            "/api/auth/register/",
            {
                "username": "bad-phone",
                "email": "bad-phone@property24.test",
                "password": "CorrectHorseRental2031",
                "name": "Bad Phone",
                "account_type": "tenant",
                "phone": "+263abc",
            },
        )

        self.assertEqual(bad_email.status_code, 400)
        self.assertIn("valid email", bad_email.json()["error"])
        self.assertEqual(bad_phone.status_code, 400)
        self.assertIn("Phone number", bad_phone.json()["error"])

    def test_public_registration_rejects_oversized_password(self):
        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "long-password",
                "email": "long-password@property24.test",
                "password": "A" * 129,
                "name": "Long Password",
                "account_type": "tenant",
                "phone": "+263772111111",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("128", response.json()["error"])

    def test_public_registration_stores_argon2_password_hash(self):
        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "argon2-user",
                "email": "argon2-user@property24.test",
                "password": "CorrectHorseRental2029",
                "name": "Argon Two",
                "account_type": "tenant",
                "phone": "+263771666666",
            },
        )

        self.assertEqual(response.status_code, 201)
        user = get_user_model().objects.get(username="argon2-user")
        self.assertTrue(user.password.startswith("argon2$"))
        self.assertNotIn("CorrectHorseRental2029", user.password)
        self.assertTrue(user.check_password("CorrectHorseRental2029"))
        self.assertNotIn("tokens", response.json())

    def test_public_registration_rejects_duplicate_phone_before_account_creation(self):
        User = get_user_model()
        User.objects.create_user(username="existing-phone", password="secret12345", phone="263771000000")

        response = self.post_json(
            "/api/auth/register/",
            {
                "username": "duplicate-phone",
                "email": "duplicate-phone@property24.test",
                "password": "CorrectHorseRental2026",
                "name": "Duplicate Phone",
                "account_type": "tenant",
                "phone": "+263771000000",
            },
        )
        username_phone_response = self.post_json(
            "/api/auth/register/",
            {
                "username": "+263771000000",
                "email": "duplicate-username-phone@property24.test",
                "password": "CorrectHorseRental2027",
                "name": "Duplicate Username Phone",
                "account_type": "tenant",
                "phone": "+263772000000",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("phone number", response.json()["error"])
        self.assertEqual(username_phone_response.status_code, 400)
        self.assertFalse(get_user_model().objects.filter(username="duplicate-phone").exists())
        self.assertFalse(get_user_model().objects.filter(username="+263771000000").exists())

    @override_settings(OTP_DELIVERY_CHANNEL="email", EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_verification_email_otp_endpoint_sends_and_verifies_code(self):
        self.tenant.email = "old-tenant@example.com"
        self.tenant.save(update_fields=["email"])
        send_response = self.post_json("/api/verifications/email-otp/", {"email": "typed-tenant@example.com"}, user=self.tenant)
        self.assertEqual(send_response.status_code, 201)
        self.assertEqual(send_response.json()["delivery_channel"], "email")
        self.assertNotIn("dev_otp", send_response.json())
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, ["typed-tenant@example.com"])
        challenge_id = send_response.json()["challenge_id"]
        self.assertEqual(send_response.json()["expires_in_seconds"], 30)
        challenge = EmailVerificationOTP.objects.get(pk=challenge_id)
        self.assertEqual(challenge.email, "typed-tenant@example.com")
        self.assertEqual(challenge.sent_to, "typed-tenant@example.com")
        self.assertLessEqual((challenge.expires_at - timezone.now()).total_seconds(), 30)
        self.assertGreater((challenge.expires_at - timezone.now()).total_seconds(), 0)

        challenge.code_hash = hash_otp("123456")
        challenge.save(update_fields=["code_hash"])
        verify_response = self.post_json("/api/verifications/email-otp/verify/", {"challenge_id": challenge_id, "otp": "123456"}, user=self.tenant)

        self.assertEqual(verify_response.status_code, 200)
        self.assertTrue(verify_response.json()["email_verified"])
        challenge.refresh_from_db()
        self.tenant.refresh_from_db()
        self.assertEqual(challenge.status, EmailVerificationOTP.Status.VERIFIED)
        self.assertEqual(self.tenant.email, "typed-tenant@example.com")
        self.assertTrue(self.tenant.email_verified)

    @override_settings(OTP_DELIVERY_CHANNEL="email", EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_verification_email_otp_rejects_email_owned_by_another_account(self):
        User = get_user_model()
        User.objects.create_user(username="email-owner", email="owner@example.com", password="secret12345")
        send_response = self.post_json("/api/verifications/email-otp/", {"email": "owner@example.com"}, user=self.tenant)
        self.assertEqual(send_response.status_code, 400)
        self.assertIn("email", send_response.json()["error"])
        self.assertEqual(len(mail.outbox), 0)

    def test_identity_verification_submission_uses_secure_document_concept(self):
        User = get_user_model()
        tenant = User.objects.create_user(username="identity-tenant", email="identity@example.com", password="secret12345", full_name="Identity Tenant", role=User.Roles.TENANT, is_verified=False)
        phone = "+263779000004"
        self.mark_email_otp_verified(tenant)
        self.mark_phone_otp_verified(tenant, phone)
        response = self.client.post(
            "/api/verifications/",
            data={
                "role": "tenant",
                "name": "Identity Tenant",
                "phone": phone,
                "national_id_number": "63-000000L64",
                "phone_verified": "true",
                "email_verified": "true",
                "privacy_notice_accepted": "true",
                "document_type": "identity_document",
                "id_front_document": self.identity_image_upload("front.jpg"),
                "id_back_document": self.identity_image_upload("back.jpg"),
                "identity_confirmed": "true",
                "declaration_accepted": "true",
            },
            **self.auth_header(tenant),
        )

        self.assertEqual(response.status_code, 201, response.json())
        payload = response.json()
        self.assertEqual(payload["status"], VerificationRequest.Status.MANUAL_REVIEW)
        self.assertEqual(payload["verification_provider"], "manual_capture")
        self.assertTrue(payload["id_front_document_uploaded"])
        self.assertTrue(payload["id_back_document_uploaded"])
        self.assertNotIn("id_front_document", payload)
        self.assertNotIn("id_back_document", payload)
        verification = VerificationRequest.objects.get(user=tenant)
        self.assertTrue(verification.id_number_hash)
        self.assertIn("*", verification.national_id_number)
        self.assertNotEqual(verification.national_id_number, "63-000000L64")
        tenant.refresh_from_db()
        self.assertFalse(tenant.is_verified)

        other = User.objects.create_user(username="identity-duplicate", email="identity-duplicate@example.com", password="secret12345", full_name="Identity Duplicate", role=User.Roles.TENANT, is_verified=False)
        self.mark_email_otp_verified(other)
        duplicate = self.client.post(
            "/api/verifications/",
            data={
                "role": "tenant",
                "name": "Identity Duplicate",
                "phone": phone,
                "national_id_number": "63-000000L64",
                "phone_verified": "true",
                "email_verified": "true",
                "privacy_notice_accepted": "true",
                "document_type": "identity_document",
                "id_front_document": self.identity_image_upload("front-duplicate.jpg"),
                "id_back_document": self.identity_image_upload("back-duplicate.jpg"),
                "identity_confirmed": "true",
                "declaration_accepted": "true",
            },
            **self.auth_header(other),
        )
        self.assertEqual(duplicate.status_code, 400)
        self.assertTrue(any("identity document" in error for error in duplicate.json()["errors"]))

    def test_normalize_phone_accepts_zimbabwe_local_and_e164_forms(self):
        self.assertEqual(normalize_phone("0775845535"), "+263775845535")
        self.assertEqual(normalize_phone("+2630775845535"), "+263775845535")
        self.assertEqual(normalize_phone("2630775845535"), "+263775845535")
        self.assertEqual(normalize_phone("+27115550123"), "+27115550123")
        lookup_values = set(phone_lookup_values("+2630775845535"))
        self.assertIn("+263775845535", lookup_values)
        self.assertIn("0775845535", lookup_values)

    @override_settings(
        OTP_DELIVERY_CHANNEL="sms",
        OTP_SMS_PROVIDER="twilio",
        TWILIO_ACCOUNT_SID="AC123456789",
        TWILIO_AUTH_TOKEN="twilio-token",
        TWILIO_FROM_NUMBER="+15005550006",
        TWILIO_MESSAGING_SERVICE_SID="",
    )
    @patch("rentals.views.urlrequest.urlopen")
    def test_verification_phone_otp_can_use_twilio_trial_sms(self, mock_urlopen):
        class Response:
            status = 201

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, tb):
                return False

        mock_urlopen.return_value = Response()
        phone = "+263778123456"
        response = self.post_json("/api/verifications/phone-otp/", {"phone": phone}, user=self.tenant)

        self.assertEqual(response.status_code, 201, response.json())
        self.assertEqual(response.json()["delivery_channel"], "sms")
        self.assertEqual(response.json()["message"], "OTP sent to your phone")
        self.assertNotIn("dev_otp", response.json())
        request = mock_urlopen.call_args.args[0]
        self.assertIn("api.twilio.com", request.full_url)
        self.assertIn(b"To=%2B263778123456", request.data)
        self.assertIn(b"From=%2B15005550006", request.data)
        challenge = PhoneVerificationOTP.objects.get(pk=response.json()["challenge_id"])
        challenge.code_hash = hash_otp("654321")
        challenge.save(update_fields=["code_hash"])
        verify_response = self.post_json("/api/verifications/phone-otp/verify/", {"challenge_id": challenge.id, "otp": "654321"}, user=self.tenant)
        self.assertEqual(verify_response.status_code, 200, verify_response.json())
        self.tenant.refresh_from_db()
        self.assertEqual(self.tenant.phone, phone)
        self.assertTrue(self.tenant.phone_verified)

    def test_verification_id_extract_requires_manual_entry_without_ocr(self):
        response = self.client.post(
            "/api/verifications/id-extract/",
            data={
                "national_id_number": "63-000000L63",
                "id_front_document": self.identity_image_upload("extract-front.jpg"),
                "id_back_document": self.identity_image_upload("extract-back.jpg"),
            },
            **self.auth_header(self.tenant),
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["extracted_national_id_number"], "")
        self.assertEqual(response.json()["confidence"], "manual_entry_required")
        self.assertTrue(response.json()["requires_confirmation"])

    def test_verified_landlord_can_create_agent_account(self):
        response = self.post_json(
            "/api/landlord/agents/",
            {
                "email": "landlord-agent@property24.test",
                "name": "Landlord Agent",
                "phone": "+263774444444",
                "password": "CorrectHorseAgent2033",
            },
            user=self.landlord,
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["user"]["role"], "agent")
        self.assertFalse(payload["user"]["verified"])
        self.assertTrue(get_user_model().objects.filter(email="landlord-agent@property24.test", role="agent").exists())

    def test_unverified_landlord_cannot_create_agent_account(self):
        User = get_user_model()
        unverified = User.objects.create_user(username="unverified-owner", password="secret12345", role=User.Roles.LANDLORD, is_verified=False)

        response = self.post_json(
            "/api/landlord/agents/",
            {"email": "blocked-agent@property24.test", "name": "Blocked Agent", "phone": "+263775555555", "password": "CorrectHorseAgent2034"},
            user=unverified,
        )

        self.assertEqual(response.status_code, 403)
        self.assertFalse(User.objects.filter(email="blocked-agent@property24.test").exists())

    def test_public_registration_rejects_agent_accounts(self):
        response = self.post_json(
            "/api/auth/register/",
            {"username": "public-agent", "email": "public-agent@property24.test", "password": "CorrectHorseRental2032", "account_type": "agent"},
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("tenant or landlord", response.json()["error"])

    def test_public_registration_rejects_admin_accounts(self):
        response = self.post_json(
            "/api/auth/register/",
            {"username": "public-admin", "email": "public-admin@property24.test", "password": "CorrectHorseRental2028", "account_type": "admin", "phone": "+263774000000"},
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("Public registration", response.json()["error"])

    @override_settings(GOOGLE_SIGN_IN_ENABLED=True, GOOGLE_CLIENT_IDS=["web-client-id.apps.googleusercontent.com"])
    @patch("rentals.views.verify_google_id_token")
    def test_google_auth_creates_role_scoped_account_without_platform_verification(self, verify_google_id_token):
        verify_google_id_token.return_value = {
            "sub": "google-user-123",
            "email": "google-tenant@property24.test",
            "email_verified": True,
            "name": "Google Tenant",
        }

        response = self.post_json("/api/auth/google/", {"id_token": "verified-google-token", "account_type": "tenant", "phone": "+263779123456"})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["user"]["role"], "tenant")
        self.assertEqual(payload["user"]["auth_provider"], "google")
        self.assertTrue(payload["user"]["google_email_verified"])
        self.assertFalse(payload["user"]["verified"])
        self.assertIn("apply_for_rentals", payload["account"]["capabilities"])
        self.assertIn("email_verification", payload["account"]["onboarding"]["requirements"])
        self.assertIn("tokens", payload)

    @override_settings(GOOGLE_SIGN_IN_ENABLED=True, GOOGLE_CLIENT_IDS=["web-client-id.apps.googleusercontent.com"])
    @patch("rentals.views.verify_google_id_token")
    def test_google_auth_new_account_can_start_without_phone_before_verification(self, verify_google_id_token):
        verify_google_id_token.return_value = {
            "sub": "google-no-phone-123",
            "email": "google-no-phone@property24.test",
            "email_verified": True,
            "name": "Google No Phone",
        }

        response = self.post_json("/api/auth/google/", {"id_token": "verified-google-token", "account_type": "tenant"})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertFalse(payload["user"]["verified"])
        self.assertTrue(payload["account"]["onboarding"]["required"])

    @override_settings(GOOGLE_SIGN_IN_ENABLED=True, GOOGLE_CLIENT_IDS=["web-client-id.apps.googleusercontent.com"])
    @patch("rentals.views.verify_google_id_token")
    def test_google_auth_new_account_rejects_duplicate_phone(self, verify_google_id_token):
        verify_google_id_token.return_value = {
            "sub": "google-duplicate-phone-123",
            "email": "google-duplicate-phone@property24.test",
            "email_verified": True,
            "name": "Google Duplicate Phone",
        }

        response = self.post_json("/api/auth/google/", {"id_token": "verified-google-token", "account_type": "tenant", "phone": "0771111111"})

        self.assertEqual(response.status_code, 400)
        self.assertIn("phone number", response.json()["error"])

    @override_settings(GOOGLE_SIGN_IN_ENABLED=True, GOOGLE_CLIENT_IDS=["web-client-id.apps.googleusercontent.com"])
    @patch("rentals.views.verify_google_id_token")
    def test_google_auth_existing_account_signs_in_without_role_selection(self, verify_google_id_token):
        User = get_user_model()
        User.objects.create_user(
            username="google-landlord",
            email="google-landlord@property24.test",
            password="secret12345",
            full_name="Google Landlord",
            role=User.Roles.LANDLORD,
            auth_provider="google",
            google_subject="google-landlord-123",
            google_email_verified=True,
        )
        verify_google_id_token.return_value = {
            "sub": "google-landlord-123",
            "email": "google-landlord@property24.test",
            "email_verified": True,
            "name": "Google Landlord",
        }

        response = self.post_json("/api/auth/google/", {"id_token": "verified-google-token"})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["user"]["role"], "landlord")
        self.assertEqual(payload["account"]["account_type"], "landlord")
        self.assertIn("add_properties", payload["account"]["capabilities"])

    @override_settings(GOOGLE_SIGN_IN_ENABLED=True, GOOGLE_CLIENT_IDS=["web-client-id.apps.googleusercontent.com"])
    @patch("rentals.views.verify_google_id_token")
    def test_google_auth_rejects_public_admin_role(self, verify_google_id_token):
        verify_google_id_token.return_value = {
            "sub": "google-admin-123",
            "email": "google-admin@property24.test",
            "email_verified": True,
            "name": "Public Admin",
        }

        response = self.post_json("/api/auth/google/", {"id_token": "verified-google-token", "account_type": "admin"})

        self.assertEqual(response.status_code, 400)
        self.assertIn("tenant or landlord", response.json()["error"])

    def test_auth_me_returns_role_specific_hidden_sections(self):
        login = self.post_json("/api/auth/login/", {"username": "landlord", "password": "secret12345"})
        token = login.json()["tokens"]["access"]

        response = self.client.get("/api/auth/me/", HTTP_AUTHORIZATION=f"Bearer {token}")

        self.assertEqual(response.status_code, 200)
        account = response.json()["account"]
        self.assertEqual(account["account_type"], "landlord")
        self.assertIn("properties", account["visible_sections"])
        self.assertIn("commissions", account["hidden_sections"])

    def test_least_privilege_blocks_tenant_from_admin_user_list_and_property_create(self):
        users_response = self.client.get("/api/users/", **self.auth_header(self.tenant))
        property_response = self.post_json(
            "/api/properties/",
            {
                "owner_id": self.tenant.id,
                "title": "Tenant should not list",
                "address": "1 Blocked Road",
                "city": "Harare",
                "suburb": "CBD",
                "monthly_rent": "300",
                "deposit_required": "300",
                "bedrooms": 1,
                "bathrooms": 1,
                "type": "flat",
            },
            user=self.tenant,
        )

        self.assertEqual(users_response.status_code, 403)
        self.assertEqual(property_response.status_code, 403)

    def test_unverified_account_is_locked_to_verification_flow(self):
        User = get_user_model()
        unverified_tenant = User.objects.create_user(username="locked-tenant", password="secret12345", role=User.Roles.TENANT, is_verified=False)
        blocked = self.post_json(
            f"/api/properties/{self.property.id}/comments/",
            {"body": "Can I view this house?"},
            user=unverified_tenant,
        )
        unverified_tenant.email = "locked-tenant@example.com"
        unverified_tenant.save(update_fields=["email"])
        self.mark_email_otp_verified(unverified_tenant)
        self.mark_phone_otp_verified(unverified_tenant, "+263779000002")
        allowed = self.client.post(
            "/api/verifications/",
            data={
                "role": "tenant",
                "name": "Jane Smith",
                "phone": "+263779000002",
                "national_id_number": "63-000000L64",
                "extracted_national_id_number": "63-000000L64",
                "phone_verified": "true",
                "email_verified": "true",
                "privacy_notice_accepted": "true",
                "document_type": "identity_document",
                "residential_address": "12 Borrowdale Road, Harare",
                "address_gps_confirmed": "true",
                "proof_of_address_confirmed": "true",
                "declaration_accepted": "true",
                "id_front_document": self.identity_image_upload("locked-front.jpg"),
                "id_back_document": self.identity_image_upload("locked-back.jpg"),
                "identity_confirmed": "true",
            },
            **self.auth_header(unverified_tenant),
        )

        self.assertEqual(blocked.status_code, 403)
        self.assertIn("verification", blocked.json()["error"].lower())
        self.assertEqual(allowed.status_code, 201, allowed.json())

    def test_verification_submission_requires_id_otp_and_document_evidence(self):
        phone = "+263779000001"
        incomplete = self.post_json(
            "/api/verifications/",
            {"role": "landlord", "name": "John Doe", "phone": phone, "national_id_number": "63-000000L63", "phone_verified": False},
            user=self.landlord,
        )
        self.landlord.email = "landlord@example.com"
        self.landlord.save(update_fields=["email"])
        self.mark_email_otp_verified(self.landlord)
        self.mark_phone_otp_verified(self.landlord, phone)
        complete = self.client.post(
            "/api/verifications/",
            data={
                "role": "landlord",
                "name": "John Doe",
                "phone": phone,
                "national_id_number": "63-000000L63",
                "extracted_national_id_number": "63-000000L63",
                "phone_verified": "true",
                "email_verified": "true",
                "privacy_notice_accepted": "true",
                "document_type": "identity_document",
                "residential_address": "12 Borrowdale Road, Harare",
                "address_gps_confirmed": "true",
                "proof_of_address_confirmed": "true",
                "declaration_accepted": "true",
                "id_front_document": self.identity_image_upload("landlord-front.jpg"),
                "id_back_document": self.identity_image_upload("landlord-back.jpg"),
                "ownership_or_authorization_document": self.identity_image_upload("landlord-ownership.jpg"),
                "identity_confirmed": "true",
            },
            **self.auth_header(self.landlord),
        )

        self.assertEqual(incomplete.status_code, 400)
        self.assertTrue(any("id_front_document" in error for error in incomplete.json()["errors"]))
        self.assertTrue(any("email_verified" in error for error in incomplete.json()["errors"]))
        self.assertFalse(any("proof_of_ownership_or_authorization" in error for error in incomplete.json()["errors"]))
        self.assertEqual(complete.status_code, 201, complete.json())
        self.assertEqual(complete.json()["status"], VerificationRequest.Status.MANUAL_REVIEW)
        self.assertTrue(complete.json()["identity_confirmed"])

    def test_identity_document_number_must_have_valid_format(self):
        phone = "+263779000003"
        self.tenant.email = "tenant@example.com"
        self.tenant.save(update_fields=["email"])
        self.mark_email_otp_verified(self.tenant)
        response = self.client.post(
            "/api/verifications/",
            data={
                "role": "tenant",
                "name": "Jane Smith",
                "phone": phone,
                "national_id_number": "!!",
                "phone_verified": "false",
                "email_verified": "true",
                "document_type": "identity_document",
                "id_front_document": self.identity_image_upload("invalid-front.jpg"),
                "id_back_document": self.identity_image_upload("invalid-back.jpg"),
                "identity_confirmed": "true",
            },
            **self.auth_header(self.tenant),
        )

        self.assertEqual(response.status_code, 400)
        self.assertTrue(any("document number" in error for error in response.json()["errors"]))

    def test_renter_can_verify_with_identity_document(self):
        User = get_user_model()
        foreign_tenant = User.objects.create_user(username="foreign-tenant", password="secret12345", role=User.Roles.TENANT, is_verified=False)
        phone = "+27115550123"
        foreign_tenant.email = "foreign@example.com"
        foreign_tenant.save(update_fields=["email"])
        self.mark_email_otp_verified(foreign_tenant)
        self.mark_phone_otp_verified(foreign_tenant, phone)
        response = self.client.post(
            "/api/verifications/",
            data={
                "role": "tenant",
                "name": "Nomsa Dlamini",
                "phone": phone,
                "document_type": "identity_document",
                "national_id_number": "A12345678",
                "phone_verified": "true",
                "email_verified": "true",
                "id_front_document": self.identity_image_upload("identity-front.jpg"),
                "id_back_document": self.identity_image_upload("identity-back.jpg"),
                "identity_confirmed": "true",
                "privacy_notice_accepted": "true",
                "declaration_accepted": "true",
            },
            **self.auth_header(foreign_tenant),
        )

        self.assertEqual(response.status_code, 201, response.json())
        self.assertEqual(response.json()["document_type"], "identity_document")

    def test_least_privilege_scopes_tenant_records_to_self(self):
        User = get_user_model()
        other_tenant = User.objects.create_user(username="other-tenant", password="secret12345", role=User.Roles.TENANT)

        history_response = self.client.get(f"/api/users/{other_tenant.id}/rental-history/", **self.auth_header(self.tenant))
        save_response = self.post_json(f"/api/properties/{self.property.id}/save/", {"tenant_id": other_tenant.id}, user=self.tenant)

        self.assertEqual(history_response.status_code, 403)
        self.assertEqual(save_response.json()["tenant_id"], self.tenant.id)

    def complete_tenant_rental_lifecycle(self, tenant=None, prop=None):
        tenant = tenant or self.tenant
        prop = prop or self.property
        Viewing.objects.create(property=prop, tenant=tenant, agent=self.agent, scheduled_for=timezone.now(), status=Viewing.Status.COMPLETED)
        Application.objects.update_or_create(property=prop, tenant=tenant, defaults={"status": Application.Status.APPROVED, "score": 90})
        return LeaseAgreement.objects.create(
            property=prop,
            tenant=tenant,
            landlord=self.landlord,
            start_date="2026-07-01",
            end_date="2027-06-30",
            monthly_rent=prop.monthly_rent,
            deposit=prop.deposit_required,
            term="12 Months",
            status=LeaseAgreement.Status.ACTIVE,
            signed_by_tenant=True,
            signed_by_landlord=True,
        )

    def test_application_and_lease_follow_viewing_and_approval_order(self):
        early_application = self.post_json(
            "/api/applications/",
            {"property_id": self.property.id, "message": "I want to apply before viewing."},
            user=self.tenant,
        )
        self.assertEqual(early_application.status_code, 409)
        self.assertIn("Physical viewing", early_application.json()["errors"][0])

        Viewing.objects.create(property=self.property, tenant=self.tenant, agent=self.agent, scheduled_for=timezone.now(), status=Viewing.Status.COMPLETED)
        application = self.post_json(
            "/api/applications/",
            {"property_id": self.property.id, "message": "I viewed the property and want to apply."},
            user=self.tenant,
        )
        self.assertEqual(application.status_code, 201)

        early_lease = self.post_json(
            "/api/leases/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "start_date": "2026-07-01", "end_date": "2027-06-30"},
            user=self.landlord,
        )
        self.assertEqual(early_lease.status_code, 409)
        self.assertIn("approved", early_lease.json()["errors"][0].lower())

        Application.objects.filter(property=self.property, tenant=self.tenant).update(status=Application.Status.APPROVED)
        lease = self.post_json(
            "/api/leases/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "start_date": "2026-07-01", "end_date": "2027-06-30"},
            user=self.landlord,
        )
        self.assertEqual(lease.status_code, 201)

    def test_payment_and_maintenance_unlock_only_after_verified_rental_lifecycle(self):
        early_payment = self.post_json(
            "/api/payments/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "amount": "450", "method": "ecocash"},
            user=self.tenant,
        )
        early_maintenance = self.post_json(
            "/api/maintenance/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "issue": "Leaking sink", "description": "Water under the sink."},
            user=self.tenant,
        )

        self.assertEqual(early_payment.status_code, 409)
        self.assertIn("Physical viewing", early_payment.json()["errors"][0])
        self.assertEqual(early_maintenance.status_code, 409)
        self.assertIn("active lease", early_maintenance.json()["errors"][0])

        self.complete_tenant_rental_lifecycle()

        unlocked_payment = self.post_json(
            "/api/payments/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "amount": "450", "method": "ecocash", "status": "received"},
            user=self.tenant,
        )
        unlocked_maintenance = self.post_json(
            "/api/maintenance/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "issue": "Leaking sink", "description": "Water under the sink."},
            user=self.tenant,
        )

        self.assertEqual(unlocked_payment.status_code, 201)
        self.assertEqual(unlocked_payment.json()["status"], Payment.Status.PENDING)
        self.assertEqual(unlocked_maintenance.status_code, 201)
        self.assertEqual(unlocked_maintenance.json()["status"], MaintenanceRequest.Status.OPEN)

    def test_least_privilege_tenant_payment_is_pending_not_self_marked_received(self):
        self.complete_tenant_rental_lifecycle()
        response = self.post_json(
            "/api/payments/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "amount": "450", "method": "ecocash", "status": "received"},
            user=self.tenant,
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["status"], Payment.Status.PENDING)
        self.assertIsNone(response.json()["paid_at"])

    def test_lease_generation_and_signing(self):
        Viewing.objects.create(property=self.property, tenant=self.tenant, agent=self.agent, scheduled_for=timezone.now(), status=Viewing.Status.COMPLETED)
        Application.objects.create(property=self.property, tenant=self.tenant, status=Application.Status.APPROVED, score=90)
        response = self.post_json(
            "/api/leases/",
            {
                "property_id": self.property.id,
                "tenant_id": self.tenant.id,
                "start_date": "2026-07-01",
                "end_date": "2027-06-30",
                "term": "12 Months",
            },
            user=self.landlord,
        )

        self.assertEqual(response.status_code, 201)
        lease_id = response.json()["id"]
        self.assertIn("Residential Lease Agreement", response.json()["contract_text"])

        self.post_json(f"/api/leases/{lease_id}/sign/", {"signed_by": "tenant"}, user=self.tenant)
        signed = self.post_json(f"/api/leases/{lease_id}/sign/", {"signed_by": "landlord"}, user=self.landlord).json()
        self.assertEqual(signed["status"], LeaseAgreement.Status.ACTIVE)

    def test_landlord_analytics_counts_income_and_activity(self):
        Payment.objects.create(
            tenant=self.tenant,
            property=self.property,
            amount="450.00",
            method=Payment.Method.ECOCASH,
            status=Payment.Status.RECEIVED,
            receipt_number="RCT-2026-0001",
        )
        Viewing.objects.create(property=self.property, tenant=self.tenant, agent=self.agent, scheduled_for=timezone.now(), status=Viewing.Status.COMPLETED)
        self.post_json(
            "/api/applications/",
            {"property_id": self.property.id, "tenant_id": self.tenant.id, "status": "submitted", "score": 80},
            user=self.tenant,
        )

        response = self.client.get(f"/api/analytics/landlords/{self.landlord.id}/", **self.auth_header(self.landlord))

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["applications"], 1)
        self.assertEqual(payload["rental_income"], "450")

    def test_verified_listing_requires_verified_owner_and_valid_role(self):
        User = get_user_model()
        unverified_landlord = User.objects.create_user(username="pending-owner", role=User.Roles.LANDLORD, is_verified=False)
        response = self.post_json(
            "/api/properties/",
            {
                "owner_id": unverified_landlord.id,
                "title": "Pending listing",
                "address": "1 Test Road",
                "city": "Harare",
                "suburb": "Avondale",
                "monthly_rent": "500",
                "deposit_required": "500",
                "bedrooms": 2,
                "bathrooms": 1,
                "type": "Flat",
                "listing_status": "verified",
            },
            user=self.admin,
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("owner must be verified", response.json()["error"])

    def test_ai_reviews_listing_application_and_maintenance_payloads(self):
        listing = self.post_json(
            "/api/properties/",
            {
                "owner_id": self.landlord.id,
                "title": "Avondale cottage",
                "description": "Whatsapp only, urgent deposit required before viewing",
                "address": "7 Test Lane",
                "city": "Harare",
                "suburb": "Avondale",
                "monthly_rent": "400",
                "deposit_required": "1200",
                "bedrooms": 1,
                "bathrooms": 1,
                "type": "Cottage",
            },
            user=self.landlord,
        )
        self.assertEqual(listing.status_code, 201)
        self.assertEqual(listing.json()["ai_review"]["analysis_type"], "listing_risk")
        self.assertTrue(AIAnalysis.objects.filter(target_type="property").exists())

        Viewing.objects.create(property=self.property, tenant=self.tenant, agent=self.agent, scheduled_for=timezone.now(), status=Viewing.Status.COMPLETED)
        application = self.post_json(
            "/api/applications/",
            {
                "property_id": self.property.id,
                "tenant_id": self.tenant.id,
                "message": "I am interested in this home and can provide references and employment confirmation.",
            },
            user=self.tenant,
        )
        self.assertEqual(application.status_code, 201)
        self.assertIn("ai_score", application.json())

        self.complete_tenant_rental_lifecycle()
        maintenance = self.post_json(
            "/api/maintenance/",
            {
                "property_id": self.property.id,
                "tenant_id": self.tenant.id,
                "issue": "Burst pipe flooding the kitchen",
                "description": "Water is spreading quickly.",
            },
            user=self.tenant,
        )
        self.assertEqual(maintenance.status_code, 201)
        self.assertEqual(maintenance.json()["priority"], "urgent")
        self.assertEqual(maintenance.json()["category"], MaintenanceRequest.Category.PLUMBING)

    def test_conversation_messages_mark_read_and_validate_body(self):
        conversation = Conversation.objects.create(property=self.property, title="Borrowdale chat")
        conversation.participants.set([self.tenant, self.agent])
        message = Message.objects.create(conversation=conversation, sender=self.agent, body="Viewing confirmed")

        empty_response = self.post_json(f"/api/conversations/{conversation.id}/messages/", {"body": "   "}, user=self.tenant)
        list_response = self.client.get(f"/api/conversations/{conversation.id}/messages/", **self.auth_header(self.tenant))
        message.refresh_from_db()

        self.assertEqual(empty_response.status_code, 400)
        self.assertEqual(list_response.status_code, 200)
        self.assertIsNotNone(message.read_at)
        self.assertIsNotNone(list_response.json()["results"][0]["read_at"])

    def test_conversation_calls_can_be_listed_and_ended(self):
        conversation = Conversation.objects.create(property=self.property, title="Borrowdale chat")
        conversation.participants.set([self.tenant, self.agent])

        create_response = self.post_json(f"/api/conversations/{conversation.id}/calls/", {"mode": "video"}, user=self.tenant)
        call_id = create_response.json()["id"]
        list_response = self.client.get(f"/api/conversations/{conversation.id}/calls/", **self.auth_header(self.agent))
        end_response = self.patch_json(f"/api/conversations/{conversation.id}/calls/{call_id}/", {"status": "ended"}, user=self.agent)

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(list_response.json()["results"][0]["status"], CallSession.Status.RINGING)
        self.assertEqual(end_response.status_code, 200)
        self.assertEqual(end_response.json()["status"], CallSession.Status.ENDED)
        self.assertIsNotNone(end_response.json()["ended_at"])

    def test_property_comments_are_saved_in_app_and_counted_on_listing(self):
        path = f"/api/properties/{self.property.id}/comments/"

        create_response = self.post_json(path, {"body": "Can I view the kitchen photos?", "media_url": "https://example.com/kitchen.jpg"}, user=self.tenant)
        list_response = self.client.get(path, **self.auth_header(self.tenant))
        public_listing = self.client.get("/api/properties/").json()["results"][0]
        anonymous_response = self.client.get(path)

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(create_response.json()["author"]["name"], "Jane Smith")
        self.assertEqual(create_response.json()["media_url"], "https://example.com/kitchen.jpg")
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.json()["results"]), 1)
        self.assertEqual(public_listing["comments_count"], 1)
        self.assertEqual(PropertyComment.objects.filter(property=self.property, author=self.tenant).count(), 1)
        self.assertEqual(anonymous_response.status_code, 401)

    def test_property_media_saved_listing_and_rental_history(self):
        photo_response = self.post_json(f"/api/properties/{self.property.id}/photos/", {"caption": "Front elevation"}, user=self.landlord)
        video_response = self.post_json(f"/api/properties/{self.property.id}/videos/", {"external_url": "https://example.com/tour.mp4", "caption": "Walkthrough"}, user=self.landlord)
        save_response = self.post_json(f"/api/properties/{self.property.id}/save/", {"tenant_id": self.tenant.id}, user=self.tenant)

        self.assertEqual(photo_response.status_code, 201)
        self.assertEqual(video_response.status_code, 201)
        self.assertEqual(save_response.json()["saved_count"], 1)

    def test_landlord_can_assign_agent_when_creating_listing(self):
        response = self.post_json(
            "/api/properties/",
            {
                "agent_id": self.agent.id,
                "title": "Mount Pleasant flat",
                "address": "22 Kingfisher Road",
                "city": "Harare",
                "suburb": "Mount Pleasant",
                "monthly_rent": "650",
                "deposit_required": "650",
                "bedrooms": 2,
                "bathrooms": 1,
                "property_type": "flat",
                "latitude": "-17.770000",
                "longitude": "31.050000",
            },
            user=self.landlord,
        )

        self.assertEqual(response.status_code, 201, response.json())
        self.assertEqual(response.json()["agent"]["id"], self.agent.id)
        self.assertEqual(response.json()["gps"], "-17.770000, 31.050000")

    def test_property_photo_upload_is_limited_to_ten(self):
        for index in range(10):
            PropertyPhoto.objects.create(property=self.property, caption=f"Photo {index}", sort_order=index)

        response = self.post_json(f"/api/properties/{self.property.id}/photos/", {"caption": "Overflow"}, user=self.landlord)

        self.assertEqual(response.status_code, 400)
        self.assertIn("maximum of 10 photos", response.json()["error"])

        Payment.objects.create(
            tenant=self.tenant,
            property=self.property,
            amount="450.00",
            method=Payment.Method.ZIPIT,
            status=Payment.Status.RECEIVED,
            receipt_number="RCT-2026-0002",
        )
        history = self.client.get(f"/api/users/{self.tenant.id}/rental-history/", **self.auth_header(self.tenant)).json()
        self.assertEqual(len(history["payments"]), 1)

    def test_application_maintenance_report_commission_and_reminder_workflows(self):
        application = Application.objects.create(property=self.property, tenant=self.tenant)
        application_response = self.client.patch(
            f"/api/applications/{application.id}/",
            data=json.dumps({"status": "approved", "score": 95}),
            content_type="application/json",
            **self.auth_header(self.landlord),
        )

        maintenance = MaintenanceRequest.objects.create(property=self.property, tenant=self.tenant, issue="Leaking sink", category=MaintenanceRequest.Category.PLUMBING)
        maintenance_response = self.client.patch(
            f"/api/maintenance/{maintenance.id}/",
            data=json.dumps({"status": "resolved", "priority": "normal"}),
            content_type="application/json",
            **self.auth_header(self.landlord),
        )

        report = DisputeReport.objects.create(reporter=self.tenant, property=self.property, subject="Fake advert", description="Needs review")
        report_response = self.client.patch(
            f"/api/reports/{report.id}/",
            data=json.dumps({"status": "resolved", "assigned_admin_id": self.admin.id}),
            content_type="application/json",
            **self.auth_header(self.admin),
        )

        commission_response = self.post_json(
            "/api/commissions/",
            {"agent_id": self.agent.id, "property_id": self.property.id, "amount": "45.00", "status": "earned"},
            user=self.agent,
        )

        payment = Payment.objects.create(
            tenant=self.tenant,
            property=self.property,
            amount="450.00",
            method=Payment.Method.ECOCASH,
            status=Payment.Status.PENDING,
            receipt_number="RCT-2026-0003",
        )
        reminder_response = self.post_json(f"/api/payments/{payment.id}/reminder/", {"reminder_status": "Reminder sent by SMS"}, user=self.landlord)

        self.assertEqual(application_response.json()["status"], Application.Status.APPROVED)
        self.assertEqual(maintenance_response.json()["status"], MaintenanceRequest.Status.RESOLVED)
        self.assertEqual(report_response.json()["status"], DisputeReport.Status.RESOLVED)
        self.assertEqual(commission_response.status_code, 201)
        self.assertEqual(reminder_response.json()["reminder_status"], "Reminder sent by SMS")


class RentalWebSocketTests(TransactionTestCase):
    reset_sequences = True

    def setUp(self):
        User = get_user_model()
        self.landlord = User.objects.create_user(username="ws-landlord", password="secret12345", full_name="John Doe", role=User.Roles.LANDLORD, is_verified=True)
        self.tenant = User.objects.create_user(username="ws-tenant", password="secret12345", full_name="Jane Smith", role=User.Roles.TENANT, is_verified=True)
        self.agent = User.objects.create_user(username="ws-agent", password="secret12345", full_name="Tariro Moyo", role=User.Roles.AGENT, is_verified=True)
        self.property = Property.objects.create(
            owner=self.landlord,
            agent=self.agent,
            title="Borrowdale family house",
            address="123 Borrowdale Road",
            city="Harare",
            suburb="Borrowdale",
            monthly_rent="450.00",
            deposit_required="450.00",
            property_type=Property.PropertyType.HOUSE,
            bedrooms=3,
            bathrooms="2.0",
            listing_status=Property.ListingStatus.VERIFIED,
        )
        self.conversation = Conversation.objects.create(property=self.property, title="Live chat")
        self.conversation.participants.set([self.tenant, self.agent])

    def test_websocket_participant_can_send_live_message_and_presence_is_audited(self):
        async_to_sync(self._websocket_participant_can_send_live_message_and_presence_is_audited)()

    async def _websocket_participant_can_send_live_message_and_presence_is_audited(self):
        token = issue_token_pair(self.tenant)["access"]
        communicator = WebsocketCommunicator(application, f"/ws/conversations/?token={token}", headers=[(b"host", b"localhost"), (b"origin", b"http://localhost")])
        connected, _ = await communicator.connect()
        self.assertTrue(connected)

        ready = await receive_until(communicator, "connection.ready")
        self.assertIn(str(self.conversation.id), ready["payload"]["conversation_ids"])

        await communicator.send_json_to({"type": "message.send", "conversation_id": self.conversation.id, "body": "Is viewing still available?"})
        created = await receive_until(communicator, "message.created")
        self.assertEqual(created["payload"]["body"], "Is viewing still available?")

        await communicator.disconnect()
        self.assertTrue(await message_exists("Is viewing still available?"))
        self.assertTrue(await audit_exists("websocket_connected"))
        self.assertTrue(await audit_exists("message_created"))

    def test_websocket_denies_conversation_outside_participation(self):
        async_to_sync(self._websocket_denies_conversation_outside_participation)()

    async def _websocket_denies_conversation_outside_participation(self):
        other = await create_other_conversation(self.landlord, self.property)
        token = issue_token_pair(self.tenant)["access"]
        communicator = WebsocketCommunicator(application, f"/ws/conversations/?token={token}", headers=[(b"host", b"localhost"), (b"origin", b"http://localhost")])
        connected, _ = await communicator.connect()
        self.assertTrue(connected)
        await receive_until(communicator, "connection.ready")

        await communicator.send_json_to({"type": "message.send", "conversation_id": other.id, "body": "Let me in"})
        error = await receive_until(communicator, "error")
        self.assertIn("cannot access", error["payload"]["message"])

        await communicator.disconnect()
        self.assertFalse(await message_exists("Let me in"))
        self.assertTrue(await audit_exists("conversation_access_denied"))


async def receive_until(communicator, event_type, limit=6):
    for _ in range(limit):
        event = await communicator.receive_json_from()
        if event.get("type") == event_type:
            return event
    raise AssertionError(f"WebSocket event {event_type} was not received")


@database_sync_to_async
def message_exists(body):
    return Message.objects.filter(body=body).exists()


@database_sync_to_async
def audit_exists(event_type):
    return SecurityAuditEvent.objects.filter(event_type=event_type).exists()


@database_sync_to_async
def create_other_conversation(landlord, prop):
    conversation = Conversation.objects.create(property=prop, title="Private owner chat")
    conversation.participants.set([landlord])
    return conversation
