#!/usr/bin/env bash

set -euo pipefail

: "${APP_DB_USER:?APP_DB_USER is required}"
: "${APP_DB_NAME:?APP_DB_NAME is required}"
: "${APP_TEST_DB_NAME:?APP_TEST_DB_NAME is required}"
: "${APP_DB_PASSWORD_FILE:?APP_DB_PASSWORD_FILE is required}"


if [ ! -r "$APP_DB_PASSWORD_FILE" ]; then

    echo "[ERROR] Application database password secret is not readable" >&2
    exit 1

fi


APP_DB_PASSWORD="$(cat "$APP_DB_PASSWORD_FILE")"

psql \
    -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --set=app_user="$APP_DB_USER" \
    --set=app_password="$APP_DB_PASSWORD" \
    --set=app_db="$APP_DB_NAME" \
    --set=test_db="$APP_TEST_DB_NAME" <<'EOSQL'

SELECT format(
    'CREATE ROLE %I LOGIN PASSWORD %L',
    :'app_user',
    :'app_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = :'app_user'
)
\gexec


SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'app_db',
    :'app_user'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = :'app_db'
)
\gexec


SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'test_db',
    :'app_user'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = :'test_db'
)
\gexec

EOSQL

unset APP_DB_PASSWORD
