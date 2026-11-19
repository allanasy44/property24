from unittest import TestCase
from urllib.parse import parse_qs, urlsplit

from django.test import override_settings

from .storage_backends import MinioStorage


class MinioPrivateUrlTests(TestCase):
    @override_settings(
        OBJECT_STORAGE_QUERYSTRING_AUTH=True,
        OBJECT_STORAGE_PUBLIC_BASE_URL="https://media.example.test/property24-media",
        OBJECT_STORAGE_UPLOAD_EXPIRY_SECONDS=900,
    )
    def test_url_signs_against_browser_reachable_bucket_url(self):
        storage = MinioStorage(
            access_key="test-access-key",
            secret_key="test-secret-key",
            bucket_name="property24-media",
            endpoint_url="http://minio:9000",
        )

        parsed_url = urlsplit(storage.url("identity/front.jpg"))

        self.assertEqual(parsed_url.scheme, "https")
        self.assertEqual(parsed_url.netloc, "media.example.test")
        self.assertEqual(parsed_url.path, "/property24-media/identity/front.jpg")
        self.assertIn("X-Amz-Signature", parse_qs(parsed_url.query))
