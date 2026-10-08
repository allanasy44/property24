from django.db import migrations


def limit_support_admin_access(apps, schema_editor):
    User = apps.get_model("rentals", "User")
    User.objects.filter(role="admin").update(is_staff=False, is_superuser=False)


class Migration(migrations.Migration):
    dependencies = [
        ("rentals", "0038_disable_seed_admin"),
    ]

    operations = [
        migrations.RunPython(limit_support_admin_access, migrations.RunPython.noop),
    ]
