from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0044_user_identity_documents_submitted"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="conversation",
            name="hidden_by",
            field=models.ManyToManyField(
                blank=True,
                related_name="hidden_conversations",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
