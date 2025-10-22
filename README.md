# nodo0-caddy-stack

Stack de Caddy v2 con auto-discovery que reemplaza Traefik en nodo0. Incluye descubrimiento automático de servicios vía Docker labels, automatización con Makefile, y configuración simplificada vs. Traefik.

## Arquitectura

- **Caddy v2** con plugin `caddy-docker-proxy` (imagen `lucaslorentz/caddy-docker-proxy:2.9-alpine`)
- **Auto-discovery**: Servicios descubiertos automáticamente via Docker labels (similar a Traefik)
- **Puertos**: 80 (HTTP), 443 (HTTPS), 443/UDP (HTTP/3)
- **Certificados**: Let's Encrypt (HTTP-01 y TLS-ALPN-01) automático, almacenamiento persistente en `caddy/data/`
- **Logs**: JSON estructurados en `logs/`
- **Red**: Docker externa `internal-nodo0-web` compartida con servicios backend
- **Zero-restart**: Levantás contenedores nuevos y Caddy los detecta automáticamente (polling 5s)

## Requisitos

- Docker 20.10+ y Docker Compose plugin.
- Puertos 80 y 443 libres en el host.
- DNS apuntando a nodo0 (`*.infra.cluster.qb.fcen.uba.ar`) y conectividad saliente a Let's Encrypt.

## Puesta en marcha

```bash
cp .env.example .env
# Completar LE_EMAIL y CADDY_ADMIN_PASSWORD_HASH
# Generar hash: htpasswd -nbB admin password

make check     # Valida configuración
make validate  # Valida sintaxis de Caddyfile
make up        # Levanta Caddy

# Verificar emisión de certificados
make logs | grep -i "certificate obtained"
```

## Migración desde Traefik

Ver `MIGRATION.md` para guía completa paso a paso.

Resumen:
1. Backup certificados Traefik: `make acme.backup` (con Makefile viejo)
2. Configurar rutas equivalentes en `caddy/Caddyfile`
3. Detener Traefik: `cd traefik && docker compose down`
4. Iniciar Caddy: `cd .. && make up`
5. Validar acceso HTTPS a servicios
6. Limpiar labels `traefik.*` de servicios backend (ya no se usan)

**Nota**: Los certificados de Traefik (`acme.json`) NO son migrables directamente. Caddy re-emite certificados (seguro si no estás cerca de rate limits de Let's Encrypt).

## Scripts y Makefile

- `make network` crea la red externa si no existe.
- `make up|down|restart|logs` controla el ciclo de vida del proxy.
- `make validate` valida sintaxis del Caddyfile antes de desplegar.
- `make check` valida presencia de directorios, Caddyfile y red.
- `make certs.backup` genera backup timestamped de `caddy/data/` en `backups/`.
- `make certs.restore [FILE=...]` restaura backup (sin FILE usa el más reciente).
- `make perms` garantiza permisos correctos en directorios de Caddy.

## Agregar servicios nuevos (Auto-Discovery)

**🚀 Igual que Traefik**: Caddy con `docker-proxy` lee labels Docker y descubre servicios automáticamente. ¡No hay que editar Caddyfile ni reiniciar Caddy!

### 1. Conectar servicio a la red

En el `docker-compose.yml` del servicio:

```yaml
networks:
  edge:
    external: true
    name: ${CADDY_DOCKER_NETWORK:-internal-nodo0-web}

services:
  miservicio:
    image: miapp:latest
    networks:
      - edge
    expose:
      - "8080"  # Puerto interno
```

### 2. Agregar labels Caddy

En el mismo `docker-compose.yml` del servicio:

```yaml
services:
  miservicio:
    # ... config anterior ...
    labels:
      # Hostname público
      caddy: "miapp.infra.cluster.qb.fcen.uba.ar"

      # Reverse proxy al puerto interno
      caddy.reverse_proxy: "{{upstreams 8080}}"

      # Opcional: headers personalizados
      caddy.header_up.X-Real-IP: "{remote_host}"
      caddy.header_up.X-Forwarded-Proto: "{scheme}"

      # Opcional: log por servicio
      caddy.log: "output file /var/log/caddy/miapp.log"
```

**¡Eso es todo!** No tocar Caddyfile.

### 3. Levantar el servicio

```bash
docker compose up -d
```

En 5-10 segundos, Caddy automáticamente:
- Redirige HTTP → HTTPS
- Obtiene certificado Let's Encrypt
- Proxy requests al backend

### 4. Verificar

```bash
# Ver detección automática en logs
make logs | grep miservicio

# Probar HTTPS
curl -I https://miapp.infra.cluster.qb.fcen.uba.ar

# Ver config generada
docker exec caddy_nodo0 caddy config
```

## Ejemplo: genphenia-api

El directorio `services/genphenia-api/` incluye un ejemplo real de servicio configurado para Caddy:

```bash
cd services/genphenia-api
CADDY_DOCKER_NETWORK=internal-nodo0-web docker compose up -d
```

Ver `services/genphenia-api/README.md` para más detalles.

## Diferencias clave con Traefik

| Aspecto | Traefik | Caddy + docker-proxy |
|---------|---------|---------------------|
| **Configuración** | TOML + labels Docker | Labels Docker (similar) |
| **Descubrimiento** | Automático (labels) | ✅ Automático (labels) |
| **Certificados** | `acme.json` (1 archivo) | `caddy/data/` (directorio) |
| **Dashboard** | Web UI nativo | Admin API (localhost) |
| **HTTPS redirect** | Middleware config | Automático |
| **Syntax labels** | `traefik.*` (5+ labels) | `caddy.*` (2 labels mínimo) |
| **Complejidad** | Mayor | Menor (labels más simples) |

## Notas finales

- `caddy/data/` debe persistirse entre despliegues para conservar certificados.
- **Con auto-discovery**: Levantar nuevos servicios NO requiere reiniciar Caddy (detección automática cada 5s).
- **Labels Caddy**: Mucho más simples que Traefik (2 labels mínimo vs 5+ en Traefik).
- Logs viven en `logs/` (JSON) y se rotan con logrotate o similar.
- Para debug: `make logs`, `make validate`, o `docker exec caddy_nodo0 caddy config`.
- El hash bcrypt para admin puede generarse con `htpasswd -nbB usuario password`.
- Los scripts crean `backups/` según sea necesario; conservarlos en lugar seguro.
- Staging ACME: Comentar/descomentar `acme_ca` en bloque global de Caddyfile.
- **Docker socket**: Caddy tiene acceso read-only a `/var/run/docker.sock` para descubrimiento.

## Soporte adicional

- **AUTO_DISCOVERY.md**: Guía completa de auto-discovery con labels Docker (⭐ importante)
- **CLAUDE.md**: Guía detallada para Claude Code con comandos y arquitectura
- **MIGRATION.md**: Proceso completo de migración desde Traefik
- **QUICKSTART.md**: Inicio rápido
- **services/genphenia-api/**: Ejemplo real de servicio con labels
- **services/example-service/**: Ejemplo simple (whoami) con labels
