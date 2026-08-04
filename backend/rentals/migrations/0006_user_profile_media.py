from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0005_supplierfollow"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="bio",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="user",
            name="cover_photo",
            field=models.ImageField(blank=True, upload_to="accounts/cover-photos/"),
        ),
        migrations.AddField(
            model_name="user",
            name="cover_photo_url",
            field=models.URLField(blank=True),
        ),
        migrations.AddField(
            model_name="user",
            name="profile_picture",
            field=models.ImageField(blank=True, upload_to="accounts/profile-pictures/"),
        ),
        migrations.AddField(
            model_name="user",
            name="profile_picture_url",
            field=models.URLField(blank=True),
        ),
    ]
