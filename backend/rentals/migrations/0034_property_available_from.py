from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("rentals", "0033_propertylike")]

    operations = [
        migrations.AddField(
            model_name="property",
            name="available_from",
            field=models.DateField(blank=True, null=True),
        ),
    ]
