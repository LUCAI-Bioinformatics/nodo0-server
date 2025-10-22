#!/usr/bin/env bash
set -euo pipefail

# Restores Caddy certificates from backup archive
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
BACKUP_DIR="$ROOT_DIR/backups"
CERTS_DIR="$ROOT_DIR/caddy"

BACKUP_FILE="$1"

if [[ -z "${BACKUP_FILE:-}" ]]; then
  # No file provided, use most recent
  BACKUP_FILE=$(ls -t "$BACKUP_DIR"/caddy-data-*.tar.gz 2>/dev/null | head -1)
  if [[ -z "$BACKUP_FILE" ]]; then
    echo "ERROR: No backup files found in $BACKUP_DIR"
    exit 1
  fi
  echo "Using most recent backup: $BACKUP_FILE"
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: Backup file $BACKUP_FILE does not exist"
  exit 1
fi

echo "Restoring Caddy certificates from $BACKUP_FILE..."

# Backup current data if it exists
if [[ -d "$CERTS_DIR/data" ]]; then
  TEMP_BACKUP="$CERTS_DIR/data.backup-$(date -u +"%Y%m%d-%H%M%SZ")"
  echo "Creating temporary backup of current data: $TEMP_BACKUP"
  mv "$CERTS_DIR/data" "$TEMP_BACKUP"
fi

# Extract backup
tar -xzf "$BACKUP_FILE" -C "$CERTS_DIR"

echo "Restore complete. Fixing permissions..."
"$ROOT_DIR/scripts/perms_fix.sh"
