#!/usr/bin/env bash
set -euo pipefail

# Ensures traefik/config/acme.json exists with correct permissions.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
ACME_FILE="$ROOT_DIR/traefik/config/acme.json"

if [[ ! -f "$ACME_FILE" ]]; then
  touch "$ACME_FILE"
fi

chmod 600 "$ACME_FILE"
echo "Permissions on $ACME_FILE set to 600"
