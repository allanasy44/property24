from django.db import migrations, models

from rentals.models import verification_document_path


class Migration(migrations.Migration):
    dependencies = [("rentals", "0025_verification_quality_fields")]

    operations = [
        migrations.AlterField(model_name="verificationrequest", name="proof_of_address_document", field=models.FileField(blank=True, upload_to=verification_document_path)),
        migrations.AlterField(model_name="verificationrequest", name="id_front_document", field=models.FileField(blank=True, upload_to=verification_document_path)),
        migrations.AlterField(model_name="verificationrequest", name="id_back_document", field=models.FileField(blank=True, upload_to=verification_document_path)),
        migrations.AlterField(model_name="verificationrequest", name="liveness_document", field=models.FileField(blank=True, upload_to=verification_document_path)),
        migrations.AlterField(model_name="verificationrequest", name="selfie_document", field=models.FileField(blank=True, upload_to=verification_document_path)),
        migrations.AlterField(model_name="verificationrequest", name="ownership_or_authorization_document", field=models.FileField(blank=True, upload_to=verification_document_path)),
    ]