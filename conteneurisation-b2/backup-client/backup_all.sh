#!/usr/bin/env bash
set -Eeuo pipefail

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-sftp:backup@backup:/backups/restic-repo}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-ChangeMe_Restic_B2}"
SSH_KEY="${SSH_KEY:-/ssh/id_ed25519}"
POSTGRES_HOST="${POSTGRES_HOST:-db}"
POSTGRES_DB="${POSTGRES_DB:-appdb}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-apppass}"
export RESTIC_REPOSITORY RESTIC_PASSWORD PGPASSWORD="$POSTGRES_PASSWORD"
export RESTIC_SFTP_COMMAND="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/root/.ssh/known_hosts"

mkdir -p /root/.ssh /tmp/backup/db
chmod 700 /root/.ssh

# Attend que le serveur SSH de sauvegarde reponde puis enregistre sa cle hote.
for attempt in $(seq 1 30); do
  if ssh-keyscan -H backup >/root/.ssh/known_hosts 2>/dev/null; then
    break
  fi
  sleep 1
  if [ "$attempt" -eq 30 ]; then
    echo "Impossible de joindre le serveur SSH de sauvegarde" >&2
    exit 1
  fi
done
chmod 600 /root/.ssh/known_hosts

# Initialise le depot Restic si c'est la premiere execution.
if ! restic snapshots >/dev/null 2>&1; then
  restic init
fi

# Sauvegarde logique de la base PostgreSQL.
pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -F c -f "/tmp/backup/db/${POSTGRES_DB}.dump"
date --iso-8601=seconds > /tmp/backup/backup_time.txt

# Sauvegarde des pages web et du dump de base.
restic backup \
  /data/web1 \
  /data/web2 \
  /tmp/backup/db \
  /tmp/backup/backup_time.txt \
  --tag b2 \
  --tag web \
  --tag db

# Politique de retention simple pour eviter une croissance infinie.
restic forget --keep-last 10 --prune --tag b2

echo "Sauvegarde terminee: $(date --iso-8601=seconds)"
