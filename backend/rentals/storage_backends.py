import hashlib
import hmac
from datetime import datetime, timezone
from urllib.error import HTTPError
from urllib.parse import quote, urlencode, urlparse
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import Storage
from django.utils.crypto import get_random_string


class MinioStorage(Storage):
    def __init__(
        self,
        access_key=None,
        secret_key=None,
        bucket_name=None,
        endpoint_url=None,
        region_name=None,
        file_overwrite=False,
        **kwargs,
    ):
        self.access_key = access_key or settings.OBJECT_STORAGE_ACCESS_KEY_ID
        self.secret_key = secret_key or settings.OBJECT_STORAGE_SECRET_ACCESS_KEY
        self.bucket_name = bucket_name or settings.OBJECT_STORAGE_BUCKET
        self.endpoint_url = (endpoint_url or settings.OBJECT_STORAGE_ENDPOINT_URL).rstrip("/")
        self.region_name = region_name or settings.OBJECT_STORAGE_REGION
        self.file_overwrite = file_overwrite

    def _save(self, name, content):
        name = self.get_available_name(name)
        body = b"".join(content.chunks()) if hasattr(content, "chunks") else content.read()
        headers = {}
        content_type = getattr(content, "content_type", "")
        if content_type:
            headers["Content-Type"] = content_type
        self._request("PUT", name, body=body, headers=headers)
        return name

    def _open(self, name, mode="rb"):
        response = self._request("GET", name)
        return ContentFile(response.read(), name=name)

    def exists(self, name):
        try:
            self._request("HEAD", name)
            return True
        except HTTPError as exc:
            if exc.code == 404:
                return False
            raise

    def delete(self, name):
        try:
            self._request("DELETE", name)
        except HTTPError as exc:
            if exc.code != 404:
                raise

    def url(self, name, parameters=None, expire=None, http_method=None):
        public_base_url = settings.OBJECT_STORAGE_PUBLIC_BASE_URL.rstrip("/")
        if public_base_url and not parameters:
            return f"{public_base_url}/{quote(name, safe='/')}"
        if parameters and parameters.get("signed"):
            return self.presigned_url(name, expires=expire or settings.OBJECT_STORAGE_UPLOAD_EXPIRY_SECONDS, method=http_method or "GET")
        return f"{self.endpoint_url}/{self.bucket_name}/{quote(name, safe='/')}"

    def presigned_url(self, name, expires=900, method="GET"):
        if not self.endpoint_url or not self.bucket_name:
            raise RuntimeError("MinIO storage requires OBJECT_STORAGE_ENDPOINT_URL and OBJECT_STORAGE_BUCKET.")
        parsed = urlparse(self.endpoint_url)
        now = datetime.now(timezone.utc)
        amz_date = now.strftime("%Y%m%dT%H%M%SZ")
        date_stamp = now.strftime("%Y%m%d")
        credential_scope = f"{date_stamp}/{self.region_name}/s3/aws4_request"
        encoded_name = quote(name, safe="/~")
        canonical_uri = f"{parsed.path.rstrip('/')}/{self.bucket_name}/{encoded_name}"
        credential = f"{self.access_key}/{credential_scope}"
        query_params = {
            "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
            "X-Amz-Credential": credential,
            "X-Amz-Date": amz_date,
            "X-Amz-Expires": str(max(60, min(int(expires or 900), 3600))),
            "X-Amz-SignedHeaders": "host",
        }
        canonical_query = urlencode(sorted(query_params.items()), quote_via=quote)
        canonical_headers = f"host:{parsed.netloc}\n"
        canonical_request = "\n".join([method, canonical_uri, canonical_query, canonical_headers, "host", "UNSIGNED-PAYLOAD"])
        string_to_sign = "\n".join([
            "AWS4-HMAC-SHA256",
            amz_date,
            credential_scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ])
        signature = hmac.new(self._signing_key(date_stamp), string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
        return f"{parsed.scheme}://{parsed.netloc}{canonical_uri}?{canonical_query}&X-Amz-Signature={signature}"

    def get_available_name(self, name, max_length=None):
        if self.file_overwrite:
            return name
        if not self.exists(name):
            return name
        root, dot, ext = name.rpartition(".")
        base = root if dot else name
        suffix = f"_{get_random_string(7)}"
        return f"{base}{suffix}.{ext}" if dot else f"{base}{suffix}"

    def _request(self, method, name, body=b"", headers=None):
        if not self.endpoint_url or not self.bucket_name:
            raise RuntimeError("MinIO storage requires OBJECT_STORAGE_ENDPOINT_URL and OBJECT_STORAGE_BUCKET.")
        headers = headers or {}
        parsed = urlparse(self.endpoint_url)
        encoded_name = quote(name, safe="/~")
        canonical_uri = f"{parsed.path.rstrip('/')}/{self.bucket_name}/{encoded_name}"
        url = f"{parsed.scheme}://{parsed.netloc}{canonical_uri}"
        payload_hash = hashlib.sha256(body).hexdigest()
        signed_headers = self._signed_headers(method, canonical_uri, payload_hash, parsed.netloc)
        request = Request(url, data=body if method not in {"HEAD", "GET"} else None, method=method)
        for key, value in {**headers, **signed_headers}.items():
            request.add_header(key, value)
        return urlopen(request, timeout=8)

    def _signed_headers(self, method, canonical_uri, payload_hash, host):
        now = datetime.now(timezone.utc)
        amz_date = now.strftime("%Y%m%dT%H%M%SZ")
        date_stamp = now.strftime("%Y%m%d")
        credential_scope = f"{date_stamp}/{self.region_name}/s3/aws4_request"
        canonical_headers = f"host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n"
        signed_headers = "host;x-amz-content-sha256;x-amz-date"
        canonical_request = "\n".join([method, canonical_uri, "", canonical_headers, signed_headers, payload_hash])
        string_to_sign = "\n".join(
            [
                "AWS4-HMAC-SHA256",
                amz_date,
                credential_scope,
                hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
            ]
        )
        signature = hmac.new(self._signing_key(date_stamp), string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
        return {
            "Authorization": f"AWS4-HMAC-SHA256 Credential={self.access_key}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}",
            "X-Amz-Content-SHA256": payload_hash,
            "X-Amz-Date": amz_date,
        }

    def _signing_key(self, date_stamp):
        date_key = hmac.new(f"AWS4{self.secret_key}".encode("utf-8"), date_stamp.encode("utf-8"), hashlib.sha256).digest()
        region_key = hmac.new(date_key, self.region_name.encode("utf-8"), hashlib.sha256).digest()
        service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
        return hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()
