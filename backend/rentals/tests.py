import json
import tempfile
from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone

from .auth import issue_token_pair
from .ai import parse_search_intent
from .models import (
    Conversation,
    Message,
    Notification,
    Property,
    PropertyComparison,
    PropertySearchSession,
    SavedSearch,
    SavedSearchMatch,
    SavedProperty,
    SecurityAuditEvent,
    JobApplication,
    JobPosting,
    ServiceListing,
    ServiceRequest,
    User,
    Viewing,
    VerificationRequest,
)
from .property_search import normalize_search_requirements
from .views import (
    _notify_property_lifecycle_events,
    _notify_saved_search_matches,
    apply_property_filters,
    normalize_listing_categories,
    normalize_listing_details,
    serialize_property,
)
from .gemini_service import GeminiConfigurationError, GeminiService
from .gemini_service import GeminiServiceError


class ServiceAndJobMarketplaceTests(TestCase):
    def setUp(self):
        self.owner = self.make_user("market-owner", User.Roles.TENANT)
        self.applicant = self.make_user("market-applicant", User.Roles.TENANT)
        self.other = self.make_user("market-other", User.Roles.TENANT)
        self.service_payload = {
            "title": "Plumbing repairs",
            "category": "Home services",
            "description": "Residential plumbing and leak repairs.",
            "location": "Harare",
            "price": "25.00",
            "price_type": "hourly",
        }
        self.job_payload = {
            "title": "Maintenance assistant",
            "category": "Facilities",
            "description": "Support our property maintenance team.",
            "location": "Harare",
            "employment_type": "full_time",
            "compensation": "Negotiable",
        }

    def make_user(self, username, role):
        return User.objects.create_user(
            username=username,
            email=f"{username}@example.test",
            password="test-password",
            role=role,
        )

    def authorize(self, user):
        self.client.defaults["HTTP_AUTHORIZATION"] = (
            f"Bearer {issue_token_pair(user)['access']}"
        )

    def post_json(self, path, payload):
        return self.client.post(
            path,
            data=json.dumps(payload),
            content_type="application/json",
        )

    def create_service(self, owner=None):
        self.authorize(owner or self.owner)
        response = self.post_json("/api/services/", self.service_payload)
        self.assertEqual(response.status_code, 201, response.content)
        return response.json()

    def create_job(self, owner=None):
        self.authorize(owner or self.owner)
        response = self.post_json("/api/jobs/", self.job_payload)
        self.assertEqual(response.status_code, 201, response.content)
        return response.json()

    def test_public_browsing_and_authenticated_role_neutral_create(self):
        response = self.client.get("/api/services/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"], [])
        response = self.client.get("/api/jobs/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"], [])

        response = self.post_json("/api/services/", self.service_payload)
        self.assertEqual(response.status_code, 401)
        self.authorize(self.owner)
        service_response = self.post_json("/api/services/", self.service_payload)
        job_response = self.post_json("/api/jobs/", self.job_payload)
        self.assertEqual(service_response.status_code, 201, service_response.content)
        self.assertEqual(job_response.status_code, 201, job_response.content)
        self.assertEqual(service_response.json()["price_type"], "hourly")
        self.assertEqual(service_response.json()["owner"]["id"], self.owner.id)
        self.assertEqual(service_response.json()["owner_id"], self.owner.id)
        self.assertEqual(job_response.json()["owner_id"], self.owner.id)
        self.assertEqual(len(self.client.get("/api/services/").json()["results"]), 1)
        self.assertEqual(len(self.client.get("/api/jobs/").json()["results"]), 1)

    def test_listing_validation_rejects_missing_and_disallowed_choices(self):
        self.authorize(self.owner)
        response = self.post_json("/api/services/", {"title": "Missing fields"})
        self.assertEqual(response.status_code, 400)
        response = self.post_json("/api/services/", {**self.service_payload, "price_type": "weekly"})
        self.assertEqual(response.status_code, 400)
        response = self.post_json("/api/services/", {**self.service_payload, "price_type": "daily"})
        self.assertEqual(response.status_code, 400)
        response = self.post_json("/api/services/", {**self.service_payload, "price_type": "quote"})
        self.assertEqual(response.status_code, 201, response.content)
        response = self.post_json("/api/jobs/", {**self.job_payload, "employment_type": "volunteer"})
        self.assertEqual(response.status_code, 400)
        response = self.post_json("/api/jobs/", {**self.job_payload, "employment_type": "casual"})
        self.assertEqual(response.status_code, 400)
        response = self.post_json("/api/jobs/", {**self.job_payload, "employment_type": "temporary"})
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(ServiceListing.objects.count(), 1)
        self.assertEqual(JobPosting.objects.count(), 1)
        self.assertEqual(
            set(ServiceListing.PriceType.values),
            {"fixed", "hourly", "quote"},
        )
        self.assertEqual(
            set(JobPosting.EmploymentType.values),
            {"full_time", "part_time", "contract", "temporary"},
        )

    def test_owner_only_listing_update_and_delete(self):
        service = self.create_service()
        job = self.create_job()
        self.authorize(self.other)
        for path in (
            f"/api/services/{service['id']}/",
            f"/api/jobs/{job['id']}/",
        ):
            response = self.client.patch(
                path,
                data=json.dumps({"title": "Hijacked"}),
                content_type="application/json",
            )
            self.assertEqual(response.status_code, 403)
            self.assertEqual(self.client.delete(path).status_code, 403)

        self.authorize(self.owner)
        response = self.client.patch(
            f"/api/services/{service['id']}/",
            data=json.dumps({"title": "Updated plumbing"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["title"], "Updated plumbing")
        service_delete = self.client.delete(f"/api/services/{service['id']}/")
        self.assertEqual(service_delete.status_code, 200)
        self.assertEqual(service_delete.json()["status"], "closed")
        self.assertFalse(ServiceListing.objects.get(pk=service["id"]).is_active)

        response = self.client.put(
            f"/api/jobs/{job['id']}/",
            data=json.dumps({**self.job_payload, "title": "Updated job"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["title"], "Updated job")
        job_delete = self.client.delete(f"/api/jobs/{job['id']}/")
        self.assertEqual(job_delete.status_code, 200)
        self.assertEqual(job_delete.json()["status"], "closed")
        self.assertFalse(JobPosting.objects.get(pk=job["id"]).is_active)
        self.client.defaults.pop("HTTP_AUTHORIZATION", None)
        self.assertEqual(self.client.get("/api/services/").json()["results"], [])
        self.assertEqual(self.client.get("/api/jobs/").json()["results"], [])
        self.assertEqual(self.client.get(f"/api/services/{service['id']}/").status_code, 404)
        self.assertEqual(self.client.get(f"/api/jobs/{job['id']}/").status_code, 404)

    def test_service_requests_and_job_applications_reject_self_and_duplicates(self):
        service = self.create_service()
        job = self.create_job()

        self.authorize(self.owner)
        self.assertEqual(
            self.post_json(
                f"/api/services/{service['id']}/requests/",
                {"message": "Please help"},
            ).status_code,
            400,
        )
        self.assertEqual(
            self.post_json(
                f"/api/jobs/{job['id']}/applications/",
                {"cover_message": "I am interested"},
            ).status_code,
            400,
        )

        self.authorize(self.applicant)
        request_response = self.post_json(
            f"/api/services/{service['id']}/requests/",
            {"message": "Please repair a leak"},
        )
        application_response = self.post_json(
            f"/api/jobs/{job['id']}/applications/",
            {"cover_message": "I have relevant experience"},
        )
        self.assertEqual(request_response.status_code, 201, request_response.content)
        self.assertEqual(application_response.status_code, 201, application_response.content)
        self.assertEqual(request_response.json()["service_id"], service["id"])
        self.assertEqual(request_response.json()["owner_id"], self.owner.id)
        self.assertEqual(request_response.json()["requester"]["id"], self.applicant.id)
        self.assertEqual(request_response.json()["requester_id"], self.applicant.id)
        self.assertEqual(application_response.json()["job_id"], job["id"])
        self.assertEqual(application_response.json()["owner_id"], self.owner.id)
        self.assertEqual(application_response.json()["applicant"]["id"], self.applicant.id)
        self.assertEqual(application_response.json()["applicant_id"], self.applicant.id)
        self.assertEqual(
            self.post_json(
                f"/api/services/{service['id']}/requests/",
                {"message": "Another request"},
            ).status_code,
            409,
        )
        self.assertEqual(
            self.post_json(
                f"/api/jobs/{job['id']}/applications/",
                {"cover_message": "Another application"},
            ).status_code,
            409,
        )
        another_service = ServiceListing.objects.create(
            owner=self.owner,
            title="Painting",
            category="Home services",
            description="Interior painting.",
            location="Harare",
        )
        collection_response = self.post_json(
            "/api/service-requests/",
            {"service_id": another_service.id, "message": "Please paint a room"},
        )
        self.assertEqual(collection_response.status_code, 201, collection_response.content)
        self.assertEqual(ServiceRequest.objects.count(), 2)
        self.assertEqual(JobApplication.objects.count(), 1)

    def test_request_and_application_lists_are_scoped_to_participant_or_owner(self):
        first_service = self.create_service()
        self.authorize(self.other)
        second_service_response = self.post_json("/api/services/", self.service_payload)
        self.assertEqual(second_service_response.status_code, 201)
        first_job = self.create_job(self.owner)
        self.authorize(self.applicant)
        second_job_response = self.post_json("/api/jobs/", self.job_payload)
        self.assertEqual(second_job_response.status_code, 201)

        ServiceRequest.objects.create(
            service_id=first_service["id"],
            requester=self.applicant,
            message="Request to first owner",
        )
        ServiceRequest.objects.create(
            service_id=second_service_response.json()["id"],
            requester=self.other,
            message="Unrelated request",
        )
        JobApplication.objects.create(
            job_id=first_job["id"],
            applicant=self.applicant,
            cover_message="Application to first owner",
        )
        JobApplication.objects.create(
            job_id=second_job_response.json()["id"],
            applicant=self.other,
            cover_message="Unrelated application",
        )

        self.authorize(self.applicant)
        response = self.client.get("/api/service-requests/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()["results"]), 1)
        self.assertEqual(response.json()["results"][0]["message"], "Request to first owner")
        response = self.client.get("/api/job-applications/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()["results"]), 2)
        self.assertEqual(
            {item["cover_message"] for item in response.json()["results"]},
            {"Application to first owner", "Unrelated application"},
        )

        self.authorize(self.owner)
        self.assertEqual(len(self.client.get("/api/service-requests/").json()["results"]), 1)
        self.assertEqual(len(self.client.get("/api/job-applications/").json()["results"]), 1)

    def test_service_request_lifecycle_is_limited_to_allowed_participant_statuses(self):
        service = self.create_service()
        request_from_applicant = ServiceRequest.objects.create(
            service_id=service["id"],
            requester=self.applicant,
            message="First service request",
        )
        request_for_owner = ServiceRequest.objects.create(
            service_id=service["id"],
            requester=self.other,
            message="Second service request",
        )

        path = f"/api/service-requests/{request_from_applicant.id}/"
        self.authorize(self.applicant)
        response = self.client.patch(
            path,
            data=json.dumps({"status": "cancelled"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["status"], "cancelled")
        self.assertEqual(response.json()["service_id"], service["id"])
        self.assertEqual(
            self.client.patch(
                path,
                data=json.dumps({"status": "accepted"}),
                content_type="application/json",
            ).status_code,
            403,
        )

        owner_path = f"/api/service-requests/{request_for_owner.id}/"
        self.authorize(self.owner)
        response = self.client.patch(
            owner_path,
            data=json.dumps({"status": "accepted"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["status"], "accepted")
        self.assertEqual(
            self.client.patch(
                owner_path,
                data=json.dumps({"status": "cancelled"}),
                content_type="application/json",
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.patch(
                owner_path,
                data=json.dumps({"status": "unknown"}),
                content_type="application/json",
            ).status_code,
            400,
        )
        self.assertEqual(
            self.client.patch(owner_path, data="{", content_type="application/json").status_code,
            400,
        )

        self.authorize(self.other)
        self.assertEqual(
            self.client.patch(
                path,
                data=json.dumps({"status": "cancelled"}),
                content_type="application/json",
            ).status_code,
            403,
        )

    def test_job_application_lifecycle_is_limited_to_allowed_participant_statuses(self):
        job = self.create_job()
        application_from_applicant = JobApplication.objects.create(
            job_id=job["id"],
            applicant=self.applicant,
            cover_message="First job application",
        )
        application_for_owner = JobApplication.objects.create(
            job_id=job["id"],
            applicant=self.other,
            cover_message="Second job application",
        )

        path = f"/api/job-applications/{application_from_applicant.id}/"
        self.authorize(self.applicant)
        response = self.client.patch(
            path,
            data=json.dumps({"status": "withdrawn"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["status"], "withdrawn")
        self.assertEqual(response.json()["job_id"], job["id"])
        self.assertEqual(
            self.client.patch(
                path,
                data=json.dumps({"status": "accepted"}),
                content_type="application/json",
            ).status_code,
            403,
        )

        owner_path = f"/api/job-applications/{application_for_owner.id}/"
        self.authorize(self.owner)
        response = self.client.patch(
            owner_path,
            data=json.dumps({"status": "declined"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["status"], "declined")
        self.assertEqual(
            self.client.patch(
                owner_path,
                data=json.dumps({"status": "withdrawn"}),
                content_type="application/json",
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.patch(
                owner_path,
                data=json.dumps({"status": "unknown"}),
                content_type="application/json",
            ).status_code,
            400,
        )
        self.assertEqual(
            self.client.patch(owner_path, data="{", content_type="application/json").status_code,
            400,
        )

        self.authorize(self.other)
        self.assertEqual(
            self.client.patch(
                path,
                data=json.dumps({"status": "withdrawn"}),
                content_type="application/json",
            ).status_code,
            403,
        )


class GoogleSignInConfigTests(TestCase):
    def test_password_login_does_not_require_an_account_type(self):
        user = User.objects.create_user(
            username="role-neutral-login",
            email="role-neutral-login@example.test",
            password="A-strong-password-123!",
            role=User.Roles.LANDLORD,
        )
        response = self.client.post(
            "/api/auth/login/",
            data=json.dumps(
                {
                    "username": user.email,
                    "password": "A-strong-password-123!",
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["account"]["account_type"], User.Roles.LANDLORD)

    def test_google_sign_in_keeps_existing_account_role(self):
        user = User.objects.create_user(
            username="existing-google-user",
            email="existing-google@example.test",
            password="A-strong-password-123!",
            role=User.Roles.TENANT,
        )
        claims = {
            "sub": "google-subject-existing-user",
            "email": user.email,
            "email_verified": True,
            "name": "Existing Google User",
            "picture": "",
        }
        with patch("rentals.views.verify_google_id_token", return_value=claims):
            response = self.client.post(
                "/api/auth/google/",
                data=json.dumps(
                    {
                        "id_token": "valid-test-token",
                        "account_type": User.Roles.LANDLORD,
                    }
                ),
                content_type="application/json",
            )

        self.assertEqual(response.status_code, 200, response.content)
        user.refresh_from_db()
        self.assertEqual(user.role, User.Roles.TENANT)
        self.assertEqual(response.json()["account"]["account_type"], User.Roles.TENANT)

    def test_public_config_returns_first_allowed_google_client_id(self):
        from django.test import override_settings

        with override_settings(
            GOOGLE_SIGN_IN_ENABLED=True,
            GOOGLE_CLIENT_IDS=[
                "web-client.apps.googleusercontent.com",
                "mobile-client.apps.googleusercontent.com",
            ],
        ):
            response = self.client.get("/api/auth/google/config/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"client_id": "web-client.apps.googleusercontent.com"},
        )

    def test_public_config_does_not_return_client_id_when_disabled(self):
        from django.test import override_settings

        with override_settings(
            GOOGLE_SIGN_IN_ENABLED=False,
            GOOGLE_CLIENT_IDS=["web-client.apps.googleusercontent.com"],
        ):
            response = self.client.get("/api/auth/google/config/")

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json(),
            {"error": "Google sign-in is not configured"},
        )


class MarketplaceCapabilityTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="capability-member",
            email="capability-member@example.test",
            password="A-strong-password-123!",
            role=User.Roles.TENANT,
            marketplace_capabilities=["list_properties"],
        )
        self.authorization = "Bearer " + issue_token_pair(self.user)["access"]
        self.client.defaults["HTTP_AUTHORIZATION"] = self.authorization
        self.listing_payload = {
            "title": "My mixed-use lodge",
            "address": "1 Lake Road",
            "city": "Harare",
            "suburb": "Lake Chivero",
            "monthly_rent": "80",
            "deposit_required": "0",
            "property_type": "lodge",
            "listing_categories": ["stays", "venues"],
        }

    def test_member_can_create_and_manage_listing_without_landlord_role(self):
        response = self.client.post(
            "/api/properties/",
            data=json.dumps(self.listing_payload),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.json()["owner"]["id"], self.user.id)
        self.assertEqual(response.json()["listing_categories"], ["stays", "venues"])

        own_listings = self.client.get("/api/properties/").json()["results"]
        self.assertEqual([item["id"] for item in own_listings], [response.json()["id"]])

    def test_listing_capability_keeps_public_browsing_and_own_drafts_available(self):
        public_owner = User.objects.create_user(
            username="public-listing-owner",
            email="public-listing-owner@example.test",
            password="A secure password 2026!",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        public_property = Property.objects.create(
            owner=public_owner,
            title="Public rental",
            address="2 Lake Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("600.00"),
            deposit_required=Decimal("600.00"),
            property_type=Property.PropertyType.HOUSE,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        own_property = Property.objects.create(
            owner=self.user,
            title="My draft",
            address="3 Lake Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("700.00"),
            deposit_required=Decimal("700.00"),
            property_type=Property.PropertyType.HOUSE,
            listing_status=Property.ListingStatus.PENDING_VERIFICATION,
        )

        response = self.client.get("/api/properties/")

        self.assertEqual(response.status_code, 200)
        ids = {item["id"] for item in response.json()["results"]}
        self.assertEqual(ids, {public_property.id, own_property.id})

    def test_property_listing_capability_can_be_enabled_from_account(self):
        self.user.marketplace_capabilities = []
        self.user.save(update_fields=["marketplace_capabilities"])
        response = self.client.patch(
            "/api/auth/profile/",
            data=json.dumps({"marketplace_capabilities": ["list_properties"]}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.assertIn("list_properties", response.json()["account"]["capabilities"])
        self.user.refresh_from_db()
        self.assertEqual(self.user.marketplace_capabilities, ["list_properties"])

    def test_property_listing_is_denied_until_capability_is_enabled(self):
        self.user.marketplace_capabilities = []
        self.user.save(update_fields=["marketplace_capabilities"])
        response = self.client.post(
            "/api/properties/",
            data=json.dumps(self.listing_payload),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 403)
        self.assertIn("Enable property listings", response.json()["error"])

    def test_landlord_can_save_searches_and_compare_listings(self):
        owner = User.objects.create_user(
            username="marketplace-owner",
            email="marketplace-owner@example.test",
            password="A secure password 2026!",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        prop = Property.objects.create(
            owner=owner,
            title="Verified rental",
            address="2 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("500.00"),
            deposit_required=Decimal("500.00"),
            property_type=Property.PropertyType.HOUSE,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        landlord = User.objects.create_user(
            username="marketplace-landlord",
            email="marketplace-landlord@example.test",
            password="Another secure password 2026!",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.client.defaults["HTTP_AUTHORIZATION"] = (
            "Bearer " + issue_token_pair(landlord)["access"]
        )

        saved_search = self.client.post(
            "/api/tenant/saved-searches/",
            data=json.dumps({
                "query": "rental homes in Harare",
                "criteria": {"location": "Harare"},
            }),
            content_type="application/json",
        )
        self.assertEqual(saved_search.status_code, 201, saved_search.content)
        self.assertEqual(
            self.client.get("/api/tenant/saved-searches/").json()["results"][0]["id"],
            saved_search.json()["id"],
        )

        comparison = self.client.post(
            "/api/tenant/comparisons/",
            data=json.dumps({"property_id": prop.id}),
            content_type="application/json",
        )
        self.assertEqual(comparison.status_code, 200, comparison.content)
        self.assertEqual(
            self.client.get("/api/tenant/comparisons/").json()["results"][0]["id"],
            prop.id,
        )


class SupportAdminTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="support-admin",
            email="support@example.test",
            password="a-long-support-password-123",
            role=User.Roles.ADMIN,
        )
        self.tenant = User.objects.create_user(
            username="support-tenant",
            email="tenant@example.test",
            password="a-long-tenant-password-123",
            role=User.Roles.TENANT,
        )
        self.admin_authorization = (
            f"Bearer {issue_token_pair(self.admin)['access']}"
        )

    def test_provisioned_support_account_is_not_a_django_superuser(self):
        password = "7-Wayland!PrivateSupport2026"
        with (
            patch(
                "builtins.input",
                side_effect=[
                    "private-support",
                    "private-support@example.test",
                    "Support Operator",
                ],
            ),
            patch(
                "rentals.management.commands.create_support_admin.getpass",
                side_effect=[password, password],
            ),
        ):
            call_command("create_support_admin")

        support_user = User.objects.get(username="private-support")
        self.assertEqual(support_user.role, User.Roles.ADMIN)
        self.assertFalse(support_user.is_staff)
        self.assertFalse(support_user.is_superuser)

    def test_admin_dashboard_is_admin_only_and_returns_aggregate_counts(self):
        response = self.client.get("/api/admin/dashboard/")
        self.assertEqual(response.status_code, 401)

        self.client.defaults["HTTP_AUTHORIZATION"] = (
            f"Bearer {issue_token_pair(self.tenant)['access']}"
        )
        response = self.client.get("/api/admin/dashboard/")
        self.assertEqual(response.status_code, 403)

        self.client.defaults["HTTP_AUTHORIZATION"] = self.admin_authorization
        response = self.client.get("/api/admin/dashboard/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["users"]["total"], 1)
        self.assertEqual(response.json()["users"]["active"], 1)

    def test_admin_can_list_and_deactivate_accounts_without_erasing_them(self):
        self.client.defaults["HTTP_AUTHORIZATION"] = self.admin_authorization
        response = self.client.get("/api/users/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual([user["id"] for user in response.json()["results"]], [self.tenant.id])

        response = self.client.post(
            "/api/users/",
            data=json.dumps({"email": "new@example.test", "password": "password"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 405)

        response = self.client.delete(f"/api/users/{self.tenant.id}/")
        self.assertEqual(response.status_code, 200)
        self.tenant.refresh_from_db()
        self.assertFalse(self.tenant.is_active)

    def test_verification_queue_is_limited_to_unreviewed_failed_landlord_checks(self):
        landlord = User.objects.create_user(
            username="failed-landlord",
            email="failed-landlord@example.test",
            password="password",
            role=User.Roles.LANDLORD,
        )
        landlord_failure = VerificationRequest.objects.create(
            user=landlord,
            role=User.Roles.LANDLORD,
            status=VerificationRequest.Status.FAILED,
            failure_reason="Document could not be matched",
        )
        VerificationRequest.objects.create(
            user=self.tenant,
            role=User.Roles.TENANT,
            status=VerificationRequest.Status.FAILED,
        )
        VerificationRequest.objects.create(
            user=landlord,
            role=User.Roles.LANDLORD,
            status=VerificationRequest.Status.MANUAL_REVIEW,
        )

        self.client.defaults["HTTP_AUTHORIZATION"] = self.admin_authorization
        response = self.client.get("/api/verifications/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual([item["id"] for item in response.json()["results"]], [str(landlord_failure.public_id)])

    def test_failed_landlord_documents_require_admin_and_are_audited(self):
        landlord = User.objects.create_user(
            username="document-landlord",
            email="document-landlord@example.test",
            password="password",
            role=User.Roles.LANDLORD,
        )
        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(
                MEDIA_ROOT=media_root,
                STORAGES={
                    "default": {
                        "BACKEND": "django.core.files.storage.FileSystemStorage"
                    },
                    "staticfiles": {
                        "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"
                    },
                },
            ):
                verification = VerificationRequest.objects.create(
                    user=landlord,
                    role=User.Roles.LANDLORD,
                    status=VerificationRequest.Status.FAILED,
                    id_front_document=SimpleUploadedFile(
                        "id-front.png",
                        b"private-document-preview",
                        content_type="image/png",
                    ),
                )
                path = (
                    f"/api/verifications/{verification.public_id}/"
                    "documents/id-front/"
                )
                self.client.defaults["HTTP_AUTHORIZATION"] = self.admin_authorization
                response = self.client.get(path)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response["Cache-Control"], "private, no-store")
                self.assertEqual(
                    b"".join(response.streaming_content),
                    b"private-document-preview",
                )
                self.assertTrue(
                    SecurityAuditEvent.objects.filter(
                        actor=self.admin,
                        event_type="identity_document_admin_previewed",
                    ).exists()
                )

                self.client.defaults["HTTP_AUTHORIZATION"] = (
                    f"Bearer {issue_token_pair(self.tenant)['access']}"
                )
                denied = self.client.get(path)
                self.assertEqual(denied.status_code, 403)

    def test_admin_cannot_read_private_chat_messages(self):
        conversation = Conversation.objects.create(title="Private support test")
        conversation.participants.add(self.tenant)
        self.client.defaults["HTTP_AUTHORIZATION"] = self.admin_authorization

        self.assertEqual(
            self.client.get("/api/conversations/").status_code,
            403,
        )
        self.assertEqual(
            self.client.get(
                f"/api/conversations/{conversation.id}/messages/"
            ).status_code,
            403,
        )

    def test_admin_cannot_access_unrelated_app_management_endpoints(self):
        self.client.defaults["HTTP_AUTHORIZATION"] = self.admin_authorization
        for path in (
            "/api/applications/",
            "/api/viewings/",
            "/api/reports/",
            "/api/media/",
        ):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 403)

    def test_admin_role_cannot_be_created_through_public_registration(self):
        response = self.client.post(
            "/api/auth/register/",
            data=json.dumps(
                {
                    "account_type": "admin",
                    "username": "public-admin@example.test",
                    "email": "public-admin@example.test",
                    "password": "a-long-public-password-123",
                }
            ),
            content_type="application/json",
        )
        self.assertNotEqual(response.status_code, 201)
        self.assertFalse(
            User.objects.filter(username="public-admin@example.test").exists()
        )


class PropertyAvailabilityTests(TestCase):
    def setUp(self):
        self.landlord = User.objects.create_user(
            username="availability-landlord",
            password="not-a-real-password",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.tenant = User.objects.create_user(
            username="availability-tenant",
            password="not-a-real-password",
            role=User.Roles.TENANT,
        )
        self.tenant_authorization = f"Bearer {issue_token_pair(self.tenant)['access']}"
        self.property = Property.objects.create(
            owner=self.landlord,
            title="Available rental",
            address="1 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("500.00"),
            deposit_required=Decimal("500.00"),
            property_type=Property.PropertyType.HOUSE,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        self.client.defaults["HTTP_AUTHORIZATION"] = (
            f"Bearer {issue_token_pair(self.landlord)['access']}"
        )

    def test_property_view_endpoint_increments_and_returns_view_count(self):
        response = self.client.post(f"/api/properties/{self.property.id}/view/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["views_count"], 1)
        self.property.refresh_from_db()
        self.assertEqual(self.property.views_count, 1)

    def test_future_availability_is_returned_with_a_date_label(self):
        available_from = timezone.localdate() + timedelta(days=30)

        response = self.client.post(
            f"/api/properties/{self.property.id}/availability/",
            data=json.dumps(
                {
                    "action": "available_from",
                    "available_from": available_from.isoformat(),
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["available_from"], available_from.isoformat())
        self.assertEqual(
            response.json()["availability_label"],
            f"Available from {available_from.day} {available_from.strftime('%b')}",
        )

    def test_rented_property_is_removed_from_public_search(self):
        response = self.client.post(
            f"/api/properties/{self.property.id}/availability/",
            data=json.dumps({"action": "rented"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["availability_label"], "Rented")
        public_response = self.client.get(
            "/api/properties/",
            HTTP_AUTHORIZATION=f"Bearer {issue_token_pair(self.tenant)['access']}",
        )
        self.assertEqual(public_response.status_code, 200)
        self.assertEqual(public_response.json()["results"], [])
        self.property.refresh_from_db()
        self.assertEqual(self.property.availability_status, Property.AvailabilityStatus.RENTED)

    def test_available_from_requires_a_valid_date(self):
        response = self.client.post(
            f"/api/properties/{self.property.id}/availability/",
            data=json.dumps({"action": "available_from", "available_from": "soon"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)

    @patch("rentals.views.send_push_to_users")
    def test_back_on_market_notifies_tenants_and_sends_push(self, send_push):
        self.property.availability_status = Property.AvailabilityStatus.RENTED
        self.property.save(update_fields=["availability_status"])

        response = self.client.post(
            f"/api/properties/{self.property.id}/availability/",
            data=json.dumps({"action": "available"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        notification = Notification.objects.get(
            user=self.tenant,
            kind="property.back_on_market",
        )
        self.assertEqual(notification.payload["property_id"], str(self.property.id))
        send_push.assert_called_once()
        self.assertIn(self.tenant.id, send_push.call_args.args[0])

    @patch("rentals.views.send_push_to_users")
    def test_price_reduction_notifies_tenants_and_sends_push(self, send_push):
        SavedProperty.objects.create(property=self.property, tenant=self.tenant)
        other_tenant = User.objects.create_user(
            username="availability-other-tenant",
            password="test-password-123",
            role=User.Roles.TENANT,
        )

        response = self.client.patch(
            f"/api/properties/{self.property.id}/",
            data=json.dumps({"monthly_rent": "450.00"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        notification = Notification.objects.get(
            user=self.tenant,
            kind="property.price_reduced",
        )
        self.assertEqual(
            notification.message,
            "Price dropped! Available rental you saved has dropped from $500 to $450.",
        )
        self.assertFalse(
            Notification.objects.filter(
                user=other_tenant,
                kind="property.price_reduced",
            ).exists()
        )
        send_push.assert_called_once()
        self.assertEqual(send_push.call_args.args[0], [self.tenant.id])
        self.assertEqual(send_push.call_args.kwargs["data"]["old_price"], "500")
        self.assertEqual(send_push.call_args.kwargs["data"]["new_price"], "450")

    @patch("rentals.views.send_push_to_users")
    def test_price_reduction_notifies_matching_saved_search_tenants(self, send_push):
        search_tenant = User.objects.create_user(
            username="availability-search-tenant",
            password="test-password-123",
            role=User.Roles.TENANT,
        )
        SavedSearch.objects.create(
            tenant=search_tenant,
            name="Affordable Avondale homes",
            query="Avondale under $475",
            criteria={
                "mode": "structured",
                "locations": ["Avondale"],
                "max_price": "475",
                "listing_intent": "rent",
            },
        )

        response = self.client.patch(
            f"/api/properties/{self.property.id}/",
            data=json.dumps({"monthly_rent": "450.00"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        notification = Notification.objects.get(
            user=search_tenant,
            kind="property.price_reduced",
        )
        self.assertIn("matches your saved search", notification.message)
        self.assertEqual(notification.payload["new_price"], "450")
        self.assertFalse(
            Notification.objects.filter(
                user=search_tenant,
                kind="saved_search.match",
            ).exists()
        )
        self.assertEqual(send_push.call_args.args[0], [search_tenant.id])

    def test_tenant_can_get_similar_listings_and_compare_up_to_three(self):
        similar = Property.objects.create(
            owner=self.landlord,
            title="Similar rental",
            address="3 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("450.00"),
            deposit_required=Decimal("450.00"),
            property_type=Property.PropertyType.HOUSE,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        suggestions = self.client.get(
            f"/api/properties/{self.property.id}/comparison-suggestions/",
            HTTP_AUTHORIZATION=self.tenant_authorization,
        )
        self.assertEqual(suggestions.status_code, 200, suggestions.content)
        self.assertIn(
            str(similar.id),
            [str(item["property"]["id"]) for item in suggestions.json()["results"]],
        )

        for property_id in (self.property.id, similar.id):
            response = self.client.post(
                "/api/tenant/comparisons/",
                data=json.dumps({"property_id": property_id}),
                content_type="application/json",
                HTTP_AUTHORIZATION=self.tenant_authorization,
            )
            self.assertEqual(response.status_code, 200)
        comparison = self.client.get(
            "/api/tenant/comparisons/",
            HTTP_AUTHORIZATION=self.tenant_authorization,
        )
        self.assertEqual(len(comparison.json()["results"]), 2)
        self.assertEqual(
            PropertyComparison.objects.filter(tenant=self.tenant).count(),
            2,
        )

    @patch("rentals.views.send_push_to_users")
    def test_newly_published_listing_notifies_tenants(self, send_push):
        self.property.listing_status = Property.ListingStatus.PENDING_VERIFICATION
        self.property.save(update_fields=["listing_status"])
        previous_state = {
            "availability_status": Property.AvailabilityStatus.AVAILABLE,
            "monthly_rent": self.property.monthly_rent,
            "is_live": False,
        }
        self.property.listing_status = Property.ListingStatus.VERIFIED
        _notify_property_lifecycle_events(self.property, previous_state)

        notification = Notification.objects.get(
            user=self.tenant,
            kind="property.new_listing",
        )
        self.assertEqual(notification.payload["property_id"], str(self.property.id))
        send_push.assert_called_once()

class StudentAndCommercialListingTests(TestCase):
    def setUp(self):
        self.landlord = User.objects.create_user(
            username="student-housing-landlord",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.student_listing = Property.objects.create(
            owner=self.landlord,
            title="Shared room near campus",
            address="1 Campus Road",
            city="Bulawayo",
            suburb="North End",
            monthly_rent=Decimal("180.00"),
            deposit_required=Decimal("180.00"),
            property_type=Property.PropertyType.STUDENT,
            accommodation_institution="National University of Science and Technology",
            shared_room=True,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        self.office_listing = Property.objects.create(
            owner=self.landlord,
            title="Office suite",
            address="2 Business Road",
            city="Bulawayo",
            suburb="CBD",
            monthly_rent=Decimal("500.00"),
            deposit_required=Decimal("500.00"),
            property_type=Property.PropertyType.OFFICE,
        )

    def test_student_filters_match_institution_shared_room_and_verified_owner(self):
        matches = apply_property_filters(
            Property.objects.all(),
            {
                "student_only": "true",
                "institution": "National University of Science and Technology",
                "shared_room": "true",
                "verified_only": "true",
            },
        )

        self.assertEqual(list(matches), [self.student_listing])

    def test_student_listing_serializes_institution_and_shared_room_fields(self):
        payload = serialize_property(self.student_listing)

        self.assertEqual(
            payload["accommodation_institution"],
            "National University of Science and Technology",
        )
        self.assertTrue(payload["shared_room"])

    def test_office_shop_and_room_categories_are_available(self):
        self.assertIn("office", Property.PropertyType.values)
        self.assertIn("shop", Property.PropertyType.values)
        self.assertIn("room", Property.PropertyType.values)
        offices = apply_property_filters(
            Property.objects.all(),
            {"property_type": "office"},
        )
        self.assertEqual(list(offices), [self.office_listing])

    def test_ai_search_accepts_rooms_as_a_property_type(self):
        requirements = normalize_search_requirements(
            {
                "listing_intent": "rent",
                "property_type": "room",
                "locations": [],
                "flexibility": {},
            },
            "room for rent",
        )

        self.assertEqual(requirements["property_type"], "room")


class StayVenueListingTests(TestCase):
    def setUp(self):
        self.landlord = User.objects.create_user(
            username="stay-venue-landlord",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.authorization = f"Bearer {issue_token_pair(self.landlord)['access']}"

    def test_lodging_types_and_venue_types_are_available(self):
        self.assertIn("lodge", Property.PropertyType.values)
        self.assertIn("hotel", Property.PropertyType.values)
        self.assertIn("wedding_venue", Property.PropertyType.values)
        self.assertIn("corporate_event_space", Property.PropertyType.values)

    def test_ai_search_recognizes_stay_and_venue_listing_types(self):
        self.assertEqual(
            parse_search_intent("Find a lodge in Harare")["property_type"],
            "lodge",
        )
        self.assertEqual(
            parse_search_intent("Self catering apartment near Bulawayo")[
                "property_type"
            ],
            "self_catering_apartment",
        )

    def test_listing_categories_allow_a_property_to_be_a_stay_and_venue(self):
        self.assertEqual(
            normalize_listing_categories(["stays", "venues", "stays"]),
            ["stays", "venues"],
        )

    def test_listing_details_normalize_rates_capacity_and_features(self):
        details = normalize_listing_details({
            "nightly_rate": "80",
            "event_rate": "1200",
            "room_types": ["2 x Standard rooms", "Family cottage"],
            "amenities": ["Wi-Fi", "Swimming pool"],
            "activities": ["Game drives", "Hiking"],
            "venue_features": ["Outdoor venue"],
            "max_guests": "6",
            "wedding_capacity": "150",
            "conference_capacity": "80",
            "catering_available": True,
            "guest_accommodation": True,
        })

        self.assertEqual(details["nightly_rate"], "80")
        self.assertEqual(details["event_rate"], "1200")
        self.assertEqual(details["max_guests"], 6)
        self.assertEqual(details["wedding_capacity"], 150)
        self.assertEqual(details["conference_capacity"], 80)
        self.assertEqual(details["amenities"], ["Wi-Fi", "Swimming pool"])
        self.assertTrue(details["catering_available"])

    def test_landlord_can_create_a_lodge_for_stays_and_venues(self):
        response = self.client.post(
            "/api/properties/",
            data=json.dumps({
                "title": "Lakeview Lodge",
                "address": "1 Lake Road",
                "city": "Harare",
                "suburb": "Lake Chivero",
                "monthly_rent": "80",
                "deposit_required": "0",
                "property_type": "lodge",
                "listing_categories": ["stays", "venues"],
                "listing_details": {
                    "nightly_rate": "80",
                    "event_rate": "1200",
                    "room_types": ["2 x Standard rooms", "Family cottage"],
                    "amenities": ["Wi-Fi", "Swimming pool"],
                    "activities": ["Game drives", "Fishing"],
                    "venue_features": ["Outdoor venue"],
                    "max_guests": 6,
                    "wedding_capacity": 150,
                    "conference_capacity": 80,
                    "catering_available": True,
                    "guest_accommodation": True,
                },
            }),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.authorization,
        )

        self.assertEqual(response.status_code, 201, response.content)
        payload = response.json()
        self.assertEqual(payload["listing_categories"], ["stays", "venues"])
        self.assertEqual(payload["listing_details"]["nightly_rate"], "80")
        self.assertEqual(payload["listing_details"]["wedding_capacity"], 150)

    def test_invalid_categories_and_capacities_are_rejected(self):
        with self.assertRaises(ValueError):
            normalize_listing_categories(["stays", "unknown"])
        with self.assertRaises(ValueError):
            normalize_listing_details({"max_guests": "-1"})


class SavedSearchAlertTests(TestCase):
    def setUp(self):
        self.landlord = User.objects.create_user(
            username="saved-search-landlord",
            password="test-password",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.tenant = User.objects.create_user(
            username="saved-search-tenant",
            password="test-password",
            role=User.Roles.TENANT,
        )
        self.property = Property.objects.create(
            owner=self.landlord,
            title="Harare family home",
            address="1 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("450.00"),
            deposit_required=Decimal("450.00"),
            property_type=Property.PropertyType.HOUSE,
            bedrooms=2,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        self.authorization = f"Bearer {issue_token_pair(self.tenant)['access']}"

    @patch("rentals.views.send_push_to_users")
    def test_matching_listing_creates_one_in_app_and_push_alert(self, send_push):
        search = SavedSearch.objects.create(
            tenant=self.tenant,
            name="Two bedroom in Harare",
            query="2 bedroom in Harare under $500",
            criteria={
                "mode": "structured",
                "location": "Harare",
                "bedrooms_min": 2,
                "rent_max": "500",
                "property_type": Property.PropertyType.HOUSE,
                "intent": Property.ListingIntent.RENT,
            },
        )

        _notify_saved_search_matches(self.property)
        _notify_saved_search_matches(self.property)

        self.assertEqual(SavedSearchMatch.objects.filter(saved_search=search).count(), 1)
        notification = Notification.objects.get(
            user=self.tenant,
            kind="saved_search.match",
        )
        self.assertEqual(notification.payload["property_id"], str(self.property.id))
        self.assertIn(search.name, notification.message)
        send_push.assert_called_once()
        self.assertEqual(send_push.call_args.args[0], [self.tenant.id])

    @patch("rentals.views.send_push_to_users")
    def test_inactive_or_non_matching_search_does_not_alert(self, send_push):
        SavedSearch.objects.create(
            tenant=self.tenant,
            name="Inactive",
            query="Harare houses",
            is_active=False,
            criteria={
                "mode": "structured",
                "location": "Harare",
                "intent": Property.ListingIntent.RENT,
            },
        )
        SavedSearch.objects.create(
            tenant=self.tenant,
            name="Too expensive",
            query="Harare under $300",
            criteria={
                "mode": "structured",
                "location": "Harare",
                "rent_max": "300",
                "intent": Property.ListingIntent.RENT,
            },
        )

        _notify_saved_search_matches(self.property)

        self.assertFalse(
            Notification.objects.filter(user=self.tenant, kind="saved_search.match").exists()
        )
        send_push.assert_not_called()

    def test_tenant_can_create_structured_search_and_invalid_criteria_are_rejected(self):
        response = self.client.post(
            "/api/tenant/saved-searches/",
            data=json.dumps(
                {
                    "name": "Avondale homes",
                    "query": "Homes in Avondale with at least 2 bedrooms",
                    "criteria": {
                        "location": "Avondale",
                        "bedrooms_min": 2,
                        "intent": "rent",
                    },
                }
            ),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.authorization,
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.json()["criteria"]["location"], "Avondale")
        self.assertEqual(response.json()["match_count"], 1)

        invalid_response = self.client.post(
            "/api/tenant/saved-searches/",
            data=json.dumps(
                {
                    "query": "Impossible budget",
                    "criteria": {
                        "rent_min": 500,
                        "rent_max": 300,
                    },
                }
            ),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.authorization,
        )
        self.assertEqual(invalid_response.status_code, 400)

    @patch("rentals.views.send_push_to_users")
    def test_saved_search_stores_hard_amenities_and_alerts_only_matching_listings(
        self,
        send_push,
    ):
        response = self.client.post(
            "/api/tenant/saved-searches/",
            data=json.dumps(
                {
                    "name": "Avondale solar homes",
                    "query": "Avondale homes that must have solar",
                    "criteria": {
                        "locations": ["Avondale"],
                        "property_type": "house",
                        "max_price": "500",
                        "required_amenities": ["solar_power"],
                        "preferred_amenities": [],
                        "listing_intent": "rent",
                    },
                }
            ),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.authorization,
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(
            response.json()["criteria"]["required_amenities"],
            ["solar_power"],
        )

        new_property = Property.objects.create(
            owner=self.landlord,
            title="New Avondale solar home",
            address="5 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("480"),
            deposit_required=Decimal("480"),
            property_type=Property.PropertyType.HOUSE,
            bedrooms=2,
            listing_status=Property.ListingStatus.VERIFIED,
            solar_power=True,
        )
        _notify_saved_search_matches(new_property)

        notification = Notification.objects.get(
            user=self.tenant,
            kind="saved_search.match",
        )
        self.assertEqual(notification.payload["property_id"], str(new_property.id))
        send_push.assert_called_once()


class AiPropertySearchTests(TestCase):
    def setUp(self):
        self.landlord = User.objects.create_user(
            username="ai-search-landlord",
            password="test-password",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.property = Property.objects.create(
            owner=self.landlord,
            title="Avondale family home",
            address="1 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("450"),
            deposit_required=Decimal("450"),
            property_type=Property.PropertyType.HOUSE,
            bedrooms=2,
            listing_status=Property.ListingStatus.VERIFIED,
            solar_power=True,
        )
        self.requirements = {
            "listing_intent": "rent",
            "property_type": "house",
            "locations": ["Avondale"],
            "min_bedrooms": 2,
            "max_bedrooms": None,
            "min_price": None,
            "max_price": "500",
            "currency": "USD",
            "move_in_date": "",
            "required_amenities": [],
            "preferred_amenities": ["solar_power"],
            "required_keywords": [],
            "keywords": [],
            "flexibility": {
                "budget": False,
                "location": False,
                "bedrooms": False,
                "property_type": False,
            },
            "clarification_question": "",
        }

    @patch.object(GeminiService, "parse_property_search")
    def test_search_ranks_real_listings_and_enforces_explicit_hard_features(
        self,
        parse_search,
    ):
        close_match = Property.objects.create(
            owner=self.landlord,
            title="Avondale home without solar",
            address="2 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("400"),
            deposit_required=Decimal("400"),
            property_type=Property.PropertyType.HOUSE,
            bedrooms=2,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        rented = Property.objects.create(
            owner=self.landlord,
            title="Rented Avondale home",
            address="3 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("350"),
            deposit_required=Decimal("350"),
            property_type=Property.PropertyType.HOUSE,
            bedrooms=2,
            listing_status=Property.ListingStatus.VERIFIED,
            availability_status=Property.AvailabilityStatus.RENTED,
        )
        parse_search.return_value = {
            **self.requirements,
            "required_amenities": [],
            "preferred_amenities": ["solar_power"],
        }

        response = self.client.post(
            "/api/ai/property-search/",
            data=json.dumps({"query": "I need solar in Avondale under $500"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200, response.content)
        payload = response.json()
        self.assertEqual(payload["parser"], "gemini")
        self.assertEqual(payload["exact_matches"], 1)
        self.assertEqual(payload["close_matches"], 1)
        self.assertEqual(
            payload["interpreted_requirements"]["required_amenities"],
            ["solar_power"],
        )
        self.assertEqual(payload["results"][0]["match_type"], "exact")
        result_ids = {item["property_id"] for item in payload["results"]}
        self.assertEqual(result_ids, {str(self.property.id), str(close_match.id)})
        self.assertNotIn(str(rented.id), result_ids)
        self.assertTrue(payload["session_id"])
        self.assertTrue(
            PropertySearchSession.objects.filter(
                pk=payload["session_id"],
                requirements=payload["interpreted_requirements"],
            ).exists()
        )

    @patch.object(GeminiService, "parse_property_search")
    def test_refinement_sends_previous_requirements_and_persists_session(
        self,
        parse_search,
    ):
        refined = {
            **self.requirements,
            "max_price": "600",
            "locations": ["Waterfalls"],
        }
        parse_search.side_effect = [self.requirements, refined]
        first = self.client.post(
            "/api/ai/property-search/",
            data=json.dumps({"query": "Two bedroom house in Avondale under $500"}),
            content_type="application/json",
        )
        session_id = first.json()["session_id"]
        second = self.client.post(
            "/api/ai/property-search/",
            data=json.dumps(
                {
                    "query": "Try Waterfalls and I can go up to $600",
                    "session_id": session_id,
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(second.status_code, 200, second.content)
        self.assertEqual(parse_search.call_args_list[1].kwargs["previous_requirements"], self.requirements)
        session = PropertySearchSession.objects.get(pk=session_id)
        self.assertEqual(session.original_query, "Two bedroom house in Avondale under $500")
        self.assertEqual(session.requirements["max_price"], "600")
        self.assertEqual(session.requirements["locations"], ["Waterfalls"])
        self.assertEqual(len(session.modifications), 1)

    @patch("rentals.views.GeminiService.parse_property_search")
    def test_missing_gemini_key_uses_local_search_parser(self, parse_search):
        from django.test import override_settings

        parse_search.side_effect = GeminiConfigurationError(
            "GEMINI_API_KEY is not configured"
        )
        with override_settings(GEMINI_API_KEY=""):
            response = self.client.post(
                "/api/ai/property-search/",
                data=json.dumps({"query": "A house in Avondale under $500"}),
                content_type="application/json",
            )

        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["parser"], "local")

    @patch("rentals.gemini_service.request.urlopen")
    def test_gemini_service_uses_server_side_key_and_json_schema(self, urlopen):
        from django.test import override_settings
        from unittest.mock import MagicMock
        from .gemini_service import GeminiService

        response = MagicMock()
        response.read.return_value = json.dumps(
            {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": json.dumps(self.requirements),
                                }
                            ]
                        }
                    }
                ]
            }
        ).encode()
        urlopen.return_value.__enter__.return_value = response
        with override_settings(
            GEMINI_API_KEY="test-key",
            GEMINI_MODEL="gemini-test-model",
            GEMINI_TIMEOUT_SECONDS=3,
        ):
            parsed = GeminiService.parse_property_search("a house in Avondale")

        self.assertEqual(parsed["property_type"], "house")
        req = urlopen.call_args.args[0]
        self.assertNotIn("test-key", req.full_url)
        self.assertEqual(req.get_header("X-goog-api-key"), "test-key")
        request_body = json.loads(req.data)
        self.assertEqual(
            request_body["generationConfig"]["responseMimeType"],
            "application/json",
        )
        self.assertIn(
            "required_amenities",
            request_body["generationConfig"]["responseSchema"]["properties"],
        )
        self.assertEqual(urlopen.call_args.kwargs["timeout"], 3)

    @patch("rentals.gemini_service.request.urlopen")
    def test_gemini_transport_failures_are_reported_without_fallback(self, urlopen):
        from urllib.error import URLError
        from django.test import override_settings

        urlopen.side_effect = URLError("network unavailable")
        with override_settings(GEMINI_API_KEY="test-key"):
            with self.assertRaises(GeminiServiceError):
                GeminiService.parse_property_search("a house in Avondale")


class ViewingRequestTests(TestCase):
    def setUp(self):
        self.landlord = User.objects.create_user(
            username="viewing-landlord",
            password="not-a-real-password",
            role=User.Roles.LANDLORD,
            is_verified=True,
        )
        self.tenant = User.objects.create_user(
            username="viewing-tenant",
            password="not-a-real-password",
            role=User.Roles.TENANT,
        )
        self.property = Property.objects.create(
            owner=self.landlord,
            title="Viewing rental",
            address="2 Example Road",
            city="Harare",
            suburb="Avondale",
            monthly_rent=Decimal("600.00"),
            deposit_required=Decimal("600.00"),
            property_type=Property.PropertyType.HOUSE,
            listing_status=Property.ListingStatus.VERIFIED,
        )
        self.tenant_authorization = (
            f"Bearer {issue_token_pair(self.tenant)['access']}"
        )
        self.landlord_authorization = (
            f"Bearer {issue_token_pair(self.landlord)['access']}"
        )

    def _request_viewing(self):
        return self.client.post(
            "/api/viewings/",
            data=json.dumps(
                {
                    "property_id": self.property.id,
                    "scheduled_for": (
                        timezone.now() + timedelta(days=2)
                    ).isoformat(),
                }
            ),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.tenant_authorization,
        )

    def test_viewing_request_messages_landlord_and_acceptance_is_chatted(self):
        response = self._request_viewing()

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        conversation = Conversation.objects.get(pk=payload["conversation_id"])
        self.assertQuerySetEqual(
            conversation.participants.order_by("id"),
            [self.landlord, self.tenant],
            transform=lambda user: user,
        )
        request_message = Message.objects.get(conversation=conversation)
        self.assertEqual(request_message.sender, self.tenant)
        self.assertIn("Viewing request for Viewing rental", request_message.body)

        decision = self.client.patch(
            f"/api/viewings/{payload['id']}/",
            data=json.dumps({"status": "confirmed"}),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.landlord_authorization,
        )

        self.assertEqual(decision.status_code, 200)
        self.assertEqual(decision.json()["status"], Viewing.Status.CONFIRMED)
        self.assertEqual(Message.objects.filter(conversation=conversation).count(), 2)
        landlord_message = Message.objects.filter(conversation=conversation).latest("id")
        self.assertEqual(landlord_message.sender, self.landlord)
        self.assertIn("confirmed the viewing request", landlord_message.body)

        landlord_viewings = self.client.get(
            "/api/viewings/",
            HTTP_AUTHORIZATION=self.landlord_authorization,
        )
        self.assertEqual(
            landlord_viewings.json()["results"][0]["conversation_id"],
            conversation.id,
        )

    def test_landlord_can_reject_but_tenant_cannot_accept(self):
        response = self._request_viewing()
        viewing_id = response.json()["id"]

        tenant_decision = self.client.patch(
            f"/api/viewings/{viewing_id}/",
            data=json.dumps({"status": "confirmed"}),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.tenant_authorization,
        )
        self.assertEqual(tenant_decision.status_code, 403)

        landlord_decision = self.client.patch(
            f"/api/viewings/{viewing_id}/",
            data=json.dumps({"status": "rejected"}),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.landlord_authorization,
        )
        self.assertEqual(landlord_decision.status_code, 200)
        self.assertEqual(landlord_decision.json()["status"], Viewing.Status.REJECTED)

    def test_request_rejects_past_and_unavailable_property_times(self):
        past_response = self.client.post(
            "/api/viewings/",
            data=json.dumps(
                {
                    "property_id": self.property.id,
                    "scheduled_for": (
                        timezone.now() - timedelta(minutes=1)
                    ).isoformat(),
                }
            ),
            content_type="application/json",
            HTTP_AUTHORIZATION=self.tenant_authorization,
        )
        self.assertEqual(past_response.status_code, 400)

        self.property.availability_status = Property.AvailabilityStatus.RENTED
        self.property.save(update_fields=["availability_status"])
        unavailable_response = self._request_viewing()
        self.assertEqual(unavailable_response.status_code, 409)
