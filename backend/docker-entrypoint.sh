#!/bin/sh
set -eu

attempt=1
max_attempts="${DB_STARTUP_MAX_ATTEMPTS:-30}"

until python manage.py migrate --noinput; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "Database was not ready after ${max_attempts} attempts." >&2
    exit 1
  fi

  echo "Database is not ready; retrying in 2 seconds (attempt ${attempt}/${max_attempts})." >&2
  attempt=$((attempt + 1))
  sleep 2
done

python manage.py collectstatic --noinput
exec "$@"
