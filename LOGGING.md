# Logging Intenso - Guía Completa

Sistema de logging comprehensivo para debugging y monitoreo de Caddy en nodo0.

##  Archivos de Log

Todos los logs viven en `logs/` con formato JSON y rotación automática.

### 1. **caddy-debug.log** - Log Principal (DEBUG level)

**Qué contiene**:
-  **Eventos ACME/Certificados**: Solicitudes, renovaciones, errores
-  **Auto-discovery Docker**: Detección de contenedores, labels, cambios
-  **Errores de red**: Timeouts, conexiones fallidas, DNS
-  **Proxy requests**: Headers, upstreams, redirects
-  **Configuración**: Cambios, reloads, validación
-  **TLS/HTTPS**: Handshakes, cipher suites, negociaciones

**Rotación**: 100MB por archivo, mantiene 10 archivos (~1GB total), 30 días

**Ver en tiempo real**:
```bash
make logs.debug
# o
tail -f logs/caddy-debug.log
```

**Buscar algo específico**:
```bash
# Certificados
grep -i certificate logs/caddy-debug.log

# Errores de red
grep -i "error\|fail\|timeout" logs/caddy-debug.log

# Auto-discovery
grep -i docker logs/caddy-debug.log
```

### 2. **error.log** - Solo Errores Críticos (ERROR level)

**Qué contiene**:
-  Errores fatales que requieren atención inmediata
-  Caídas de Caddy o panics
-  Problemas críticos de certificados (expirados, revocados)
-  Errores de configuración que impiden startup

**Rotación**: 50MB por archivo, mantiene 5 archivos

**Ver en tiempo real**:
```bash
make logs.error
```

**Si este archivo tiene contenido, hay problemas serios** 

### 3. **admin.log** - Endpoint Admin (DEBUG level)

**Qué contiene**:
- Accesos al endpoint `traefik.infra.cluster.qb.fcen.uba.ar`
- Intentos de autenticación (Basic Auth)
- Requests a `/health` y `/`

**Rotación**: 10MB por archivo, mantiene 3 archivos

**Ver**:
```bash
tail -f logs/admin.log
```

### 4. **Docker Container Logs** (stdout/stderr)

Logs del contenedor Docker en sí (no archivos en disco).

**Ver en tiempo real**:
```bash
make logs.live
# o
docker logs -f caddy_nodo0
```

**Guardar a archivo**:
```bash
make logs FILE=logs/snapshot-$(date +%Y%m%d-%H%M%S).log
```

##  Comandos de Log

### Comandos Principales

```bash
# Ver TODO (debug level) - incluye ACME, discovery, errores
make logs.debug

# Ver SOLO errores críticos
make logs.error

# Ver SOLO eventos de certificados/ACME
make logs.acme

# Ver SOLO auto-discovery Docker
make logs.discovery

# Ver logs en vivo del contenedor Docker
make logs.live

# Alias cortos
make logs.tail    # = logs.debug
make logs.follow  # = logs.live
```

### Monitor Interactivo

Dashboard en tiempo real que muestra:
- Estado del contenedor
- Health check
- Últimos errores
- Eventos ACME
- Servicios descubiertos
- Uso de recursos (CPU, RAM)

```bash
make monitor
```

Se actualiza cada 5 segundos. Presiona `Ctrl+C` para salir.

##  Eventos ACME/Certificados

### Qué buscar

**Solicitud de nuevo certificado**:
```bash
make logs.acme | grep "obtaining"
```

Verás algo como:
```json
{
  "level": "info",
  "ts": "2025-10-22T15:30:45Z",
  "msg": "obtaining certificate",
  "domain": "genphenia.infra.cluster.qb.fcen.uba.ar",
  "challenge_type": "http-01"
}
```

**Certificado obtenido exitosamente**:
```bash
make logs.acme | grep "certificate obtained"
```

**Errores de ACME**:
```bash
make logs.error | grep -i acme
```

**Renovación automática**:
```bash
make logs.acme | grep "renew"
```

### Debugging Problemas de Certificados

**Problema**: No se emite certificado

```bash
# 1. Ver qué está pasando con ACME
make logs.acme

# 2. Buscar errores específicos
grep -i "challenge\|fail" logs/caddy-debug.log | tail -20

# 3. Verificar DNS
dig +short genphenia.infra.cluster.qb.fcen.uba.ar

# 4. Probar HTTP-01 challenge manualmente
curl -I http://genphenia.infra.cluster.qb.fcen.uba.ar/.well-known/acme-challenge/test
```

