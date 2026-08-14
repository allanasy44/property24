from .providers.local_ocr import LocalOCRIdentityVerificationProvider


def get_identity_verification_provider():
    return LocalOCRIdentityVerificationProvider()
