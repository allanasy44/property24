from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("rentals", "0027_property_availability_confirmation")]

    operations = [
        migrations.AddField(
            model_name="property",
            name="stand_reference",
            field=models.CharField(blank=True, max_length=120),
        ),
        migrations.AddField(
            model_name="property",
            name="stands_available",
            field=models.PositiveIntegerField(default=1),
        ),
        migrations.AddField(
            model_name="property",
            name="land_size",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True),
        ),
        migrations.AddField(
            model_name="property",
            name="land_size_unit",
            field=models.CharField(blank=True, default="sqm", max_length=16),
        ),
        migrations.AddField(
            model_name="property",
            name="title_deed_status",
            field=models.CharField(blank=True, default="not_provided", max_length=40),
        ),
        migrations.AddField(
            model_name="property",
            name="servicing_status",
            field=models.CharField(blank=True, default="not_serviced", max_length=40),
        ),
        migrations.AddField(
            model_name="property",
            name="zoning",
            field=models.CharField(blank=True, max_length=120),
        ),
        migrations.AddField(
            model_name="property",
            name="road_access",
            field=models.CharField(blank=True, max_length=120),
        ),
        migrations.AddField(
            model_name="property",
            name="electricity_available",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="property",
            name="land_water_available",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="property",
            name="payment_terms",
            field=models.CharField(blank=True, max_length=240),
        ),
    ]
