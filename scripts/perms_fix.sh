#!/usr/bin/env bash
set -euo pipefail

# Ensures caddy/data directory exists with correct permissions.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CERTS_DIR="$ROOT_DIR/caddy/data"
CONFIG_DIR="$ROOT_DIR/caddy/config"

# Create directories if they don't exist
mkdir -p "$CERTS_DIR" "$CONFIG_DIR"

# Set proper ownership - Caddy runs as root in container but needs write access
chmod -R 755 "$CERTS_DIR" "$CONFIG_DIR"
echo "Permissions on Caddy directories set correctly"
