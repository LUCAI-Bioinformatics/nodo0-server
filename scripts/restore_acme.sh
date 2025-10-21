#!/usr/bin/env bash
set -euo pipefail

# Restores traefik/config/acme.json from a backup file.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
ACME_FILE="$ROOT_DIR/traefik/config/acme.json"
BACKUP_DIR="$ROOT_DIR/backups"
SOURCE="${1:-}"

if [[ -z "$SOURCE" ]]; then
  if ! ls "$BACKUP_DIR"/acme-*.json >/dev/null 2>&1; then
    echo "No acme.json backups found in $BACKUP_DIR" >&2
    exit 1
  fi
  SOURCE="$(ls -1t "$BACKUP_DIR"/acme-*.json | head -n1)"
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Backup file '$SOURCE' does not exist" >&2
  exit 1
fi

cp "$SOURCE" "$ACME_FILE"
chmod 600 "$ACME_FILE"
echo "Restored $ACME_FILE from $SOURCE"
