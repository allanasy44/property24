from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone


class User(AbstractUser):
    class Roles(models.TextChoices):
        TENANT = "tenant", "Tenant"
        LANDLORD = "landlord", "Landlord"
        AGENT = "agent", "Estate Agent"
        ADMIN = "admin", "Administrator"

    full_name = models.CharField(max_length=160, blank=True)
    phone = models.CharField(max_length=32, blank=True)
    role = models.CharField(max_length=16, choices=Roles.choices, default=Roles.TENANT)
    is_verified = models.BooleanField(default=False)
    auth_provider = models.CharField(max_length=24, default="password")
    google_subject = models.CharField(max_length=255, blank=True, unique=True, null=True)
    google_email_verified = models.BooleanField(default=False)
    profile_picture = models.ImageField(upload_to="accounts/profile-pictures/", blank=True)
    cover_photo = models.ImageField(upload_to="accounts/cover-photos/", blank=True)
    profile_picture_url = models.URLField(blank=True)
    cover_photo_url = models.URLField(blank=True)
    bio = models.TextField(blank=True)
    last_seen_at = models.DateTimeField(null=True, blank=True)
    digital_rental_history = models.JSONField(default=list, blank=True)

    class Meta:
        verbose_name = "user"
        verbose_name_plural = "users"
        constraints = [
            models.UniqueConstraint(fields=["phone"], condition=~models.Q(phone=""), name="unique_nonblank_user_phone"),
            models.UniqueConstraint(fields=["email"], condition=~models.Q(email=""), name="unique_nonblank_user_email"),
        ]

    def __str__(self):
        return self.full_name or self.username


class PendingRegistrationOTP(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        CONSUMED = "consumed", "Consumed"
        EXPIRED = "expired", "Expired"

    username = models.CharField(max_length=150)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=32)
    full_name = models.CharField(max_length=160, blank=True)
    role = models.CharField(max_length=16, choices=User.Roles.choices, default=User.Roles.TENANT)
    password_hash = models.CharField(max_length=128)
    code_hash = models.CharField(max_length=128)
    sent_to = models.CharField(max_length=254)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    attempts = models.PositiveSmallIntegerField(default=0)
    expires_at = models.DateTimeField()
    consumed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["phone", "status"]),
            models.Index(fields=["email", "status"]),
            models.Index(fields=["username", "status"]),
        ]

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at

    def __str__(self):
        return f"OTP for {self.phone} ({self.status})"


class PhoneVerificationOTP(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        VERIFIED = "verified", "Verified"
        EXPIRED = "expired", "Expired"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="phone_verification_otps")
    phone = models.CharField(max_length=32)
    code_hash = models.CharField(max_length=128)
    sent_to = models.CharField(max_length=32)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    attempts = models.PositiveSmallIntegerField(default=0)
    expires_at = models.DateTimeField()
    verified_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "phone", "status"], name="rentals_pho_user_id_7aa62e_idx"),
            models.Index(fields=["phone", "status"], name="rentals_pho_phone_14590b_idx"),
        ]

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at

    def __str__(self):
        return f"Phone OTP for {self.phone} ({self.status})"


class SecurityAuditEvent(models.Model):
    class Category(models.TextChoices):
        AUTHENTICATION = "authentication", "Authentication"
        AUTHORIZATION = "authorization", "Authorization"
        CHAT = "chat", "Chat"
        PRESENCE = "presence", "Presence"
        RATE_LIMIT = "rate_limit", "Rate limit"
        SYSTEM = "system", "System"

    class Severity(models.TextChoices):
        INFO = "info", "Info"
        LOW = "low", "Low"
        MEDIUM = "medium", "Medium"
        HIGH = "high", "High"
        CRITICAL = "critical", "Critical"

    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="security_audit_events")
    category = models.CharField(max_length=32, choices=Category.choices)
    event_type = models.CharField(max_length=80)
    severity = models.CharField(max_length=16, choices=Severity.choices, default=Severity.INFO)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["category", "event_type", "created_at"], name="rentals_sec_categor_ea206d_idx"),
            models.Index(fields=["actor", "created_at"], name="rentals_sec_actor_i_4996af_idx"),
            models.Index(fields=["severity", "created_at"], name="rentals_sec_severit_bab0de_idx"),
        ]

    def __str__(self):
        return f"{self.severity} {self.category}.{self.event_type}"


