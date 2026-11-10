import django.db.models.deletion
import django.utils.timezone
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("rentals", "0043_pendingregistrationotp_marketplace_capabilities_and_more")]
    operations = [migrations.CreateModel(
        name="PhoneLoginChallenge",
        fields=[
            ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
            ("destination", models.CharField(max_length=20)),
            ("purpose", models.CharField(default="login", max_length=24)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("expires_at", models.DateTimeField()),
            ("last_sent_at", models.DateTimeField(blank=True, null=True)),
            ("send_count", models.PositiveSmallIntegerField(default=0)),
            ("check_count", models.PositiveSmallIntegerField(default=0)),
            ("status", models.CharField(default="pending", max_length=16)),
            ("ip_hash", models.CharField(max_length=64)),
            ("checking", models.BooleanField(default=False)),
            ("user", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
        ],
        options={"indexes": [models.Index(fields=["destination", "created_at"], name="rentals_pho_destina_eaf595_idx"), models.Index(fields=["ip_hash", "created_at"], name="rentals_pho_ip_hash_3c87ec_idx")]},
    )]
