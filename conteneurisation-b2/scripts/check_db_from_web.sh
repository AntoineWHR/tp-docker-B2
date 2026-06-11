#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

echo "Requete DB depuis web1:"
docker compose exec -T web1 /usr/local/bin/check_db.sh

echo "Requete DB depuis web2:"
docker compose exec -T web2 /usr/local/bin/check_db.sh
