#!/usr/bin/env bash
set -euo pipefail

# Script de diagnóstico rápido para Caddy
# Recopila toda la info necesaria para debugging

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OUTPUT_DIR="$ROOT_DIR/diagnostics"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%SZ")
OUTPUT_FILE="$OUTPUT_DIR/diagnostic-$TIMESTAMP.txt"

echo " Recopilando información de diagnóstico..."
mkdir -p "$OUTPUT_DIR"

{
    echo "=========================================="
    echo "DIAGNÓSTICO CADDY - $(date)"
    echo "=========================================="
    echo ""

    echo "========== VERSIONES =========="
    echo "Docker:"
    docker --version
    echo ""
    echo "Docker Compose:"
    docker compose version
    echo ""
    echo "Caddy:"
    docker exec caddy_nodo0 caddy version 2>/dev/null || echo "Caddy no está corriendo"
    echo ""

    echo "========== ESTADO DEL CONTENEDOR =========="
    docker ps -a --filter "name=caddy_nodo0" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No encontrado"
    echo ""
    echo "Restart count:"
    docker inspect caddy_nodo0 --format='{{.RestartCount}}' 2>/dev/null || echo "N/A"
    echo ""

    echo "========== HEALTH CHECK =========="
    docker inspect caddy_nodo0 --format='Health Status: {{.State.Health.Status}}' 2>/dev/null || echo "No health check"
    docker inspect caddy_nodo0 --format='{{range .State.Health.Log}}{{.Output}}{{end}}' 2>/dev/null | tail -5 || true
    echo ""

    echo "========== RED DOCKER =========="
    docker network inspect internal-nodo0-web 2>/dev/null | head -50 || echo "Red no existe"
    echo ""

    echo "========== SERVICIOS CON LABELS CADDY =========="
    docker ps --filter "label=caddy" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" || echo "Ninguno"
    echo ""

    echo "========== ÚLTIMOS 20 LOGS DEL CONTENEDOR =========="
    docker logs caddy_nodo0 --tail=20 2>&1 || echo "No disponible"
    echo ""

    echo "========== ÚLTIMOS 10 ERRORES =========="
    if [[ -f "$ROOT_DIR/logs/error.log" ]]; then
        tail -n 10 "$ROOT_DIR/logs/error.log" || echo "Sin errores"
    else
        echo "No hay archivo error.log"
    fi
    echo ""

    echo "========== ÚLTIMOS 10 EVENTOS ACME =========="
    if [[ -f "$ROOT_DIR/logs/caddy-debug.log" ]]; then
        grep -i 'certificate\|acme' "$ROOT_DIR/logs/caddy-debug.log" 2>/dev/null | tail -n 10 || echo "Sin eventos ACME"
    else
        echo "No hay archivo caddy-debug.log"
    fi
    echo ""

    echo "========== CONFIGURACIÓN GENERADA =========="
    echo "Primeros 100 líneas de config:"
    docker exec caddy_nodo0 caddy config 2>/dev/null | head -100 || echo "No disponible"
    echo ""

    echo "========== CADDYFILE ACTUAL =========="
    cat "$ROOT_DIR/caddy/Caddyfile" 2>/dev/null || echo "No encontrado"
    echo ""

    echo "========== VARIABLES DE ENTORNO =========="
    if [[ -f "$ROOT_DIR/.env" ]]; then
        echo ".env existe (no mostrando contenido por seguridad)"
        grep -v "PASSWORD\|SECRET\|KEY" "$ROOT_DIR/.env" 2>/dev/null || true
    else
        echo ".env no existe"
    fi
    echo ""

    echo "========== PUERTOS EN USO =========="
    netstat -tuln | grep -E ':(80|443|8080|2019)\s' || echo "Ninguno de los puertos de Caddy"
    echo ""

    echo "========== USO DE RECURSOS =========="
    docker stats caddy_nodo0 --no-stream 2>/dev/null || echo "No disponible"
    echo ""

    echo "========== ESPACIO EN DISCO =========="
    df -h "$ROOT_DIR" | tail -1
    echo ""
    echo "Tamaño de logs:"
    du -sh "$ROOT_DIR/logs" 2>/dev/null || echo "No hay logs"
    echo ""
    echo "Tamaño de certificados:"
    du -sh "$ROOT_DIR/caddy/data" 2>/dev/null || echo "No hay data"
    echo ""

    echo "========== FIN DEL DIAGNÓSTICO =========="
    echo "Guardado en: $OUTPUT_FILE"

} > "$OUTPUT_FILE" 2>&1

echo " Diagnóstico completo guardado en:"
echo "   $OUTPUT_FILE"
echo ""
echo " Para compartir:"
echo "   cat $OUTPUT_FILE"
echo ""
echo " O comprimir:"
echo "   tar -czf diagnostic-$TIMESTAMP.tar.gz -C $OUTPUT_DIR diagnostic-$TIMESTAMP.txt logs/"
