import json
from unittest.mock import patch
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone

from .models import PhoneLoginChallenge, User


class PhoneLoginTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="phone-user", email="phone@example.test", password="A-strong-password-123!",
            phone="+263771234567", phone_verified=True,
        )

    def post(self, path, body):
        return self.client.post(path, data=json.dumps(body), content_type="application/json")

    @patch("rentals.phone_login._provider", return_value={"sid": "VE-test", "status": "pending"})
    def test_normalized_send_issues_no_session_until_provider_approval(self, provider):
        sent = self.post("/api/auth/phone/send/", {"phone": "077 123 4567", "country": "ZW"})
        self.assertEqual(sent.status_code, 200)
        provider.assert_called_once_with("Verifications", {"To": "+263771234567", "Channel": "sms"})
        challenge_id = sent.json()["challenge_id"]
        self.assertNotIn("tokens", sent.json())
        provider.return_value = {"status": "pending"}
        rejected = self.post("/api/auth/phone/check/", {"challenge_id": challenge_id, "code": "123456"})
        self.assertEqual(rejected.status_code, 400)
        self.assertNotIn("tokens", rejected.json())
        provider.return_value = {"status": "approved"}
        approved = self.post("/api/auth/phone/check/", {
            "challenge_id": challenge_id, "code": "123456", "user_id": 999999, "role": "admin",
        })
        self.assertEqual(approved.status_code, 200)
        self.assertIn("tokens", approved.json())
        self.assertEqual(approved.json()["user"]["id"], self.user.id)
        replay = self.post("/api/auth/phone/check/", {"challenge_id": challenge_id, "code": "123456"})
        self.assertEqual(replay.status_code, 400)

    def test_invalid_number_and_unverified_legacy_phone_do_not_authenticate(self):
        invalid = self.post("/api/auth/phone/send/", {"phone": "not a number", "country": "ZW"})
        self.assertEqual(invalid.status_code, 400)
        self.user.phone_verified = False
        self.user.save(update_fields=["phone_verified"])
        with patch("rentals.phone_login._provider", return_value={"sid": "VE-test"}):
            sent = self.post("/api/auth/phone/send/", {"phone": "0771234567", "country": "ZW"})
        self.assertEqual(sent.status_code, 200)
        self.assertIsNone(PhoneLoginChallenge.objects.get(pk=sent.json()["challenge_id"]).user)

    @patch("rentals.phone_login._provider", return_value={"sid": "VE-test"})
    def test_new_attempt_replaces_previous_challenge_and_cannot_substitute_account(self, provider):
        first = self.post("/api/auth/phone/send/", {"phone": "+263771234567", "country": "ZW"})
        # Destination cooldown is enforced server-side, so wait until its window expires.
        challenge = PhoneLoginChallenge.objects.get(pk=first.json()["challenge_id"])
        from django.utils import timezone
        from datetime import timedelta
        PhoneLoginChallenge.objects.filter(pk=challenge.pk).update(last_sent_at=timezone.now()-timedelta(seconds=31))
        second = self.post("/api/auth/phone/send/", {"phone": "+263771234567", "country": "ZW", "challenge_id": first.json()["challenge_id"]})
        self.assertEqual(second.status_code, 200)
        challenge.refresh_from_db()
        self.assertEqual(challenge.status, "replaced")
        self.assertNotEqual(first.json()["challenge_id"], second.json()["challenge_id"])

    @patch("rentals.phone_login._provider", return_value=None)
    def test_provider_timeout_fails_closed(self, provider):
        response = self.post("/api/auth/phone/send/", {"phone": "+263771234567", "country": "ZW"})
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("tokens", response.json())
        self.assertEqual(PhoneLoginChallenge.objects.get().status, "unavailable")

    @patch("rentals.phone_login._provider", return_value={"sid": "VE-test", "status": "approved"})
    def test_disabled_account_cannot_login(self, provider):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        sent = self.post("/api/auth/phone/send/", {"phone": "+263771234567", "country": "ZW"})
        result = self.post("/api/auth/phone/check/", {"challenge_id": sent.json()["challenge_id"], "code": "123456"})
        self.assertEqual(result.status_code, 400)
        self.assertNotIn("tokens", result.json())

    @patch("rentals.phone_login._provider", return_value={"sid": "VE-test", "status": "approved"})
    def test_expired_and_duplicate_legacy_numbers_cannot_issue_sessions(self, provider):
        sent = self.post("/api/auth/phone/send/", {"phone": "+263771234567", "country": "ZW"})
        PhoneLoginChallenge.objects.filter(pk=sent.json()["challenge_id"]).update(
            expires_at=timezone.now()-timedelta(seconds=1),
        )
        expired = self.post("/api/auth/phone/check/", {"challenge_id": sent.json()["challenge_id"], "code": "123456"})
        self.assertEqual(expired.status_code, 400)
        self.assertNotIn("tokens", expired.json())

        self.user.phone = "0771234567"
        self.user.save(update_fields=["phone"])
        User.objects.create_user(
            username="duplicate-phone", email="duplicate@example.test", password="A-strong-password-123!",
            phone="+263771234567", phone_verified=True,
        )
        PhoneLoginChallenge.objects.filter(pk=sent.json()["challenge_id"]).update(
            last_sent_at=timezone.now()-timedelta(seconds=31),
        )
        # A duplicate is deliberately treated as ineligible before any session can be issued.
        duplicate_send = self.post("/api/auth/phone/send/", {"phone": "+263771234567", "country": "ZW"})
        challenge = PhoneLoginChallenge.objects.get(pk=duplicate_send.json()["challenge_id"])
        self.assertIsNone(challenge.user)
        result = self.post("/api/auth/phone/check/", {"challenge_id": str(challenge.pk), "code": "123456"})
        self.assertEqual(result.status_code, 400)
        self.assertNotIn("tokens", result.json())
