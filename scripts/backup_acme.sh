#!/usr/bin/env bash
set -euo pipefail

# Creates a timestamped backup copy of traefik/config/acme.json.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
ACME_FILE="$ROOT_DIR/traefik/config/acme.json"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
TARGET="$BACKUP_DIR/acme-$TIMESTAMP.json"

if [[ ! -f "$ACME_FILE" ]]; then
  echo "acme.json not found at $ACME_FILE" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
cp "$ACME_FILE" "$TARGET"
chmod 600 "$TARGET"
echo "Backup written to $TARGET"
