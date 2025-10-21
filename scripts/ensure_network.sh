#!/usr/bin/env bash
set -euo pipefail

# Ensures the external Docker network used by Traefik exists.
NETWORK_NAME="${TRAEFIK_DOCKER_NETWORK:-internal-nodo0-web}"

if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Network '$NETWORK_NAME' already present"
  exit 0
fi

echo "Creating Docker network '$NETWORK_NAME'"
docker network create "$NETWORK_NAME"
echo "Network '$NETWORK_NAME' ready"
