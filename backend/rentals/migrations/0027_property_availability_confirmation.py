from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("rentals", "0026_verification_private_paths")]

    operations = [
        migrations.AddField(
            model_name="property",
            name="availability_confirmed_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
