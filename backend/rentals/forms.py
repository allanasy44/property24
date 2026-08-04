from django import forms
from django.contrib.auth import get_user_model

from .models import Application, Conversation, DisputeReport, LeaseAgreement, MaintenanceRequest, Payment, Property, Review, VerificationRequest, Viewing


User = get_user_model()


class JsonForm(forms.Form):
    def error_payload(self):
        return self.errors.get_json_data()


class UserCreateForm(JsonForm):
    username = forms.CharField(required=False, max_length=150)
    email = forms.EmailField(required=False)
    password = forms.CharField(required=False)
    name = forms.CharField(required=False, max_length=160)
    full_name = forms.CharField(required=False, max_length=160)
    phone = forms.CharField(required=False, max_length=32)
    role = forms.ChoiceField(choices=User.Roles.choices, required=False)

    def clean(self):
        cleaned_data = super().clean()
        if not cleaned_data.get("username") and not cleaned_data.get("email"):
            raise forms.ValidationError("username or email is required")
        return cleaned_data


class PropertyCreateForm(JsonForm):
    owner_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    agent_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id", required=False)
    title = forms.CharField(max_length=180)
    description = forms.CharField(required=False)
    address = forms.CharField(max_length=240)
    city = forms.CharField(max_length=100)
    suburb = forms.CharField(max_length=100)
    latitude = forms.DecimalField(max_digits=9, decimal_places=6, required=False)
    longitude = forms.DecimalField(max_digits=9, decimal_places=6, required=False)
    gps = forms.CharField(required=False)
    monthly_rent = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    price = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    deposit_required = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    deposit = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    property_type = forms.ChoiceField(choices=Property.PropertyType.choices, required=False)
    type = forms.ChoiceField(choices=Property.PropertyType.choices, required=False)
    bedrooms = forms.IntegerField(min_value=0)
    bathrooms = forms.DecimalField(max_digits=4, decimal_places=1, min_value=0)
    furnished = forms.BooleanField(required=False)
    water_availability = forms.CharField(required=False, max_length=160)
    water = forms.CharField(required=False, max_length=160)
    solar_power = forms.BooleanField(required=False)
    borehole = forms.BooleanField(required=False)
    parking = forms.CharField(required=False, max_length=120)
    pet_friendly = forms.BooleanField(required=False)
    has_360_tour = forms.BooleanField(required=False)
    listing_status = forms.ChoiceField(choices=Property.ListingStatus.choices, required=False)

    def clean(self):
        cleaned_data = super().clean()
        if cleaned_data.get("monthly_rent") is None and cleaned_data.get("price") is None:
            self.add_error("monthly_rent", "This field is required.")
        if cleaned_data.get("deposit_required") is None and cleaned_data.get("deposit") is None:
            self.add_error("deposit_required", "This field is required.")
        if cleaned_data.get("latitude") is None and cleaned_data.get("longitude") is None:
            latitude, longitude = parse_gps(cleaned_data.get("gps"))
            cleaned_data["latitude"] = latitude
            cleaned_data["longitude"] = longitude
        return cleaned_data


class PropertyUpdateForm(JsonForm):
    title = forms.CharField(max_length=180, required=False)
    description = forms.CharField(required=False)
    address = forms.CharField(max_length=240, required=False)
    city = forms.CharField(max_length=100, required=False)
    suburb = forms.CharField(max_length=100, required=False)
    monthly_rent = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    deposit_required = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    property_type = forms.ChoiceField(choices=Property.PropertyType.choices, required=False)
    bedrooms = forms.IntegerField(min_value=0, required=False)
    bathrooms = forms.DecimalField(max_digits=4, decimal_places=1, min_value=0, required=False)
    furnished = forms.BooleanField(required=False)
    water_availability = forms.CharField(required=False, max_length=160)
    solar_power = forms.BooleanField(required=False)
    borehole = forms.BooleanField(required=False)
    parking = forms.CharField(required=False, max_length=120)
    pet_friendly = forms.BooleanField(required=False)
    has_360_tour = forms.BooleanField(required=False)
    listing_status = forms.ChoiceField(choices=Property.ListingStatus.choices, required=False)
    is_active = forms.BooleanField(required=False)


