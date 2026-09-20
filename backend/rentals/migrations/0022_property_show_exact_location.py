from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0021_property_area_sqft"),
    ]

    operations = [
        migrations.AddField(
            model_name="property",
            name="show_exact_location",
            field=models.BooleanField(default=False),
        ),
    ]
