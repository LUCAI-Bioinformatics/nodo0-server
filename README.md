# nodo0-traefik-stack

Stack de Traefik v3 lista para reemplazar el proxy actual en nodo0. Incluye automatización con Makefile y scripts para manejar red, certificados y permisos.

## Arquitectura

- Traefik v3 (imagen `traefik:v3`) expuesto en 80/443/8080.
- Providers Docker (solo servicios con `traefik.enable=true`) y File (`dynamic.toml`).
- Certificados Let's Encrypt (HTTP-01) con almacenamiento persistente en `traefik/config/acme.json`.
- Dashboard/API habilitado solo para debugging en 8080 con Basic Auth (`TRAEFIK_DASHBOARD_USER` + hash bcrypt en `.env`).
- Red Docker externa `internal-nodo0-web` compartida con los servicios backend.

## Requisitos

- Docker 20.10+ y Docker Compose plugin.
- Puertos 80 y 443 libres en el host.
- DNS apuntando a nodo0 (`infra.cluster.qb.fcen.uba.ar`) y conectividad saliente a Let's Encrypt.

## Puesta en marcha

```bash
cp .env.example .env
# Completar LE_EMAIL, credenciales de dashboard y cualquier override necesario
make check
make up
# Verificar emisión de certificados y errores ACME
make logs | grep ACME
```

## Migración segura desde el Traefik existente

1. Detener el contenedor antiguo: `docker stop traefik` (o nombre equivalente).
2. Copiar el `acme.json` actual a `traefik/config/acme.json` dentro de este repo.
3. Asegurar permisos: `chmod 600 traefik/config/acme.json` o `make perms`.
4. Levantar el nuevo stack: `make up`.
5. Validar acceso HTTPS a los hosts publicados.

## Scripts y Makefile

- `make network` crea la red externa (`scripts/ensure_network.sh`).
- `make up|down|restart|logs` controla el ciclo de vida del proxy (con `make logs FILE=logs/traefik-$(date -Iseconds).log` guarda una copia).
- `make check` valida presencia de `acme.json`, permisos y red.
- `make acme.backup` genera un backup timestamped en `backups/`.
- `make acme.restore FILE=backups/acme-YYYYmmdd-HHMMSSZ.json` restaura un backup (sin `FILE` usa el más reciente).
- `make perms` garantiza permisos 600 en `acme.json`.

## Agregar servicios nuevos

1. Conectar el servicio a la red externa definida en `.env` (`TRAEFIK_DOCKER_NETWORK`, default `internal-nodo0-web`).
2. Añadir labels de Traefik con el host público, entrypoints (`web`, `websecure`) y puerto interno correcto. Recordá incluir `traefik.routing.enable=true` además de `traefik.enable=true` (el proxy filtra servicios por esa etiqueta).
3. Reutilizar el middleware `https_redirect@file` para forzar HTTPS.
4. No commitear certificados: `traefik/config/acme.json` está en `.gitignore` y debe mantenerse así.

El directorio `services/example-service/` incluye un ejemplo mínimo (`traefik/whoami`) con las labels y red necesarias para validar el ruteo.

## Notas finales

- `acme.json` debe persistirse entre despliegues para evitar límites de Let's Encrypt.
- Los logs generales viven en `logs/traefik.log` (formato JSON). Ajustá `TRAEFIK_LOG_LEVEL` a `DEBUG` si necesitás más detalle; los eventos ACME se registran con nivel `INFO`.
- Para auditoría de ruteo podés activar el access log con `TRAEFIK_ACCESS_LOG=true`; se guarda en `logs/access.log`.
- El hash bcrypt para el dashboard puede generarse con `htpasswd -nbB usuario password` o `openssl passwd -6`.
- Los scripts crean `backups/` según sea necesario; recordá conservarlos en un lugar seguro.
