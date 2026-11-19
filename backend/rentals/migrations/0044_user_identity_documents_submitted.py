from django.conf import settings
from django.db import migrations, models


def mark_existing_identity_documents(apps, schema_editor):
    User = apps.get_model(*settings.AUTH_USER_MODEL.split("."))
    VerificationRequest = apps.get_model("rentals", "VerificationRequest")
    users_with_documents = VerificationRequest.objects.filter(
        id_front_document__gt="",
        id_back_document__gt="",
    ).values("user_id")
    User.objects.filter(pk__in=users_with_documents).update(
        identity_documents_submitted=True,
    )


class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0043_pendingregistrationotp_marketplace_capabilities_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="identity_documents_submitted",
            field=models.BooleanField(default=False),
        ),
        migrations.RunPython(
            mark_existing_identity_documents,
            migrations.RunPython.noop,
        ),
    ]
