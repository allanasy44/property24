from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("rentals", "0011_message_attachments"),
    ]

    operations = [
        migrations.CreateModel(
            name="SecurityAuditEvent",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("category", models.CharField(choices=[("authentication", "Authentication"), ("authorization", "Authorization"), ("chat", "Chat"), ("presence", "Presence"), ("rate_limit", "Rate limit"), ("system", "System")], max_length=32)),
                ("event_type", models.CharField(max_length=80)),
                ("severity", models.CharField(choices=[("info", "Info"), ("low", "Low"), ("medium", "Medium"), ("high", "High"), ("critical", "Critical")], default="info", max_length=16)),
                ("ip_address", models.GenericIPAddressField(blank=True, null=True)),
                ("user_agent", models.CharField(blank=True, max_length=255)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("actor", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="security_audit_events", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "indexes": [
                    models.Index(fields=["category", "event_type", "created_at"], name="rentals_sec_categor_ea206d_idx"),
                    models.Index(fields=["actor", "created_at"], name="rentals_sec_actor_i_4996af_idx"),
                    models.Index(fields=["severity", "created_at"], name="rentals_sec_severit_bab0de_idx"),
                ],
            },
        ),
    ]
