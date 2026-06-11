#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

mkdir -p ssh
if [ ! -f ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -f ssh/id_ed25519 -N "" -C "b2-backup-key" >/dev/null
  echo "Cle SSH creee dans ./ssh"
else
  echo "Cle SSH deja presente dans ./ssh"
fi
chmod 700 ssh
chmod 600 ssh/id_ed25519
chmod 644 ssh/id_ed25519.pub
