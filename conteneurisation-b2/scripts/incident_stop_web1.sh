#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

start_ms="$(date +%s%3N)"
echo "Incident: arret du serveur web1"
docker compose stop web1 >/dev/null

until curl -fsS http://localhost:8080 >/tmp/b2_lb_response.html 2>/dev/null; do
  sleep 1
done
end_ms="$(date +%s%3N)"
rto_ms=$((end_ms - start_ms))

echo "Service disponible via le load balancer. RTO mesure: ${rto_ms} ms"
grep -Eo 'Serveur Web [12]' /tmp/b2_lb_response.html | head -n 1 || true

echo "RPO web: 0 donnee perdue pour cet incident, car aucune restauration n'est necessaire."

if [ "${KEEP_DOWN:-no}" != "yes" ]; then
  docker compose start web1 >/dev/null
  echo "web1 redemarre. Utilisez KEEP_DOWN=yes pour le laisser arrete."
fi
