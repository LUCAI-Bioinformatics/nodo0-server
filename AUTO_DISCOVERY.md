# Auto-Discovery con Caddy Docker Proxy

Esta guía explica cómo usar el descubrimiento automático de servicios con `caddy-docker-proxy`, similar a cómo funcionaba Traefik con labels.

## ¿Qué es caddy-docker-proxy?

`caddy-docker-proxy` es un plugin que extiende Caddy para descubrir servicios Docker automáticamente mediante labels, eliminando la necesidad de editar el Caddyfile y reiniciar Caddy cada vez que agregás un nuevo servicio.

### Ventajas

✅ **Sin restart**: Levantás un contenedor nuevo y Caddy lo detecta automáticamente
✅ **Tipo Traefik**: Mismo workflow que Traefik con labels
✅ **Actualización dinámica**: Polling cada 5 segundos detecta cambios
✅ **HTTPS automático**: Let's Encrypt sin configuración adicional
✅ **HTTP/3**: Soporte incluido (UDP 443)

### Desventajas

⚠️ **Moving parts**: Una dependencia más (plugin vs Caddy vanilla)
⚠️ **Docker socket**: Requiere acceso a `/var/run/docker.sock` (riesgo de seguridad menor)
⚠️ **Syntax diferente**: Labels Caddy vs labels Traefik (no son 1:1)

## Configuración Actual

El stack ya está configurado para auto-discovery:

- **Imagen**: `lucaslorentz/caddy-docker-proxy:2.9-alpine`
- **Polling**: Cada 5 segundos busca cambios
- **Prefix**: Labels deben empezar con `caddy.` o `caddy:`

## Agregar un Servicio Nuevo (Zero-Restart)

### Paso 1: Crear docker-compose.yml del Servicio

```yaml
version: "3.9"

networks:
  edge:
    external: true
    name: internal-nodo0-web

services:
  mi-api:
    image: mi-registry/mi-api:latest
    container_name: mi_api_nodo0
    restart: always

    expose:
      - "3000"  # Puerto interno

    networks:
      - edge

    labels:
      # Hostname público
      caddy: "miapi.infra.cluster.qb.fcen.uba.ar"

      # Reverse proxy al puerto 3000
      caddy.reverse_proxy: "{{upstreams 3000}}"

      # Automático: HTTP→HTTPS y Let's Encrypt
```

### Paso 2: Levantar el Servicio

```bash
cd services/mi-api
docker compose up -d
```

**¡Eso es todo!** En 5-10 segundos:
- Caddy detecta el nuevo contenedor
- Solicita certificado Let's Encrypt
- Comienza a rutear tráfico HTTPS

### Paso 3: Verificar

```bash
# Ver logs de Caddy detectando el servicio
cd ../../
make logs | grep mi-api

# Verificar certificado
curl -I https://miapi.infra.cluster.qb.fcen.uba.ar

# Ver configuración actual de Caddy
docker exec caddy_nodo0 wget -qO- http://localhost:2019/config/ | jq
```

## Labels Disponibles

### Labels Básicos (Mínimo)

```yaml
labels:
  caddy: "tu-dominio.com"                    # Hostname
  caddy.reverse_proxy: "{{upstreams 8080}}"  # Puerto interno
```

### Labels Avanzados

```yaml
labels:
  # Múltiples dominios
  caddy: "app.example.com app2.example.com"

  # Reverse proxy con opciones
  caddy.reverse_proxy: "{{upstreams 8080}}"
  caddy.reverse_proxy.health_uri: "/health"
  caddy.reverse_proxy.health_interval: "30s"

  # Headers personalizados
  caddy.header_up.X-Real-IP: "{remote_host}"
  caddy.header_up.X-Forwarded-Proto: "{scheme}"

  # TLS custom (staging)
  caddy.tls: "internal"  # Para testing local

  # Logging por servicio
  caddy.log: "output file /var/log/caddy/mi-servicio.log"

  # Redirigir www → non-www
  caddy_0: "www.example.com"
  caddy_0.redir: "https://example.com{uri}"

  # Basic Auth
  caddy.basicauth: "/admin/*"
  caddy.basicauth.admin: "$2y$05$YourBcryptHash"

  # Rewrite path
  caddy.rewrite: "* /api{path}"

  # Rate limiting (si tenés el módulo)
  caddy.rate_limit: "100/m"
```

## Plantilla Completa

```yaml
version: "3.9"

networks:
  edge:
    external: true
    name: ${CADDY_DOCKER_NETWORK:-internal-nodo0-web}

services:
  my-app:
    image: your-registry/your-app:latest
    container_name: my_app_nodo0
    restart: always

    expose:
      - "8080"

    networks:
      - edge

    environment:
      - PORT=8080
      - NODE_ENV=production

    labels:
      # === CONFIGURACIÓN BÁSICA ===
      # Hostname público (requerido)
      caddy: "myapp.infra.cluster.qb.fcen.uba.ar"

      # Reverse proxy (requerido)
      caddy.reverse_proxy: "{{upstreams 8080}}"

      # === OPCIONALES ===
      # Headers personalizados
      caddy.header_up.X-Real-IP: "{remote_host}"
      caddy.header_up.X-Forwarded-Proto: "{scheme}"

      # Logging específico
      caddy.log: "output file /var/log/caddy/myapp.log"

      # Health check del upstream
      caddy.reverse_proxy.health_uri: "/health"
      caddy.reverse_proxy.health_interval: "30s"

    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

## Ejemplos Prácticos

### API REST con Subpath

```yaml
labels:
  caddy: "api.infra.cluster.qb.fcen.uba.ar"
  caddy.reverse_proxy: "/v1/* {{upstreams 8080}}"
