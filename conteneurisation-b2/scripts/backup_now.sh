#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

docker compose exec -T backup-client /usr/local/bin/backup_all.sh

echo "Snapshots Restic disponibles:"
docker compose exec -T backup-client bash -lc 'mkdir -p /root/.ssh && ssh-keyscan -H backup >/root/.ssh/known_hosts 2>/dev/null || true; export RESTIC_SFTP_COMMAND="ssh -i /ssh/id_ed25519 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/root/.ssh/known_hosts"; restic snapshots --tag b2'
