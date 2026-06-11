#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

docker compose exec -T backup-client /usr/local/bin/restore_latest.sh

echo
echo "Pour importer aussi le dump dans PostgreSQL:"
echo "docker compose exec -e CONFIRM_DB_RESTORE=yes backup-client /usr/local/bin/restore_latest.sh"