**Problema**: Certificado staging (no confiable)

```bash
# Ver si dice "acme-staging" en los logs
make logs.acme | grep staging

# Solución: Comentar línea acme_ca en Caddyfile y reiniciar
```

## 🐳 Auto-Discovery Docker

### Ver Qué Se Descubre

```bash
# Ver todos los eventos de discovery
make logs.discovery

# Ver qué contenedores detectó
docker ps --filter "label=caddy"

# Ver configuración generada
docker exec caddy_nodo0 caddy config | jq
```

### Debugging Discovery

**Problema**: Servicio no se detecta

```bash
# 1. Verificar que el contenedor tiene labels
docker inspect mi_servicio | grep caddy

# 2. Ver si Caddy lo vio
make logs.discovery | grep mi_servicio

# 3. Forzar re-scan
make restart

# 4. Verificar configuración generada
docker exec caddy_nodo0 caddy config | grep mi_servicio
```

**Problema**: Discovery demasiado lento

```bash
# Ver intervalo de polling en docker-compose.yml
grep POLLING_INTERVAL caddy/docker-compose.yml

# Actual: 5 segundos
# Para cambiar, editar CADDY_DOCKER_POLLING_INTERVAL
```

##  Errores de Red

### Tipos Comunes

**1. Backend no responde (502)**:
```bash
# Ver qué upstream está fallando
make logs.error | grep "502\|bad gateway"

# Ver logs del backend
docker logs mi_servicio_nodo0

# Probar conectividad desde Caddy
docker exec caddy_nodo0 wget -qO- http://mi-servicio:8080
```

**2. Timeout conectando a backend**:
```bash
# Ver timeouts
make logs.error | grep timeout

# Verificar que el servicio esté en la misma red
docker network inspect internal-nodo0-web
```

**3. DNS no resuelve**:
```bash
# Ver errores DNS
make logs.error | grep "dns\|resolve"

# Verificar desde host
dig +short genphenia.infra.cluster.qb.fcen.uba.ar

# Verificar desde Caddy
docker exec caddy_nodo0 nslookup genphenia.infra.cluster.qb.fcen.uba.ar
```

## 🔴 Caddy Se Cae / Restart Loop

### Detectar

```bash
# Ver estado del contenedor
docker ps -a | grep caddy_nodo0

# Ver restart count
docker inspect caddy_nodo0 --format='{{.RestartCount}}'

# Ver últimos logs antes de crash
docker logs caddy_nodo0 --tail=50
```

### Debugging

```bash
# 1. Ver errores fatales
make logs.error

# 2. Ver logs del contenedor
make logs.live

# 3. Validar Caddyfile
make validate

# 4. Ver health check
docker inspect caddy_nodo0 | grep -A 10 Health
```

**Causas comunes**:
- Caddyfile con syntax error
- Permisos incorrectos en `/data`
- Puerto 80/443 ya en uso
- Docker socket no accesible

##  Análisis de Logs

### JSON Parsing con jq

Todos los logs son JSON, ideal para parsing:

```bash
# Ver solo mensajes
cat logs/caddy-debug.log | jq -r '.msg'

# Filtrar por level
cat logs/caddy-debug.log | jq 'select(.level=="error")'

# Ver timestamps legibles
cat logs/caddy-debug.log | jq -r '"\(.ts) | \(.level) | \(.msg)"'

# Contar errores por tipo
cat logs/error.log | jq -r '.msg' | sort | uniq -c | sort -rn
```

### Estadísticas

```bash
# Total de requests (si access log habilitado)
wc -l logs/access.log

# Errores por hora
cat logs/error.log | jq -r '.ts' | cut -d: -f1 | uniq -c

# Certificados obtenidos
grep "certificate obtained" logs/caddy-debug.log | wc -l

# Servicios descubiertos
grep "discovered container" logs/caddy-debug.log | jq -r '.container_name' | sort -u
```

##  Alertas y Monitoreo

### Script de Alerta Simple

```bash
#!/bin/bash
# scripts/alert-on-errors.sh

ERROR_COUNT=$(wc -l < logs/error.log 2>/dev/null || echo "0")

if [[ "$ERROR_COUNT" -gt 10 ]]; then
    echo " ALERTA: Más de 10 errores detectados"
    tail -5 logs/error.log
    # Aquí: enviar email, Slack, etc.
fi
```