class VerificationRequest(models.Model):
    class Status(models.TextChoices):
        SUBMITTED = "submitted", "Submitted"
        REVIEWING = "reviewing", "Reviewing"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="verification_requests")
    role = models.CharField(max_length=16, choices=User.Roles.choices)
    national_id_number = models.CharField(max_length=64, blank=True)
    phone_verified = models.BooleanField(default=False)
    country_of_residence = models.CharField(max_length=80, blank=True)
    privacy_notice_accepted = models.BooleanField(default=False)
    document_issue_country = models.CharField(max_length=80, blank=True)
    document_type = models.CharField(max_length=40, blank=True)
    residential_address = models.TextField(blank=True)
    address_gps_confirmed = models.BooleanField(default=False)
    proof_of_address_document = models.FileField(upload_to="verification/address/", blank=True)
    proof_of_address_confirmed = models.BooleanField(default=False)
    politically_exposed_person = models.BooleanField(default=False)
    declaration_accepted = models.BooleanField(default=False)
    id_front_document = models.FileField(upload_to="verification/id-front/", blank=True)
    id_back_document = models.FileField(upload_to="verification/id-back/", blank=True)
    extracted_national_id_number = models.CharField(max_length=64, blank=True)
    identity_confirmed = models.BooleanField(default=False)
    liveness_document = models.FileField(upload_to="verification/liveness/", blank=True)
    selfie_document = models.FileField(upload_to="verification/selfies/", blank=True)
    ownership_or_authorization_document = models.FileField(upload_to="verification/ownership/", blank=True)
    estate_agency_registration = models.CharField(max_length=120, blank=True)
    agency_name = models.CharField(max_length=160, blank=True)
    contact_details = models.TextField(blank=True)
    checks = models.JSONField(default=list, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.SUBMITTED)
    reviewed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="reviewed_verifications")
    notes = models.TextField(blank=True)
    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    def approve(self, reviewer=None):
        self.status = self.Status.APPROVED
        self.reviewed_by = reviewer
        self.reviewed_at = timezone.now()
        self.user.is_verified = True
        self.user.save(update_fields=["is_verified"])
        self.save(update_fields=["status", "reviewed_by", "reviewed_at"])

    def __str__(self):
        return f"{self.user} {self.get_role_display()} verification"


class Property(models.Model):
    class PropertyType(models.TextChoices):
        HOUSE = "house", "House"
        FLAT = "flat", "Flat"
        COTTAGE = "cottage", "Cottage"
        STUDENT = "student_accommodation", "Student accommodation"
        COMMERCIAL = "commercial_property", "Commercial property"

    class ListingStatus(models.TextChoices):
        DRAFT = "draft", "Draft"
        PENDING_VERIFICATION = "pending_verification", "Pending verification"
        VERIFIED = "verified", "Verified"
        REJECTED = "rejected", "Rejected"
        ARCHIVED = "archived", "Archived"

    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="properties")
    agent = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="managed_properties")
    title = models.CharField(max_length=180)
    description = models.TextField(blank=True)
    address = models.CharField(max_length=240)
    city = models.CharField(max_length=100, db_index=True)
    suburb = models.CharField(max_length=100, db_index=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    monthly_rent = models.DecimalField(max_digits=12, decimal_places=2)
    deposit_required = models.DecimalField(max_digits=12, decimal_places=2)
    property_type = models.CharField(max_length=32, choices=PropertyType.choices)
    bedrooms = models.PositiveSmallIntegerField(default=0)
    bathrooms = models.DecimalField(max_digits=4, decimal_places=1, default=1)
    furnished = models.BooleanField(default=False)
    water_availability = models.CharField(max_length=160, blank=True)
    solar_power = models.BooleanField(default=False)
    borehole = models.BooleanField(default=False)
    parking = models.CharField(max_length=120, blank=True)
    pet_friendly = models.BooleanField(default=False)
    has_360_tour = models.BooleanField(default=False)
    listing_status = models.CharField(max_length=32, choices=ListingStatus.choices, default=ListingStatus.PENDING_VERIFICATION)
    is_active = models.BooleanField(default=True)
    views_count = models.PositiveIntegerField(default=0)
    saved_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def is_verified(self):
        return self.listing_status == self.ListingStatus.VERIFIED

    def __str__(self):
        return self.title


class PropertyPhoto(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="photos")
    image = models.ImageField(upload_to="properties/photos/", blank=True)
    caption = models.CharField(max_length=160, blank=True)
    sort_order = models.PositiveSmallIntegerField(default=0)

    def __str__(self):
        return self.caption or f"Photo for {self.property}"


class PropertyVideo(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="videos")
    video = models.FileField(upload_to="properties/videos/", blank=True)
    external_url = models.URLField(blank=True)
    caption = models.CharField(max_length=160, blank=True)

    def __str__(self):
        return self.caption or f"Video for {self.property}"


class SavedProperty(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="saved_by")
    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="saved_properties")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("property", "tenant")


