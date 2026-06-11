#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Fichier .env cree depuis .env.example"
fi

set -a
. ./.env
set +a

bash scripts/setup_ssh_keys.sh
docker compose up -d --build

echo "Verification de PostgreSQL..."
until docker compose exec -T db pg_isready -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-appdb}" >/dev/null 2>&1; do
  sleep 1
done

echo "Lancement d'une premiere sauvegarde manuelle..."
docker compose exec -T backup-client /usr/local/bin/backup_all.sh

echo "Projet demarre. Application: http://localhost:8080"
