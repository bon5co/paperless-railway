"""Create the Paperless superuser, or re-apply its credential on a later boot.

Run through `manage.py shell`, so Django's settings and app registry are ready.
Upstream's `manage_superuser` command cannot do this: it returns early when the
username exists or when any superuser exists.
"""

import os

from django.contrib.auth.models import User

username = os.environ.get("PAPERLESS_ADMIN_USER", "admin")
secret = os.environ.get("PAPERLESS_ADMIN_PASSWORD", "")
mail = os.environ.get("PAPERLESS_ADMIN_MAIL", "root@localhost")

if not secret:
    raise SystemExit("[init-superuser] PAPERLESS_ADMIN_PASSWORD is empty")

user, created = User.objects.get_or_create(
    username=username,
    defaults={"email": mail, "is_staff": True, "is_superuser": True},
)
user.email = mail
user.is_staff = True
user.is_superuser = True
user.is_active = True
user.set_password(secret)
user.save()

print(f"[init-superuser] {'created' if created else 'updated'} superuser {username!r}")
