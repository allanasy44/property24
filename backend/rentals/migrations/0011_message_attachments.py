from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0010_user_last_seen_at"),
    ]

    operations = [
        migrations.AddField(
            model_name="message",
            name="attachment",
            field=models.FileField(blank=True, upload_to="conversations/attachments/"),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_url",
            field=models.URLField(blank=True),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_type",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_name",
            field=models.CharField(blank=True, max_length=180),
        ),
    ]
