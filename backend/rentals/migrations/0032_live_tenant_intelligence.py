from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0031_notification"),
    ]

    operations = [
        migrations.CreateModel(
            name="NeighborhoodProfile",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("city", models.CharField(max_length=100)),
                ("suburb", models.CharField(max_length=100)),
                ("water_reliability", models.PositiveSmallIntegerField(blank=True, null=True, validators=[MinValueValidator(0), MaxValueValidator(100)])),
                ("safety_score", models.PositiveSmallIntegerField(blank=True, null=True, validators=[MinValueValidator(0), MaxValueValidator(100)])),
                ("commute_to_cbd_minutes", models.PositiveSmallIntegerField(blank=True, null=True)),
                ("amenities", models.JSONField(blank=True, default=list)),
                ("source_name", models.CharField(blank=True, max_length=120)),
                ("source_url", models.URLField(blank=True)),
                ("verified_at", models.DateTimeField(blank=True, null=True)),
                ("expires_at", models.DateTimeField(blank=True, null=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.CreateModel(
            name="SavedSearch",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=80)),
                ("query", models.CharField(max_length=500)),
                ("criteria", models.JSONField(blank=True, default=dict)),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("tenant", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="saved_searches", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-updated_at"]},
        ),
        migrations.CreateModel(
            name="PropertyComparison",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("property", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="comparison_entries", to="rentals.property")),
                ("tenant", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="property_comparisons", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["created_at"]},
        ),
        migrations.CreateModel(
            name="SavedSearchMatch",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("match_score", models.PositiveSmallIntegerField(default=0)),
                ("first_matched_at", models.DateTimeField(auto_now_add=True)),
                ("last_matched_at", models.DateTimeField(auto_now=True)),
                ("property", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="saved_search_matches", to="rentals.property")),
                ("saved_search", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="matches", to="rentals.savedsearch")),
            ],
        ),
        migrations.AddConstraint(
            model_name="neighborhoodprofile",
            constraint=models.UniqueConstraint(fields=("city", "suburb"), name="unique_neighborhood_city_suburb"),
        ),
        migrations.AddConstraint(
            model_name="savedsearch",
            constraint=models.UniqueConstraint(fields=("tenant", "query"), name="unique_tenant_saved_search_query"),
        ),
        migrations.AddConstraint(
            model_name="propertycomparison",
            constraint=models.UniqueConstraint(fields=("tenant", "property"), name="unique_tenant_property_comparison"),
        ),
        migrations.AddConstraint(
            model_name="savedsearchmatch",
            constraint=models.UniqueConstraint(fields=("saved_search", "property"), name="unique_saved_search_property_match"),
        ),
        migrations.AddIndex(
            model_name="neighborhoodprofile",
            index=models.Index(fields=["city", "suburb"], name="rentals_nei_city_3d22d5_idx"),
        ),
        migrations.AddIndex(
            model_name="savedsearch",
            index=models.Index(fields=["tenant", "is_active", "-updated_at"], name="rentals_sav_tenant_95bb2b_idx"),
        ),
        migrations.AddIndex(
            model_name="propertycomparison",
            index=models.Index(fields=["tenant", "created_at"], name="rentals_pro_tenant_35739d_idx"),
        ),
        migrations.AddIndex(
            model_name="savedsearchmatch",
            index=models.Index(fields=["saved_search", "-match_score"], name="rentals_sav_search_7e97f3_idx"),
        ),
        migrations.AddIndex(
            model_name="savedsearchmatch",
            index=models.Index(fields=["property", "-last_matched_at"], name="rentals_sav_property_5281c9_idx"),
        ),
    ]