### Integrar con Cron

```bash
# Agregar a crontab para revisar cada 5 minutos
*/5 * * * * cd /home/mate/qb-65/traefik-gateway-nodo0/nodo0-server && ./scripts/alert-on-errors.sh
```

### Integrar con Prometheus/Grafana

Caddy exporta métricas en `/metrics` (si habilitas el plugin):

```caddyfile
# En Caddyfile global
{
    servers {
        metrics
    }
}
```

Luego scrape con Prometheus en `http://localhost:2019/metrics`

##  Configuración Avanzada

### Cambiar Level a INFO (Producción)

Para reducir verbosidad en producción:

```caddyfile
# En Caddyfile global
log {
    output file /var/log/caddy/caddy.log
    format json
    level INFO  # Cambiar de DEBUG a INFO
}
```

Luego: `make restart`

### Habilitar Access Log

Para registrar TODOS los requests HTTP:

```caddyfile
# En Caddyfile global o por host
log {
    output file /var/log/caddy/access.log
    format json
}
```

Esto genera 1 línea por request. Puede crecer rápido.

### Logs a Syslog

```caddyfile
log {
    output net syslog://localhost:514
    format json
    level INFO
}
```

### Logs a Stdout (Docker logs only)

```caddyfile
log {
    output stdout
    format json
    level DEBUG
}
```

Luego ver con: `make logs.live`

##  Checklist de Troubleshooting

Cuando algo no funciona:

- [ ] `make logs.error` - ¿Hay errores críticos?
- [ ] `make logs.acme` - ¿Problemas con certificados?
- [ ] `make logs.discovery` - ¿Servicio fue detectado?
- [ ] `docker ps` - ¿Caddy está corriendo?
- [ ] `make monitor` - ¿Health check OK?
- [ ] `make validate` - ¿Caddyfile válido?
- [ ] `docker logs caddy_nodo0` - ¿Qué dice el contenedor?
- [ ] `docker exec caddy_nodo0 caddy config` - ¿Configuración generada correcta?

## 🎓 Ejemplos Prácticos

### Nuevo servicio no funciona

```bash
# 1. Verificar que Caddy lo detectó
make logs.discovery | grep mi-servicio

# 2. Ver si hay errores de proxy
make logs.error | grep mi-servicio

# 3. Probar conectividad
docker exec caddy_nodo0 wget -O- http://mi-servicio:8080

# 4. Ver configuración generada
docker exec caddy_nodo0 caddy config | jq '.apps.http.servers.srv0.routes' | grep mi-servicio
```

### Certificado no se renueva

```bash
# 1. Ver logs de renovación
make logs.acme | grep renew

# 2. Ver cuándo expira
echo | openssl s_client -servername genphenia.infra.cluster.qb.fcen.uba.ar -connect genphenia.infra.cluster.qb.fcen.uba.ar:443 2>/dev/null | openssl x509 -noout -dates

# 3. Forzar renovación (si es necesario)
docker exec caddy_nodo0 caddy reload
```

### Performance issues

```bash
# 1. Ver uso de recursos
make monitor

# 2. Ver si hay muchos errors
wc -l logs/error.log

# 3. Ver requests más lentos (si access log habilitado)
cat logs/access.log | jq 'select(.duration > 5)' | jq -r '"\(.duration)s | \(.request.uri)"'

# 4. Stats del contenedor
docker stats caddy_nodo0 --no-stream
```

##  Recursos Adicionales

- **Caddy Logging Docs**: https://caddyserver.com/docs/caddyfile/directives/log
- **Docker Logging**: https://docs.docker.com/config/containers/logging/
- **jq Tutorial**: https://stedolan.github.io/jq/tutorial/

##  Resumen Rápido

```bash
# Ver TODO en tiempo real
make logs.debug

# Ver SOLO errores
make logs.error

# Ver certificados
make logs.acme

# Ver auto-discovery
make logs.discovery

# Dashboard interactivo
make monitor

# Guardar snapshot
make logs FILE=logs/debug-$(date +%Y%m%d).log
```

**Nivel de logging actual**: `DEBUG` (intenso, ideal para debugging)

**Para producción**: Cambiar a `INFO` en Caddyfile y reiniciar.
