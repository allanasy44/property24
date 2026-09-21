from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("rentals", "0024_agent_landlord_listing_intent")]

    operations = [
        migrations.AddField(
            model_name="verificationrequest",
            name="document_fingerprint",
            field=models.CharField(blank=True, db_index=True, max_length=128),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="extracted_date_of_birth",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="extracted_full_name",
            field=models.CharField(blank=True, max_length=160),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="ocr_confidence",
            field=models.CharField(blank=True, max_length=32),
        ),
    ]