```

### SPA con API Backend

```yaml
# Frontend (SPA)
labels:
  caddy: "app.infra.cluster.qb.fcen.uba.ar"
  caddy.reverse_proxy: "{{upstreams 80}}"

# Backend (API)
labels:
  caddy: "app.infra.cluster.qb.fcen.uba.ar"
  caddy.reverse_proxy: "/api/* {{upstreams 3000}}"
```

### WebSocket Support

```yaml
labels:
  caddy: "ws.infra.cluster.qb.fcen.uba.ar"
  caddy.reverse_proxy: "{{upstreams 8080}}"
  caddy.reverse_proxy.header_up.Connection: "{>Connection}"
  caddy.reverse_proxy.header_up.Upgrade: "{>Upgrade}"
```

### Staging con Certificado Interno

```yaml
labels:
  caddy: "staging.infra.cluster.qb.fcen.uba.ar"
  caddy.reverse_proxy: "{{upstreams 8080}}"
  caddy.tls: "internal"  # No usa Let's Encrypt
```

## Debugging

### Ver Servicios Detectados

```bash
# Ver todos los contenedores con labels caddy
docker ps --filter "label=caddy"

# Ver configuración actual de Caddy
docker exec caddy_nodo0 caddy config --adapter caddyfile
```

### Ver Logs de Auto-Discovery

```bash
# Logs generales
make logs

# Filtrar por polling
make logs | grep -i "docker"

# Ver cambios de config
make logs | grep -i "config"
```

### Probar Label Syntax

```bash
# Validar sin levantar el servicio
docker compose config
```

### Forzar Re-scan

```bash
# Reiniciar Caddy (detectará todos los servicios)
make restart
```

## Troubleshooting

### Servicio No Se Detecta

**Síntomas**: Levantaste el contenedor pero Caddy no lo rutea

**Checklist**:
1. Contenedor en red correcta: `docker inspect CONTAINER | grep internal-nodo0-web`
2. Label `caddy:` presente: `docker inspect CONTAINER | grep caddy`
3. Polling activo: `make logs | grep polling`
4. Revisar typos en labels (caddy vs Caddy vs CADDY)

**Solución**:
```bash
# Reiniciar Caddy fuerza re-scan
make restart

# Ver si aparece
make logs | tail -50
```

### Certificado No Se Emite

**Síntomas**: HTTP funciona pero HTTPS da error

**Causas**:
- DNS no apunta al servidor
- Puerto 80 no accesible desde internet
- Label `caddy.tls: "internal"` está configurado (usa cert interno)

**Solución**:
```bash
# Verificar DNS
dig +short miapp.infra.cluster.qb.fcen.uba.ar

# Ver logs ACME
make logs | grep -i acme

# Probar HTTP-01 challenge
curl -I http://miapp.infra.cluster.qb.fcen.uba.ar/.well-known/acme-challenge/test
```

### Conflictos entre Servicios

**Síntomas**: Dos servicios con mismo hostname

**Caddy comportamiento**: Último en ser detectado gana

**Solución**: Asegurar hostnames únicos o usar paths:
```yaml
# Servicio A
caddy: "app.example.com"
caddy.reverse_proxy: "/api/* {{upstreams 8080}}"

# Servicio B
caddy: "app.example.com"
caddy.reverse_proxy: "/* {{upstreams 3000}}"
```

## Comparación: Labels Traefik vs Caddy

| Traefik | Caddy Docker Proxy |
|---------|-------------------|
| `traefik.enable=true` | Label `caddy:` con hostname |
| `traefik.http.routers.X.rule=Host(\`...\`)` | `caddy: "hostname.com"` |
| `traefik.http.services.X.loadbalancer.server.port=8080` | `caddy.reverse_proxy: "{{upstreams 8080}}"` |
| `traefik.http.routers.X.tls.certresolver=leresolver` | Automático (o `caddy.tls` para custom) |
| `traefik.http.middlewares.redirect.redirectscheme` | Automático (HTTP→HTTPS) |
| `traefik.http.routers.X.middlewares=auth@file` | `caddy.basicauth: "..."` |

## Migrando de Traefik

```bash
# ANTES (Traefik)
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=leresolver"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"

# DESPUÉS (Caddy)
labels:
  caddy: "myapp.example.com"
  caddy.reverse_proxy: "{{upstreams 8080}}"
```

**Mucho más simple!** 2 labels vs 5.

## Performance

- **Polling overhead**: Negligible (5s intervalo, solo escanea labels Docker)
- **Config reload**: <100ms típicamente
- **Certificados**: Se cachean en `/data`, no se re-emiten innecesariamente
- **Memory**: ~50MB adicional vs Caddy vanilla

## Seguridad

### Docker Socket Access

Caddy tiene acceso de lectura a `/var/run/docker.sock`. Esto es necesario para descubrimiento pero tiene implicaciones:

- ✅ Read-only mount (`:ro`)
- ⚠️ Puede listar todos los contenedores del host
- ⚠️ No puede crear/modificar/destruir contenedores (read-only)

**Mitigación**: En producción, considerar Docker Socket Proxy (containrrr/docker-socket-proxy) que filtra API calls.

## Siguiente Paso

Ver `services/genphenia-api/` y `services/example-service/` para ejemplos completos con labels.

Para volver a configuración estática, ver `STATIC_CONFIG.md` (próximamente).
