#!/usr/bin/env bash
set -euo pipefail

# Backs up Caddy certificates directory to timestamped archive
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CERTS_DIR="$ROOT_DIR/caddy/data"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%SZ")
BACKUP_FILE="$BACKUP_DIR/caddy-data-$TIMESTAMP.tar.gz"

if [[ ! -d "$CERTS_DIR" ]]; then
  echo "ERROR: $CERTS_DIR does not exist. Nothing to backup."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "Backing up Caddy certificates to $BACKUP_FILE..."
tar -czf "$BACKUP_FILE" -C "$ROOT_DIR/caddy" data

echo "Backup complete: $BACKUP_FILE"
ls -lh "$BACKUP_FILE"
