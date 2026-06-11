#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

docker compose down -v --remove-orphans
rm -rf ssh/id_ed25519 ssh/id_ed25519.pub
