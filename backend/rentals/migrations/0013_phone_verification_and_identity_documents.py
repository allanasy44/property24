# Generated for Property24 verification flow updates.

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("rentals", "0012_securityauditevent"),
    ]

    operations = [
        migrations.CreateModel(
            name="PhoneVerificationOTP",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("phone", models.CharField(max_length=32)),
                ("code_hash", models.CharField(max_length=128)),
                ("sent_to", models.CharField(max_length=32)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("verified", "Verified"), ("expired", "Expired")], default="pending", max_length=16)),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("expires_at", models.DateTimeField()),
                ("verified_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="phone_verification_otps", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="id_front_document",
            field=models.FileField(blank=True, upload_to="verification/id-front/"),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="id_back_document",
            field=models.FileField(blank=True, upload_to="verification/id-back/"),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="extracted_national_id_number",
            field=models.CharField(blank=True, max_length=64),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="identity_confirmed",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="verificationrequest",
            name="liveness_document",
            field=models.FileField(blank=True, upload_to="verification/liveness/"),
        ),
        migrations.AddIndex(
            model_name="phoneverificationotp",
            index=models.Index(fields=["user", "phone", "status"], name="rentals_pho_user_id_7aa62e_idx"),
        ),
        migrations.AddIndex(
            model_name="phoneverificationotp",
            index=models.Index(fields=["phone", "status"], name="rentals_pho_phone_14590b_idx"),
        ),
    ]
