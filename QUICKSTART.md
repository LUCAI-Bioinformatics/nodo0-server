# Quick Start - Caddy en nodo0

Guía rápida para levantar Caddy desde cero o migrar desde Traefik.

## Instalación desde Cero

```bash
cd nodo0-server

# 1. Crear archivo de entorno
cp .env.example .env

# 2. Editar configuración mínima
nano .env
# Cambiar:
# - LE_EMAIL=tu-email@example.com
# - CADDY_ADMIN_PASSWORD_HASH (ver abajo cómo generar)

# 3. Generar hash de password para admin
htpasswd -nbB admin tu-password
# Copiar el hash (parte después de "admin:") a CADDY_ADMIN_PASSWORD_HASH en .env

# 4. Validar configuración
make check
make validate

# 5. Levantar Caddy
make up

# 6. Verificar funcionamiento
docker ps | grep caddy_nodo0
make logs

# 7. Probar certificados (esperar 30-60 segundos)
curl -I https://genphenia.infra.cluster.qb.fcen.uba.ar
curl -I https://traefik.infra.cluster.qb.fcen.uba.ar
```

## Migración Rápida desde Traefik

```bash
cd nodo0-server

# 1. Backup de Traefik (opcional pero recomendado)
cd traefik
docker compose exec traefik cat /acme.json > ../backups/traefik-acme-backup.json
cd ..

# 2. Preparar Caddy
cp .env.example .env
nano .env  # Configurar LE_EMAIL y password hash

# 3. Documentar servicios actuales de Traefik
docker ps --filter "label=traefik.enable=true" --format "{{.Names}}"
# Anotar qué servicios tenés corriendo

# 4. Detener Traefik
cd traefik
docker compose down
cd ..

# 5. Levantar Caddy inmediatamente
make up

# 6. Verificar que todo funciona
make logs | grep -i "certificate obtained"
curl -I https://genphenia.infra.cluster.qb.fcen.uba.ar

# 7. Limpiar labels de Traefik de servicios (opcional)
# Editar docker-compose.yml de cada servicio y remover labels "traefik.*"
```

**Downtime estimado**: 10-30 segundos

## Comandos Más Usados

```bash
# ========== LOGS (DEBUG INTENSO) ==========
make logs.debug      # Ver TODO: ACME, errores, discovery
make logs.error      # Ver SOLO errores críticos
make logs.acme       # Ver SOLO certificados/Let's Encrypt
make logs.discovery  # Ver SOLO auto-discovery Docker
make monitor         # Dashboard interactivo

# ========== CICLO DE VIDA ==========
make restart         # Reiniciar Caddy
make validate        # Validar Caddyfile sin reiniciar
make ps              # Ver estado

# ========== CERTIFICADOS ==========
make certs.backup    # Backup de certificados

# ========== INFO ==========
docker exec caddy_nodo0 caddy version
docker exec caddy_nodo0 caddy config  # Ver config generada
```

Ver **LOGGING.md** para guía completa de debugging.

## Agregar Tu Primer Servicio

```bash
# 1. Agregar bloque al Caddyfile
nano caddy/Caddyfile

# Agregar:
# miapp.infra.cluster.qb.fcen.uba.ar {
#     reverse_proxy mi-servicio:8080
# }

# 2. Validar sintaxis
make validate

# 3. Reiniciar Caddy
make restart

# 4. Verificar certificado
make logs | grep "miapp.infra.cluster.qb.fcen.uba.ar"
curl -I https://miapp.infra.cluster.qb.fcen.uba.ar
```

## Troubleshooting Rápido

### Caddy no arranca

```bash
# Ver errores críticos
make logs.error

# Ver logs del contenedor
make logs.live

# Si ves "permission denied":
make perms
make restart

# Validar sintaxis Caddyfile
make validate
```

### Certificado no se emite

```bash
# Ver logs de certificados en tiempo real
make logs.acme

# Ver si hay errores
make logs.error | grep -i acme

# Verificar DNS
dig +short genphenia.infra.cluster.qb.fcen.uba.ar

# Verificar puerto 80 accesible desde internet
curl -I http://genphenia.infra.cluster.qb.fcen.uba.ar
```

### Servicio backend no responde

```bash
# Ver si Caddy lo detectó
make logs.discovery | grep nombre-servicio

# Ver errores de proxy
make logs.error | grep nombre-servicio

# Verificar que el servicio está en la red correcta
docker network inspect internal-nodo0-web

# Verificar conectividad desde Caddy
docker exec caddy_nodo0 wget -qO- http://nombre-servicio:8080

# Ver config generada
docker exec caddy_nodo0 caddy config | grep nombre-servicio
```

### Certificado staging (no confiable)

```bash
# Editar Caddyfile y comentar línea acme_ca
nano caddy/Caddyfile
# Comentar: # acme_ca https://acme-staging-v02...

# Limpiar certificados viejos
rm -rf caddy/data/caddy/certificates/*

# Reiniciar
make restart

# Verificar nuevo certificado
make logs | grep "certificate obtained"
```

## Checklist Post-Instalación

- [ ] Caddy corriendo: `docker ps | grep caddy_nodo0`
- [ ] Red creada: `docker network ls | grep internal-nodo0-web`
- [ ] Certificados emitidos: `make logs | grep "certificate obtained"`
- [ ] HTTPS funciona: `curl -I https://genphenia.infra.cluster.qb.fcen.uba.ar`
- [ ] Admin auth funciona: `curl -u admin:password https://traefik.infra.cluster.qb.fcen.uba.ar/health`
- [ ] Backup configurado: Agregar `make certs.backup` a cron/systemd timer
- [ ] Docs actualizados: Informar al equipo sobre el cambio

## Siguiente Paso

Lee `MIGRATION.md` para detalles completos de migración y `README.md` para uso día a día.

Para Claude Code: Ver `CLAUDE.md` en la raíz del repositorio.
