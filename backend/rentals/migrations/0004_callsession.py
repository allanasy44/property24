from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0003_google_auth_fields"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="CallSession",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("mode", models.CharField(choices=[("voice", "Voice"), ("video", "Video")], max_length=12)),
                ("status", models.CharField(choices=[("ringing", "Ringing"), ("ended", "Ended"), ("missed", "Missed")], default="ringing", max_length=12)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("ended_at", models.DateTimeField(blank=True, null=True)),
                ("conversation", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="call_sessions", to="rentals.conversation")),
                ("initiator", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="started_call_sessions", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
    ]
