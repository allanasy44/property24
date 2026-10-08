from django.db import migrations


def disable_seed_admin(apps, schema_editor):
    User = apps.get_model("rentals", "User")
    User.objects.filter(
        username="admin@property24.test",
        role="admin",
        is_superuser=True,
    ).update(is_active=False)


class Migration(migrations.Migration):
    dependencies = [("rentals", "0037_student_room_commercial_types")]

    operations = [
        migrations.RunPython(disable_seed_admin, migrations.RunPython.noop),
    ]
