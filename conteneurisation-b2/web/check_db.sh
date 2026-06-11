#!/usr/bin/env sh
set -eu

DB_HOST="${DB_HOST:-db}"
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-apppass}"
export PGPASSWORD="$DB_PASSWORD"

psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT id, message, created_at FROM messages ORDER BY id;"
