from dataclasses import dataclass, field


@dataclass(frozen=True)
class IdentityExtractionResult:
    document_number: str = ""
    confidence: str = "manual_review_required"
    extracted_fields: dict = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class IdentityVerificationResult:
    status: str
    extracted_document_number: str = ""
    provider: str = "local_ocr"
    provider_reference: str = ""
    score: float | None = None
    failure_reason: str = ""
    warnings: list[str] = field(default_factory=list)


class IdentityVerificationProvider:
    provider_name = "base"

    def extract_document_data(self, *, files, data):
        raise NotImplementedError

    def verify_document(self, *, files, data, document_type, confirmed_document_number):
        raise NotImplementedError
