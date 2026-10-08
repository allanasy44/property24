# Generated for hospitality and event venue listings.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0039_limit_support_admin"),
    ]

    operations = [
        migrations.AddField(
            model_name="property",
            name="listing_categories",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="property",
            name="listing_details",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AlterField(
            model_name="property",
            name="property_type",
            field=models.CharField(
                choices=[
                    ("house", "House"),
                    ("flat", "Flat"),
                    ("cottage", "Cottage"),
                    ("room", "Room"),
                    ("office", "Office"),
                    ("shop", "Shop"),
                    ("student_accommodation", "Student accommodation"),
                    ("commercial_property", "Commercial property"),
                    ("land", "Land / Stand"),
                    ("lodge", "Lodge"),
                    ("guest_house", "Guest house"),
                    ("hotel", "Hotel"),
                    ("holiday_home", "Holiday home"),
                    ("resort", "Resort"),
                    ("self_catering_apartment", "Self-catering apartment"),
                    ("camping_glamping", "Camping / glamping"),
                    ("wedding_venue", "Wedding venue"),
                    ("conference_venue", "Conference venue"),
                    ("party_venue", "Party venue"),
                    ("garden", "Garden"),
                    ("function_hall", "Function hall"),
                    ("corporate_event_space", "Corporate event space"),
                ],
                max_length=32,
            ),
        ),
    ]
