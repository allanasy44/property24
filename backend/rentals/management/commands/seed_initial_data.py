from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from rentals.models import Application, Property, VerificationRequest, Viewing


class Command(BaseCommand):
    help = "Seed initial data for the Property24 Zimbabwe rentals API."

    def handle(self, *args, **options):
        User = get_user_model()
        landlord, _ = User.objects.get_or_create(username="john@property24.test", defaults={"email": "john@property24.test", "full_name": "John Doe", "phone": "+263771000001", "role": User.Roles.LANDLORD, "is_verified": True})
        tenant, _ = User.objects.get_or_create(username="jane@property24.test", defaults={"email": "jane@property24.test", "full_name": "Jane Smith", "phone": "+263772000002", "role": User.Roles.TENANT})
        agent, _ = User.objects.get_or_create(username="tariro@property24.test", defaults={"email": "tariro@property24.test", "full_name": "Tariro Moyo", "phone": "+263773000003", "role": User.Roles.AGENT, "is_verified": True})

        prop, _ = Property.objects.get_or_create(
            title="Borrowdale family house",
            defaults={
                "owner": landlord,
                "agent": agent,
                "address": "123 Borrowdale Road",
                "city": "Harare",
                "suburb": "Borrowdale",
                "latitude": "-17.756200",
                "longitude": "31.088100",
                "monthly_rent": "450.00",
                "deposit_required": "450.00",
                "property_type": Property.PropertyType.HOUSE,
                "bedrooms": 3,
                "bathrooms": "2.0",
                "description": "Verified landlord, ID and liveness checks on file, borehole water, solar backup, and secure parking.",
                "water_availability": "Municipal water",
                "solar_power": True,
                "borehole": True,
                "parking": "2 car bays",
                "pet_friendly": True,
                "listing_status": Property.ListingStatus.VERIFIED,
                "views_count": 148,
                "saved_count": 31,
            },
        )

        VerificationRequest.objects.filter(user=landlord, role=User.Roles.LANDLORD).first() or VerificationRequest.objects.create(
            user=landlord,
            role=User.Roles.LANDLORD,
            national_id_number="63-000000A63",
            phone_verified=True,
            checks=["Phone OTP verification", "ID front capture", "ID back capture", "Extracted ID confirmation", "Liveness check"],
            status=VerificationRequest.Status.APPROVED,
            reviewed_at=timezone.now(),
        )
        Application.objects.get_or_create(property=prop, tenant=tenant, defaults={"status": Application.Status.APPROVED, "score": 92})
        Viewing.objects.get_or_create(property=prop, tenant=tenant, agent=agent, scheduled_for="2026-07-24T10:00:00+02:00", defaults={"status": Viewing.Status.CONFIRMED})

        self.stdout.write(self.style.SUCCESS("Seeded Property24 initial data."))
