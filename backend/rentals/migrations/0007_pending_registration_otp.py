from django.db import migrations, models


def normalize_phone(value):
    return "".join(ch for ch in str(value or "") if ch.isdigit())


def normalize_existing_contact_details(apps, schema_editor):
    User = apps.get_model("rentals", "User")
    seen_phones = set()
    seen_emails = set()
    for user in User.objects.order_by("id"):
        changed = False
        phone = normalize_phone(user.phone)
        if phone and phone in seen_phones:
            phone = ""
        if phone != (user.phone or ""):
            user.phone = phone
            changed = True
        if phone:
            seen_phones.add(phone)

        email = str(user.email or "").strip().lower()
        if email and email in seen_emails:
            email = ""
        if email != (user.email or ""):
            user.email = email
            changed = True
        if email:
            seen_emails.add(email)

        if changed:
            user.save(update_fields=["phone", "email"])

class Migration(migrations.Migration):

    dependencies = [
        ("rentals", "0006_user_profile_media"),
    ]

    operations = [
        migrations.CreateModel(
            name="PendingRegistrationOTP",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("username", models.CharField(max_length=150)),
                ("email", models.EmailField(blank=True, max_length=254)),
                ("phone", models.CharField(max_length=32)),
                ("full_name", models.CharField(blank=True, max_length=160)),
                ("role", models.CharField(choices=[("tenant", "Tenant"), ("landlord", "Landlord"), ("agent", "Estate Agent"), ("admin", "Administrator")], default="tenant", max_length=16)),
                ("password_hash", models.CharField(max_length=128)),
                ("code_hash", models.CharField(max_length=128)),
                ("sent_to", models.CharField(max_length=32)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("consumed", "Consumed"), ("expired", "Expired")], default="pending", max_length=16)),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("expires_at", models.DateTimeField()),
                ("consumed_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.RunPython(normalize_existing_contact_details, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="user",
            constraint=models.UniqueConstraint(condition=~models.Q(phone=""), fields=("phone",), name="unique_nonblank_user_phone"),
        ),
        migrations.AddConstraint(
            model_name="user",
            constraint=models.UniqueConstraint(condition=~models.Q(email=""), fields=("email",), name="unique_nonblank_user_email"),
        ),
        migrations.AddIndex(
            model_name="pendingregistrationotp",
            index=models.Index(fields=["phone", "status"], name="rentals_pen_phone_b3b792_idx"),
        ),
        migrations.AddIndex(
            model_name="pendingregistrationotp",
            index=models.Index(fields=["email", "status"], name="rentals_pen_email_5dc7fc_idx"),
        ),
        migrations.AddIndex(
            model_name="pendingregistrationotp",
            index=models.Index(fields=["username", "status"], name="rentals_pen_usernam_95df41_idx"),
        ),
    ]
