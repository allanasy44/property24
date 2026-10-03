from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("rentals", "0032_live_tenant_intelligence"),
    ]

    operations = [
        migrations.CreateModel(
            name="PropertyLike",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "property",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="likes",
                        to="rentals.property",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="property_likes",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "indexes": [
                    models.Index(
                        fields=["property", "created_at"],
                        name="rentals_pro_property_2cae0c_idx",
                    ),
                ],
                "constraints": [
                    models.UniqueConstraint(
                        fields=("property", "user"),
                        name="unique_property_like_per_user",
                    ),
                ],
            },
        ),
    ]
