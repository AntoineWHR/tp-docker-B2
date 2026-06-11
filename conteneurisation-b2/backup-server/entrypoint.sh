#!/usr/bin/env sh
set -eu

if ! id backup >/dev/null 2>&1; then
  adduser -D -h /home/backup -s /bin/sh backup
fi

mkdir -p /run/sshd /home/backup/.ssh /backups/restic-repo

if [ -f /ssh/id_ed25519.pub ]; then
  cp /ssh/id_ed25519.pub /home/backup/.ssh/authorized_keys
else
  echo "Cle publique absente: lancez scripts/setup_ssh_keys.sh avant docker compose up" >&2
  touch /home/backup/.ssh/authorized_keys
fi

chown -R backup:backup /home/backup/.ssh /backups
chmod 700 /home/backup/.ssh /backups
chmod 600 /home/backup/.ssh/authorized_keys

ssh-keygen -A >/dev/null

# Durcissement SSH minimal pour le projet: pas de mot de passe, pas de root, seul l'utilisateur backup.
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
if ! grep -q '^AllowUsers backup' /etc/ssh/sshd_config; then
  echo 'AllowUsers backup' >> /etc/ssh/sshd_config
fi

exec /usr/sbin/sshd -D -e
