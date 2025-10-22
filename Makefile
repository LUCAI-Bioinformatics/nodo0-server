SHELL := /usr/bin/env bash

PROJECT_ROOT := $(abspath .)

ENV_FILE := $(PROJECT_ROOT)/.env
COMPOSE  ?= docker compose --env-file $(ENV_FILE) -f caddy/docker-compose.yml

export CADDY_DOCKER_NETWORK ?= internal-nodo0-web

.PHONY: network up down restart logs logs.debug logs.error logs.acme logs.discovery logs.live logs.tail logs.follow logs.all monitor diagnose certs.backup certs.restore perms check config ps validate

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

# ========== LOGS COMMANDS ==========
# Logs generales del contenedor Docker
logs:
	@if [ -n "$(FILE)" ]; then \
		mkdir -p logs; \
		$(COMPOSE) logs --no-color caddy > "$(FILE)"; \
		echo "Logs saved to $(FILE)"; \
	else \
		$(COMPOSE) logs -f caddy; \
	fi

# Ver TODOS los logs de debug (incluye ACME, errores, discovery)
logs.debug:
	@echo " Mostrando logs de DEBUG (incluye ACME, discovery, errores)..."
	@tail -f logs/caddy-debug.log 2>/dev/null || echo "  No hay logs todavía. Inicia Caddy con 'make up'"

# Ver SOLO errores críticos
logs.error:
	@echo " Mostrando SOLO errores críticos..."
	@tail -f logs/error.log 2>/dev/null || echo " No hay errores registrados aún"

# Ver SOLO eventos ACME (certificados)
logs.acme:
	@echo " Filtrando logs de certificados ACME/Let's Encrypt..."
	@tail -f logs/caddy-debug.log 2>/dev/null | grep -i --line-buffered 'acme\|certificate\|tls\|obtain' || echo "  No hay logs de ACME todavía"

# Ver SOLO eventos de Docker discovery
logs.discovery:
	@echo " Filtrando logs de auto-discovery Docker..."
	@tail -f logs/caddy-debug.log 2>/dev/null | grep -i --line-buffered 'docker\|discovery\|container\|label' || echo "  No hay logs de discovery todavía"

# Ver logs en vivo del contenedor Docker (stdout/stderr)
logs.live:
	@echo "📺 Logs en vivo del contenedor Caddy (Ctrl+C para salir)..."
	@$(COMPOSE) logs -f --tail=100 caddy

# Alias corto para logs.debug
logs.tail:
	@$(MAKE) logs.debug

# Alias para logs.live
logs.follow:
	@$(MAKE) logs.live

# Ver TODOS los tipos de logs al mismo tiempo (multi-window)
logs.all:
	@echo " Abriendo múltiples vistas de logs..."
	@echo "   Terminal 1: Debug general"
	@echo "   Terminal 2: Errores"
	@echo "   Terminal 3: ACME/Certificados"
	@echo "   Terminal 4: Docker Discovery"
	@echo ""
	@echo " Tip: Usa 'tmux' o abre 4 terminales y ejecuta:"
	@echo "   make logs.debug"
	@echo "   make logs.error"
	@echo "   make logs.acme"
	@echo "   make logs.discovery"

# Monitor en tiempo real (dashboard interactivo)
monitor:
	@./scripts/monitor.sh

# Generar reporte de diagnóstico completo
diagnose:
	@./scripts/diagnose.sh

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
