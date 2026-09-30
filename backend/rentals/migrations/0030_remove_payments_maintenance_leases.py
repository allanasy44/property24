from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("rentals", "0029_alter_property_property_type"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="commission",
            name="lease",
        ),
        migrations.DeleteModel(name="Payment"),
        migrations.DeleteModel(name="LeaseAgreement"),
        migrations.DeleteModel(name="MaintenanceRequest"),
        migrations.RemoveField(
            model_name="property",
            name="payment_terms",
        ),
        migrations.RemoveField(
            model_name="user",
            name="digital_rental_history",
        ),
        migrations.AlterField(
            model_name="mediaasset",
            name="scope",
            field=models.CharField(
                choices=[
                    ("profile", "Profile"),
                    ("property", "Property"),
                    ("chat", "Chat"),
                    ("verification", "Verification"),
                ],
                max_length=24,
            ),
        ),
        migrations.AlterField(
            model_name="aianalysis",
            name="analysis_type",
            field=models.CharField(
                choices=[
                    ("listing_risk", "Listing risk"),
                    ("application_score", "Application score"),
                ],
                max_length=32,
            ),
        ),
    ]
