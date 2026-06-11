#!/usr/bin/env bash
set -Eeuo pipefail

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-sftp:backup@backup:/backups/restic-repo}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-ChangeMe_Restic_B2}"
SSH_KEY="${SSH_KEY:-/ssh/id_ed25519}"
RESTORE_TARGET="${RESTORE_TARGET:-/restore/latest}"
POSTGRES_HOST="${POSTGRES_HOST:-db}"
POSTGRES_DB="${POSTGRES_DB:-appdb}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-apppass}"
export RESTIC_REPOSITORY RESTIC_PASSWORD PGPASSWORD="$POSTGRES_PASSWORD"
export RESTIC_SFTP_COMMAND="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/root/.ssh/known_hosts"

mkdir -p /root/.ssh /restore
chmod 700 /root/.ssh
ssh-keyscan -H backup >/root/.ssh/known_hosts 2>/dev/null || true
chmod 600 /root/.ssh/known_hosts || true

rm -rf "$RESTORE_TARGET"
mkdir -p "$RESTORE_TARGET"
restic restore latest --target "$RESTORE_TARGET" --tag b2

echo "Restauration fichiers effectuee dans: $RESTORE_TARGET"
find "$RESTORE_TARGET" -maxdepth 4 -type f | sort

if [ "${CONFIRM_DB_RESTORE:-no}" = "yes" ]; then
  dump_file="$(find "$RESTORE_TARGET" -type f -name "${POSTGRES_DB}.dump" | head -n 1)"
  if [ -z "$dump_file" ]; then
    echo "Dump PostgreSQL introuvable dans la restauration" >&2
    exit 1
  fi
  pg_restore -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists "$dump_file"
  echo "Base PostgreSQL restauree depuis: $dump_file"
else
  echo "Base non importee. Pour restaurer la base: CONFIRM_DB_RESTORE=yes /usr/local/bin/restore_latest.sh"
fi
