from getpass import getpass

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.management.base import BaseCommand, CommandError
from django.core.exceptions import ValidationError
from django.core.validators import validate_email


class Command(BaseCommand):
    help = "Securely create a private Property24 support administrator."

    def handle(self, *args, **options):
        User = get_user_model()
        username = input("Username or email: ").strip()
        email = input("Email: ").strip().lower()
        full_name = input("Full name: ").strip()
        if not username or not email or not full_name:
            raise CommandError("Username, email, and full name are required.")
        if len(username) > 150 or len(full_name) > 160:
            raise CommandError("Username or full name is too long.")
        try:
            validate_email(email)
        except ValidationError as exc:
            raise CommandError("Enter a valid email address.") from exc
        if User.objects.filter(username__iexact=username).exists():
            raise CommandError("That username is already in use.")
        if User.objects.filter(email__iexact=email).exists():
            raise CommandError("That email is already in use.")

        password = getpass("Password (hidden): ")
        confirmation = getpass("Confirm password (hidden): ")
        if password != confirmation:
            raise CommandError("Passwords do not match.")
        user = User(username=username, email=email, full_name=full_name)
        try:
            validate_password(password, user=user)
        except ValidationError as exc:
            raise CommandError("; ".join(exc.messages)) from exc
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            full_name=full_name,
            role=User.Roles.ADMIN,
        )
        self.stdout.write(self.style.SUCCESS(
            f"Support administrator '{user.username}' created."
        ))
