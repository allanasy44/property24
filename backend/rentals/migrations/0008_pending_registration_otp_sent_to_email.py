from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0007_pending_registration_otp"),
    ]

    operations = [
        migrations.AlterField(
            model_name="pendingregistrationotp",
            name="sent_to",
            field=models.CharField(max_length=254),
        ),
    ]
