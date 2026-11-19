import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0045_conversation_hidden_by"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="UserPresenceSession",
            fields=[
                (
                    "session_id",
                    models.CharField(max_length=32, primary_key=True, serialize=False),
                ),
                (
                    "connected_at",
                    models.DateTimeField(default=django.utils.timezone.now),
                ),
                (
                    "last_ping_at",
                    models.DateTimeField(default=django.utils.timezone.now),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="presence_sessions",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
        ),
        migrations.AddIndex(
            model_name="userpresencesession",
            index=models.Index(
                fields=["user", "last_ping_at"],
                name="presence_user_last_ping_idx",
            ),
        ),
    ]