class PropertyComment(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="comments")
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="property_comments")
    parent = models.ForeignKey("self", on_delete=models.CASCADE, null=True, blank=True, related_name="replies")
    body = models.TextField()
    media_url = models.URLField(blank=True)
    likes_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["property", "-created_at"]),
            models.Index(fields=["author", "-created_at"]),
        ]

    def __str__(self):
        return f"Comment by {self.author} on {self.property}"


class SupplierFollow(models.Model):
    follower = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="followed_suppliers")
    supplier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="supplier_followers")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("follower", "supplier")


class Application(models.Model):
    class Status(models.TextChoices):
        SUBMITTED = "submitted", "Submitted"
        UNDER_REVIEW = "under_review", "Under review"
        APPROVED = "approved", "Approved"
        DECLINED = "declined", "Declined"
        WITHDRAWN = "withdrawn", "Withdrawn"

    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="applications")
    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="rental_applications")
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.SUBMITTED)
    score = models.PositiveSmallIntegerField(default=0, validators=[MaxValueValidator(100)])
    message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("property", "tenant")

    def __str__(self):
        return f"{self.tenant} application for {self.property}"


class Viewing(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        CONFIRMED = "confirmed", "Confirmed"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"

    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="viewings")
    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="viewings")
    agent = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="agent_viewings")
    scheduled_for = models.DateTimeField()
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class Payment(models.Model):
    class Method(models.TextChoices):
        ECOCASH = "ecocash", "EcoCash"
        ZIPIT = "zipit", "ZIPIT"
        BANK_TRANSFER = "bank_transfer", "Bank transfer"
        CARD = "card", "Visa/Mastercard"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        RECEIVED = "received", "Received"
        FAILED = "failed", "Failed"
        REFUNDED = "refunded", "Refunded"

    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="payments")
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="payments")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    method = models.CharField(max_length=24, choices=Method.choices)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    provider_reference = models.CharField(max_length=120, blank=True)
    receipt_number = models.CharField(max_length=32, unique=True)
    reminder_status = models.CharField(max_length=160, blank=True)
    due_date = models.DateField(null=True, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.receipt_number} {self.amount}"


class LeaseAgreement(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        AWAITING_SIGNATURES = "awaiting_signatures", "Awaiting signatures"
        ACTIVE = "active", "Active"
        EXPIRED = "expired", "Expired"
        TERMINATED = "terminated", "Terminated"

    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="leases")
    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="leases")
    landlord = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="landlord_leases")
    start_date = models.DateField()
    end_date = models.DateField()
    monthly_rent = models.DecimalField(max_digits=12, decimal_places=2)
    deposit = models.DecimalField(max_digits=12, decimal_places=2)
    term = models.CharField(max_length=80, default="12 Months")
    contract_text = models.TextField(blank=True)
    pdf = models.FileField(upload_to="leases/", blank=True)
    status = models.CharField(max_length=24, choices=Status.choices, default=Status.DRAFT)
    signed_by_tenant = models.BooleanField(default=False)
    signed_by_landlord = models.BooleanField(default=False)
    tenant_signed_at = models.DateTimeField(null=True, blank=True)
    landlord_signed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def generate_contract_text(self):
        from .ai import generate_lease_text

        return generate_lease_text(self)

    def save(self, *args, **kwargs):
        if not self.contract_text:
            self.contract_text = self.generate_contract_text()
        if self.signed_by_tenant and self.signed_by_landlord and self.status in {self.Status.DRAFT, self.Status.AWAITING_SIGNATURES}:
            self.status = self.Status.ACTIVE
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Lease for {self.property}"


