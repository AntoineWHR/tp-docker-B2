#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

echo "Etat des conteneurs:"
docker compose ps

echo
echo "Reponses du load balancer:"
for i in $(seq 1 6); do
  html="$(curl -fsS http://localhost:8080)"
  echo "$html" | grep -Eo 'Serveur Web [12]' | head -n 1 || echo "Reponse recue sans titre attendu"
done
