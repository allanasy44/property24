# Generated for Property24 in-app listing comments.

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("rentals", "0008_pending_registration_otp_sent_to_email"),
    ]

    operations = [
        migrations.CreateModel(
            name="PropertyComment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("body", models.TextField()),
                ("media_url", models.URLField(blank=True)),
                ("likes_count", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("author", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="property_comments", to=settings.AUTH_USER_MODEL)),
                ("parent", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="replies", to="rentals.propertycomment")),
                ("property", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="comments", to="rentals.property")),
            ],
            options={
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(fields=["property", "-created_at"], name="rentals_pro_propert_65bdc2_idx"),
                    models.Index(fields=["author", "-created_at"], name="rentals_pro_author__249a04_idx"),
                ],
            },
        ),
    ]