class MaintenanceRequest(models.Model):
    class Category(models.TextChoices):
        PLUMBING = "plumbing", "Plumbing"
        ELECTRICITY = "electricity", "Electricity"
        ROOFING = "roofing", "Roofing"
        PAINTING = "painting", "Painting"
        GENERAL = "general_repairs", "General repairs"

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        IN_PROGRESS = "in_progress", "In progress"
        RESOLVED = "resolved", "Resolved"
        CANCELLED = "cancelled", "Cancelled"

    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="maintenance_requests")
    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="maintenance_requests")
    issue = models.CharField(max_length=180)
    category = models.CharField(max_length=32, choices=Category.choices)
    description = models.TextField(blank=True)
    photo = models.ImageField(upload_to="maintenance/photos/", blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.OPEN)
    priority = models.CharField(max_length=32, default="normal")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.issue


class Conversation(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="conversations", null=True, blank=True)
    participants = models.ManyToManyField(settings.AUTH_USER_MODEL, related_name="conversations")
    title = models.CharField(max_length=180, blank=True)
    phone_numbers_revealed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title or f"Conversation {self.pk}"


class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sent_messages")
    body = models.TextField()
    attachment = models.FileField(upload_to="conversations/attachments/", blank=True)
    attachment_url = models.URLField(blank=True)
    attachment_type = models.CharField(max_length=32, blank=True)
    attachment_name = models.CharField(max_length=180, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["created_at"]


class CallSession(models.Model):
    class Mode(models.TextChoices):
        VOICE = "voice", "Voice"
        VIDEO = "video", "Video"

    class Status(models.TextChoices):
        RINGING = "ringing", "Ringing"
        ENDED = "ended", "Ended"
        MISSED = "missed", "Missed"

    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="call_sessions")
    initiator = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="started_call_sessions")
    mode = models.CharField(max_length=12, choices=Mode.choices)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.RINGING)
    created_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]


class Review(models.Model):
    tenant = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews_written")
    landlord = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="landlord_reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class Commission(models.Model):
    agent = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="commissions")
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="commissions")
    lease = models.ForeignKey(LeaseAgreement, on_delete=models.SET_NULL, null=True, blank=True, related_name="commissions")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=24, default="pending")
    created_at = models.DateTimeField(auto_now_add=True)


class DisputeReport(models.Model):
    class Status(models.TextChoices):
        OPEN = "open", "Open"
        REVIEWING = "reviewing", "Reviewing"
        RESOLVED = "resolved", "Resolved"
        DISMISSED = "dismissed", "Dismissed"

    reporter = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reports")
    property = models.ForeignKey(Property, on_delete=models.SET_NULL, null=True, blank=True, related_name="reports")
    subject = models.CharField(max_length=180)
    description = models.TextField()
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.OPEN)
    assigned_admin = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_reports")
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return self.subject


class AIAnalysis(models.Model):
    class AnalysisType(models.TextChoices):
        LISTING_RISK = "listing_risk", "Listing risk"
        MAINTENANCE_TRIAGE = "maintenance_triage", "Maintenance triage"
        APPLICATION_SCORE = "application_score", "Application score"

    analysis_type = models.CharField(max_length=32, choices=AnalysisType.choices)
    target_type = models.CharField(max_length=64, blank=True)
    target_id = models.PositiveBigIntegerField(null=True, blank=True)
    provider = models.CharField(max_length=40, default="local")
    model = models.CharField(max_length=80, default="property24-rules-v1")
    score = models.JSONField(default=dict, blank=True)
    confidence = models.DecimalField(max_digits=4, decimal_places=2, default=0)
    flags = models.JSONField(default=list, blank=True)
    recommendation = models.CharField(max_length=80, blank=True)
    summary = models.TextField(blank=True)
    result = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["analysis_type", "target_type", "target_id"]),
        ]

    def __str__(self):
        return f"{self.analysis_type} for {self.target_type or 'payload'} {self.target_id or ''}".strip()
