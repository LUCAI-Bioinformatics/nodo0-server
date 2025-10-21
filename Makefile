SHELL := /usr/bin/env bash

PROJECT_ROOT := $(abspath .)

ENV_FILE := $(PROJECT_ROOT)/.env
COMPOSE  ?= docker compose --env-file $(ENV_FILE) -f traefik/docker-compose.yml

export TRAEFIK_DOCKER_NETWORK ?= internal-nodo0-web

.PHONY: network up down restart logs acme.backup acme.restore perms check config ps

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
		$(COMPOSE) logs --no-color traefik > "$(FILE)"; \
		echo "Logs saved to $(FILE)"; \
	else \
		$(COMPOSE) logs -f traefik; \
	fi

acme.backup:
	@./scripts/backup_acme.sh

acme.restore:
	@if [ -n "$(FILE)" ]; then \
		./scripts/restore_acme.sh "$(FILE)"; \
	else \
		./scripts/restore_acme.sh; \
	fi

perms:
	@./scripts/perms_fix.sh

check:
	@test -f traefik/config/acme.json || (echo "Missing traefik/config/acme.json" && exit 1)
	@chmod 600 traefik/config/acme.json
	@docker network inspect $${TRAEFIK_DOCKER_NETWORK:-internal-nodo0-web} >/dev/null 2>&1 || (echo "Network $${TRAEFIK_DOCKER_NETWORK:-internal-nodo0-web} not found" && exit 1)
	@echo "Configuration is ready to start Traefik"

config:
	@$(COMPOSE) config

ps:
	@$(COMPOSE) ps
