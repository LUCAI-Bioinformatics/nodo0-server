#!/usr/bin/env bash
set -euo pipefail

# Script de monitoreo continuo para Caddy
# Uso: ./scripts/monitor.sh [intervalo_segundos]

INTERVAL="${1:-5}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
LOG_DIR="$ROOT_DIR/logs"

echo " Monitoreando Caddy cada ${INTERVAL} segundos..."
echo " Logs: $LOG_DIR"
echo "  Presiona Ctrl+C para salir"
echo ""

while true; do
    clear
    echo "=========================================="
    echo " ESTADO DE CADDY - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""

    # Estado del contenedor
    echo "🐳 CONTENEDOR:"
    if docker ps --filter "name=caddy_nodo0" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q caddy_nodo0; then
        docker ps --filter "name=caddy_nodo0" --format "table {{.Names}}\t{{.Status}}"
        echo " Caddy está corriendo"
    else
        echo " Caddy NO está corriendo"
        echo "   Inicia con: make up"
    fi
    echo ""

    # Health check
    echo " HEALTH CHECK:"
    if docker inspect caddy_nodo0 2>/dev/null | grep -q '"Health"'; then
        HEALTH=$(docker inspect caddy_nodo0 --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        case "$HEALTH" in
            "healthy")
                echo " Estado: HEALTHY"
                ;;
            "unhealthy")
                echo " Estado: UNHEALTHY"
                ;;
            "starting")
                echo " Estado: STARTING..."
                ;;
            *)
                echo "  Estado: $HEALTH"
                ;;
        esac
    else
        echo "  No health check configurado"
    fi
    echo ""

    # Errores recientes
    echo " ERRORES RECIENTES (últimos 5):"
    if [[ -f "$LOG_DIR/error.log" ]]; then
        ERROR_COUNT=$(wc -l < "$LOG_DIR/error.log" 2>/dev/null || echo "0")
        if [[ "$ERROR_COUNT" -gt 0 ]]; then
            echo "  Total de errores registrados: $ERROR_COUNT"
            tail -n 5 "$LOG_DIR/error.log" | jq -r '"\(.ts) | \(.level) | \(.msg)"' 2>/dev/null || tail -n 5 "$LOG_DIR/error.log"
        else
            echo " No hay errores registrados"
        fi
    else
        echo " No hay errores registrados"
    fi
    echo ""

    # Certificados ACME recientes
    echo " CERTIFICADOS (últimos 3 eventos):"
    if [[ -f "$LOG_DIR/caddy-debug.log" ]]; then
        grep -i 'certificate\|acme\|obtain' "$LOG_DIR/caddy-debug.log" 2>/dev/null | tail -n 3 | jq -r '"\(.ts) | \(.msg)"' 2>/dev/null || \
        grep -i 'certificate\|acme\|obtain' "$LOG_DIR/caddy-debug.log" 2>/dev/null | tail -n 3 || \
        echo "ℹ  No hay eventos de certificados todavía"
    else
        echo "ℹ  No hay logs de debug todavía"
    fi
    echo ""

    # Servicios descubiertos
    echo " SERVICIOS AUTO-DESCUBIERTOS:"
    docker ps --filter "label=caddy" --format "table {{.Names}}\t{{.Labels}}" 2>/dev/null | grep -v "caddy_nodo0" | head -n 10 || echo "ℹ  No hay servicios con labels caddy"
    echo ""

    # Uso de recursos
    echo " RECURSOS:"
    docker stats caddy_nodo0 --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "  No disponible"
    echo ""

    echo "=========================================="
    echo " Próxima actualización en ${INTERVAL}s..."
    sleep "$INTERVAL"
done
