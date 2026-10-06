import json
from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch

from django.test import TestCase
from django.utils import timezone

from .auth import issue_token_pair
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
    User,
    Viewing,
)
from .property_search import normalize_search_requirements
from .views import (
    _notify_property_lifecycle_events,
    _notify_saved_search_matches,
    apply_property_filters,
    serialize_property,
)
from .gemini_service import GeminiConfigurationError, GeminiService
from .gemini_service import GeminiServiceError


class GoogleSignInConfigTests(TestCase):
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
