#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

echo "Incident: arret de la base PostgreSQL"
docker compose stop db >/dev/null

if curl -fsS http://localhost:8080 >/tmp/b2_lb_response.html 2>/dev/null; then
  echo "Les pages web statiques restent disponibles via le load balancer."
  grep -Eo 'Serveur Web [12]' /tmp/b2_lb_response.html | head -n 1 || true
else
  echo "Le front web ne repond pas."
fi

echo "Verification DB depuis web1: l'echec est attendu tant que la base est arretee."
docker compose exec -T web1 /usr/local/bin/check_db.sh || true

echo "RPO base: au maximum l'intervalle cron configure, soit 5 minutes, sauf sauvegarde manuelle plus recente."

if [ "${KEEP_DOWN:-no}" != "yes" ]; then
  docker compose start db >/dev/null
  echo "db redemarree. Utilisez KEEP_DOWN=yes pour la laisser arretee."
fi
