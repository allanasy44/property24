from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0009_propertycomment"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="last_seen_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
