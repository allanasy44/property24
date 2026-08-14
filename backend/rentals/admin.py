from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import (
    AIAnalysis,
    Application,
    Commission,
    Conversation,
    DisputeReport,
    LeaseAgreement,
    MaintenanceRequest,
    Message,
    Payment,
    PendingRegistrationOTP,
    PhoneVerificationOTP,
    Property,
    PropertyPhoto,
    PropertyVideo,
    Review,
    SavedProperty,
    User,
    VerificationRequest,
    Viewing,
)


@admin.register(User)
class RentalUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (("Rental profile", {"fields": ("full_name", "phone", "role", "is_verified", "digital_rental_history")}),)
    list_display = ("username", "email", "full_name", "phone", "role", "is_verified", "is_staff")
    list_filter = ("role", "is_verified", "is_staff")
    search_fields = ("username", "email", "full_name", "phone")


class PropertyPhotoInline(admin.TabularInline):
    model = PropertyPhoto
    extra = 1


class PropertyVideoInline(admin.TabularInline):
    model = PropertyVideo
    extra = 1


@admin.register(Property)
class PropertyAdmin(admin.ModelAdmin):
    inlines = [PropertyPhotoInline, PropertyVideoInline]
    list_display = ("title", "city", "suburb", "monthly_rent", "property_type", "listing_status", "owner", "agent")
    list_filter = ("city", "property_type", "listing_status", "furnished", "solar_power", "borehole", "pet_friendly")
    search_fields = ("title", "address", "city", "suburb", "owner__username", "agent__username")


@admin.register(VerificationRequest)
class VerificationRequestAdmin(admin.ModelAdmin):
    list_display = ("user", "role", "status", "phone_verified", "document_type", "country_of_residence", "submitted_at", "reviewed_by")
    list_filter = ("role", "status", "phone_verified", "document_type", "privacy_notice_accepted", "declaration_accepted", "politically_exposed_person")
    search_fields = ("user__username", "user__full_name", "national_id_number", "document_issue_country", "residential_address", "agency_name")



@admin.register(PhoneVerificationOTP)
class PhoneVerificationOTPAdmin(admin.ModelAdmin):
    list_display = ("user", "phone", "status", "attempts", "expires_at", "verified_at", "created_at")
    list_filter = ("status",)
    search_fields = ("user__username", "user__full_name", "phone")
    readonly_fields = ("code_hash", "created_at", "updated_at", "verified_at")


@admin.register(PendingRegistrationOTP)
class PendingRegistrationOTPAdmin(admin.ModelAdmin):
    list_display = ("phone", "email", "role", "status", "attempts", "expires_at", "created_at")
    list_filter = ("role", "status")
    search_fields = ("phone", "email", "username", "full_name")
    readonly_fields = ("password_hash", "code_hash", "created_at", "updated_at", "consumed_at")


admin.site.register(Application)
admin.site.register(Viewing)
admin.site.register(Payment)
admin.site.register(LeaseAgreement)
admin.site.register(MaintenanceRequest)
admin.site.register(Conversation)
admin.site.register(Message)
admin.site.register(SavedProperty)
admin.site.register(Review)
admin.site.register(Commission)
admin.site.register(DisputeReport)


@admin.register(AIAnalysis)
class AIAnalysisAdmin(admin.ModelAdmin):
    list_display = ("analysis_type", "target_type", "target_id", "provider", "score", "recommendation", "created_at")
    list_filter = ("analysis_type", "provider", "recommendation")
    search_fields = ("target_type", "recommendation", "summary")