class ApplicationForm(JsonForm):
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id")
    tenant_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    status = forms.ChoiceField(choices=Application.Status.choices, required=False)
    score = forms.IntegerField(min_value=0, max_value=100, required=False)
    message = forms.CharField(required=False)


class PaymentForm(JsonForm):
    tenant_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id")
    amount = forms.DecimalField(max_digits=12, decimal_places=2)
    method = forms.ChoiceField(choices=Payment.Method.choices)
    status = forms.ChoiceField(choices=Payment.Status.choices, required=False)
    provider_reference = forms.CharField(required=False, max_length=120)
    receipt_number = forms.CharField(required=False, max_length=32)
    reminder_status = forms.CharField(required=False, max_length=160)
    due_date = forms.DateField(required=False)


class LeaseForm(JsonForm):
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id")
    tenant_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    landlord_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id", required=False)
    start_date = forms.DateField()
    end_date = forms.DateField()
    monthly_rent = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    deposit = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    term = forms.CharField(max_length=80, required=False)
    status = forms.ChoiceField(choices=LeaseAgreement.Status.choices, required=False)


class LeaseSignatureForm(JsonForm):
    signed_by = forms.ChoiceField(choices=(("tenant", "Tenant"), ("landlord", "Landlord")))


class MaintenanceForm(JsonForm):
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id")
    tenant_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    issue = forms.CharField(max_length=180)
    category = forms.ChoiceField(choices=MaintenanceRequest.Category.choices)
    description = forms.CharField(required=False)
    status = forms.ChoiceField(choices=MaintenanceRequest.Status.choices, required=False)
    priority = forms.CharField(required=False, max_length=32)


class VerificationForm(JsonForm):
    user_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    role = forms.ChoiceField(choices=User.Roles.choices, required=False)
    national_id_number = forms.CharField(required=False, max_length=64)
    phone_verified = forms.BooleanField(required=False)
    estate_agency_registration = forms.CharField(required=False, max_length=120)
    agency_name = forms.CharField(required=False, max_length=160)
    contact_details = forms.CharField(required=False)
    checks = forms.JSONField(required=False)
    status = forms.ChoiceField(choices=VerificationRequest.Status.choices, required=False)


class VerificationReviewForm(JsonForm):
    status = forms.ChoiceField(choices=VerificationRequest.Status.choices)
    reviewed_by_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id", required=False)
    notes = forms.CharField(required=False)


class ViewingForm(JsonForm):
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id")
    tenant_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    agent_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id", required=False)
    scheduled_for = forms.DateTimeField()
    status = forms.ChoiceField(choices=Viewing.Status.choices, required=False)
    notes = forms.CharField(required=False)


class ConversationForm(JsonForm):
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id", required=False)
    participant_ids = forms.ModelMultipleChoiceField(queryset=User.objects.all(), to_field_name="id")
    title = forms.CharField(required=False, max_length=180)
    phone_numbers_revealed = forms.BooleanField(required=False)


class MessageForm(JsonForm):
    sender_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    body = forms.CharField()


class ReviewForm(JsonForm):
    tenant_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    landlord_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    rating = forms.IntegerField(min_value=1, max_value=5)
    comment = forms.CharField(required=False)


class ReportForm(JsonForm):
    reporter_id = forms.ModelChoiceField(queryset=User.objects.all(), to_field_name="id")
    property_id = forms.ModelChoiceField(queryset=Property.objects.all(), to_field_name="id", required=False)
    subject = forms.CharField(max_length=180)
    description = forms.CharField()
    status = forms.ChoiceField(choices=DisputeReport.Status.choices, required=False)


def parse_gps(value):
    if not value or "," not in value:
        return None, None
    latitude, longitude = value.split(",", 1)
    return latitude.strip(), longitude.strip()
