import re
import uuid

from .base import IdentityExtractionResult, IdentityVerificationProvider, IdentityVerificationResult

GENERIC_DOCUMENT_NUMBER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 /-]{4,63}$")


def normalize_identity_number(value):
    return re.sub(r"[^A-Z0-9]", "", str(value or "").upper())


def is_valid_generic_document_number(value):
    return bool(GENERIC_DOCUMENT_NUMBER_RE.fullmatch(str(value or "").strip()))


class LocalOCRIdentityVerificationProvider(IdentityVerificationProvider):
    provider_name = "manual_capture"

    def extract_document_data(self, *, files, data):
        # No OCR engine is installed in this backend. Do not fake extraction from
        # user-supplied hints, filenames, or raw image bytes.
        return IdentityExtractionResult(
            confidence="manual_entry_required",
            warnings=["ocr_engine_not_configured"],
        )

    def verify_document(self, *, files, data, document_type, confirmed_document_number):
        reference = f"manual-{uuid.uuid4()}"
        if not is_valid_generic_document_number(confirmed_document_number):
            return IdentityVerificationResult(
                status="rejected",
                provider=self.provider_name,
                provider_reference=reference,
                score=0.0,
                failure_reason="invalid_document_number",
                warnings=["manual_document_number_invalid"],
            )

        return IdentityVerificationResult(
            status="manual_review",
            provider=self.provider_name,
            provider_reference=reference,
            score=None,
            failure_reason="manual_review_required",
            warnings=["ocr_engine_not_configured"],
        )
