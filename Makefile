SHELL := /usr/bin/env bash

PROJECT_ROOT := $(abspath .)

ENV_FILE := $(PROJECT_ROOT)/.env
COMPOSE  ?= docker compose --env-file $(ENV_FILE) -f caddy/docker-compose.yml

export CADDY_DOCKER_NETWORK ?= internal-nodo0-web

.PHONY: network up down restart logs certs.backup certs.restore perms check config ps validate

network:
	@./scripts/ensure_network.sh

up:
	@$(MAKE) perms
	@$(MAKE) network
	@mkdir -p logs
	@$(COMPOSE) up -d

down:
	@$(COMPOSE) down

restart:
	@$(MAKE) down
	@$(MAKE) up

logs:
	@if [ -n "$(FILE)" ]; then \
		mkdir -p logs; \
		$(COMPOSE) logs --no-color caddy > "$(FILE)"; \
		echo "Logs saved to $(FILE)"; \
	else \
		$(COMPOSE) logs -f caddy; \
	fi

certs.backup:
	@./scripts/backup_certs.sh

certs.restore:
	@if [ -n "$(FILE)" ]; then \
		./scripts/restore_certs.sh "$(FILE)"; \
	else \
		./scripts/restore_certs.sh; \
	fi

perms:
	@./scripts/perms_fix.sh

check:
	@test -d caddy/data || (echo "Missing caddy/data directory" && exit 1)
	@test -f caddy/Caddyfile || (echo "Missing caddy/Caddyfile" && exit 1)
	@docker network inspect $${CADDY_DOCKER_NETWORK:-internal-nodo0-web} >/dev/null 2>&1 || (echo "Network $${CADDY_DOCKER_NETWORK:-internal-nodo0-web} not found" && exit 1)
	@echo "Configuration is ready to start Caddy"

validate:
	@$(COMPOSE) run --rm caddy caddy validate --config /etc/caddy/Caddyfile

config:
	@$(COMPOSE) config

ps:
	@$(COMPOSE) ps
