from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("rentals", "0034_property_available_from")]

    operations = [
        migrations.AlterField(
            model_name="viewing",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("confirmed", "Confirmed"),
                    ("rejected", "Rejected"),
                    ("completed", "Completed"),
                    ("cancelled", "Cancelled"),
                ],
                default="pending",
                max_length=16,
            ),
        ),
    ]
