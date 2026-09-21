import re
import shutil
import subprocess
import uuid
from io import BytesIO

from PIL import Image, ImageFilter, ImageStat

from .base import IdentityExtractionResult, IdentityVerificationProvider, IdentityVerificationResult

GENERIC_DOCUMENT_NUMBER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 /-]{4,63}$")


def normalize_identity_number(value):
    return re.sub(r"[^A-Z0-9]", "", str(value or "").upper())


def is_valid_generic_document_number(value):
    return bool(GENERIC_DOCUMENT_NUMBER_RE.fullmatch(str(value or "").strip()))


class LocalOCRIdentityVerificationProvider(IdentityVerificationProvider):
    provider_name = "manual_capture"

    def extract_document_data(self, *, files, data):
        extracted_fields, checks, warnings = self._inspect_documents(files)
        if extracted_fields.get("document_number"):
            confidence = "extracted"
        elif shutil.which("tesseract"):
            confidence = "ocr_uncertain"
        else:
            confidence = "manual_entry_required"
        return IdentityExtractionResult(
            document_number=extracted_fields.get("document_number", ""),
            confidence=confidence,
            extracted_fields=extracted_fields,
            warnings=warnings,
        )

    def verify_document(self, *, files, data, document_type, confirmed_document_number):
        reference = f"local-{uuid.uuid4()}"
        if not is_valid_generic_document_number(confirmed_document_number):
            return IdentityVerificationResult(
                status="rejected",
                provider=self.provider_name,
                provider_reference=reference,
                score=0.0,
                failure_reason="invalid_document_number",
                warnings=["manual_document_number_invalid"],
            )
        extracted_fields, checks, warnings = self._inspect_documents(files)
        extracted_number = normalize_identity_number(extracted_fields.get("document_number", ""))
        confirmed_number = normalize_identity_number(confirmed_document_number)
        if extracted_number:
            checks.append({
                "type": "document_number_match",
                "result": "pass" if extracted_number == confirmed_number else "review",
                "details": "OCR document number matches the submitted number" if extracted_number == confirmed_number else "OCR document number differs from the submitted number",
            })
        else:
            checks.append({"type": "document_number_match", "result": "review", "details": "Document number requires manual confirmation"})
        return IdentityVerificationResult(
            status="manual_review",
            extracted_document_number=extracted_fields.get("document_number", ""),
            provider=self.provider_name,
            provider_reference=reference,
            score=None,
            failure_reason="manual_review_required",
            warnings=warnings,
            extracted_fields=extracted_fields,
            checks=checks,
        )

    def _inspect_documents(self, files):
        checks = []
        warnings = []
        extracted_fields = {}
        texts = []
        for field_name in ("id_front_document", "id_back_document"):
            upload = files.get(field_name)
            if not upload:
                continue
            quality, text = self._inspect_upload(upload)
            checks.extend({"type": f"{field_name}_{key}", "result": value[0], "details": value[1]} for key, value in quality.items())
            if text:
                texts.append(text)
        raw_text = "\n".join(texts)
        if raw_text:
            extracted_fields.update(self._extract_fields(raw_text))
            checks.append({"type": "ocr", "result": "pass", "details": "Document text was extracted"})
        else:
            warnings.append("ocr_engine_not_configured" if not shutil.which("tesseract") else "ocr_text_not_detected")
            checks.append({"type": "ocr", "result": "review", "details": "OCR text was not available; manual review required"})
        return extracted_fields, checks, warnings

    def _inspect_upload(self, upload):
        upload.seek(0)
        image = Image.open(BytesIO(upload.read()))
        image.load()
        gray = image.convert("L")
        brightness = ImageStat.Stat(gray).mean[0]
        contrast = ImageStat.Stat(gray).stddev[0]
        edge_stat = ImageStat.Stat(gray.filter(ImageFilter.FIND_EDGES)).mean[0]
        quality = {
            "dimensions": ("pass", f"{image.width}x{image.height}"),
            "brightness": ("pass" if 35 <= brightness <= 225 else "review", f"brightness={brightness:.0f}"),
            "contrast": ("pass" if contrast >= 18 else "review", f"contrast={contrast:.0f}"),
            "sharpness": ("pass" if edge_stat >= 8 else "review", f"edge_detail={edge_stat:.1f}"),
        }
        text = ""
        if shutil.which("tesseract"):
            upload.seek(0)
            process = subprocess.run(
                ["tesseract", "stdin", "stdout", "--psm", "6"],
                input=upload.read(), capture_output=True, timeout=12, check=False,
            )
            text = process.stdout.decode("utf-8", errors="ignore")
        return quality, text

    def _extract_fields(self, text):
        normalized = " ".join(text.split())
        id_match = re.search(r"\b\d{2}[- ]?\d{5,7}[- ]?[A-Z0-9][- ]?\d{1,3}\b", normalized, re.IGNORECASE)
        dob_match = re.search(r"\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b", normalized)
        return {
            "document_number": id_match.group(0) if id_match else "",
            "date_of_birth": dob_match.group(1) if dob_match else "",
            "raw_name_hint": normalized[:160],
        }
