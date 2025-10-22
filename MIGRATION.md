# Migración de Traefik a Caddy

Este documento describe el proceso seguro para migrar desde Traefik v3 a Caddy v2 en nodo0, preservando certificados y minimizando el downtime.

## Diferencias Clave: Traefik vs Caddy

| Aspecto | Traefik | Caddy |
|---------|---------|-------|
| **Configuración** | TOML estático + labels Docker | Caddyfile estático (o JSON API) |
| **Descubrimiento** | Labels en contenedores (automático) | Configuración manual en Caddyfile |
| **Certificados** | `acme.json` (un archivo) | `/data` directorio (múltiples archivos) |
| **Dashboard** | Dashboard web nativo | Admin API (solo localhost por defecto) |
| **Complejidad** | Mayor superficie de config | Configuración más simple |
| **TLS automático** | HTTP-01 configurable | HTTP-01 y TLS-ALPN-01 por defecto |

## Preparación

### 1. Backup de Certificados Traefik

Antes de cualquier cambio, respaldar los certificados existentes:

```bash
cd nodo0-server

# Con Traefik corriendo
make acme.backup

# Resultado: backups/acme-YYYYmmdd-HHMMSSZ.json
```

### 2. Documentar Servicios Actuales

Listar todos los servicios que actualmente enrutan a través de Traefik:

```bash
# Ver contenedores con labels de Traefik
docker ps --filter "label=traefik.enable=true" --format "table {{.Names}}\t{{.Image}}"

# Ver routers configurados
docker exec traefik_nodo0 cat /etc/traefik/dynamic/dynamic.toml | grep -A 5 "\[http.routers"
```

Anotar:
- Host externo (ej. `genphenia.infra.cluster.qb.fcen.uba.ar`)
- Puerto interno del servicio (ej. `8080`)
- Middlewares aplicados (Basic Auth, redirects, etc.)

### 3. Configurar Caddy para Tus Servicios

Editar `caddy/Caddyfile` y agregar un bloque por cada servicio:

```caddyfile
# Ejemplo: agregar un nuevo servicio
miservicio.infra.cluster.qb.fcen.uba.ar {
    reverse_proxy nombre-servicio:puerto

    log {
        output file /var/log/caddy/miservicio.log
        format json
    }
}
```

**Importante**: El nombre del servicio debe coincidir con el `service name` en docker-compose.yml del servicio backend.

### 4. Generar Hash para Basic Auth (si aplica)

Si tu endpoint de admin/debug necesita Basic Auth:

```bash
# Opción 1: htpasswd
htpasswd -nbB admin tu-password

# Opción 2: openssl
openssl passwd -6

# Copiar el hash resultante a caddy/Caddyfile en la sección basicauth
```

Actualizar en `Caddyfile`:

```caddyfile
traefik.infra.cluster.qb.fcen.uba.ar {
    basicauth {
        admin $2y$05$TuHashAqui...
    }
    # ...
}
```

## Proceso de Migración

### Opción A: Migración con Downtime Mínimo (Recomendado)

Este método cambia Traefik por Caddy en segundos, ideal si tienes una ventana de mantenimiento.

```bash
cd nodo0-server

# 1. Verificar configuración de Caddy
cp .env.example .env
# Editar .env con tus valores (LE_EMAIL, etc.)

make check
make validate  # Valida sintaxis del Caddyfile

# 2. Detener Traefik (libera puertos 80/443)
cd traefik
docker compose down

# 3. Iniciar Caddy inmediatamente
cd ..
make up

# 4. Verificar que Caddy está corriendo
make ps
make logs

# 5. Verificar certificados se están emitiendo
make logs | grep -i "certificate obtained"

# 6. Probar acceso HTTPS a tus servicios
curl -I https://genphenia.infra.cluster.qb.fcen.uba.ar
curl -I https://traefik.infra.cluster.qb.fcen.uba.ar  # Debe pedir auth
```

**Downtime estimado**: 10-30 segundos (tiempo entre `docker compose down` y `make up`).

### Opción B: Migración Gradual con Traefik en Staging

Si quieres probar Caddy sin afectar producción:

1. **Levantar Caddy en puertos alternativos** (ej. 8080/8443):
   ```yaml
   # En caddy/docker-compose.yml temporalmente
   ports:
     - "8080:80"
     - "8443:443"
   ```

2. **Probar con hosts locales**:
   ```bash
   curl -H "Host: genphenia.infra.cluster.qb.fcen.uba.ar" http://localhost:8080 --insecure
   ```

3. **Cuando estés listo, cambiar a puertos reales**:
   - Detener Traefik
   - Cambiar puertos en Caddy a 80/443
   - Reiniciar Caddy

### Opción C: Migración de Certificados (Experimental)

Caddy y Traefik usan formatos diferentes para certificados. **No es posible migrar directamente `acme.json` a `/data`**.

Opciones:
1. **Dejar que Caddy re-emita** (recomendado si no estás cerca de rate limits)
2. **Usar certificados externos** (copiar certs a `/data/caddy/certificates` manualmente - avanzado)

**Rate Limits de Let's Encrypt**:
- 50 certificados por dominio registrado por semana
- 5 duplicados por semana para el mismo conjunto de dominios

Si solo tienes 2-3 dominios (genphenia, traefik admin), re-emitir es seguro.

## Post-Migración

### 1. Verificar Todos los Servicios

```bash
# Probar cada endpoint configurado
curl -I https://genphenia.infra.cluster.qb.fcen.uba.ar
curl -u admin:password https://traefik.infra.cluster.qb.fcen.uba.ar/health

# Verificar logs de errores
cd nodo0-server
make logs | grep -i error
```

### 2. Configurar Backups Automáticos

```bash
# Agregar a crontab del servidor
0 3 * * * cd /ruta/a/nodo0-server && make certs.backup

# O script systemd timer
```

### 3. Cambiar a ACME Producción

Si estabas usando Let's Encrypt staging, cambiar a producción:

```caddyfile
# En caddy/Caddyfile, eliminar esta línea:
# acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
```

Luego:

```bash
# Limpiar certificados staging
rm -rf caddy/data/caddy/certificates/*
make restart

# Verificar emisión de certificados de producción
make logs | grep "certificate obtained"
```

### 4. Actualizar Servicios Backend

Los servicios ya NO necesitan labels de Traefik. Puedes limpiarlos:

```yaml
# ANTES (con Traefik)
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.miapp.rule=Host(`miapp.example.com`)"
  # ...

# DESPUÉS (con Caddy) - sin labels
# El routing está en caddy/Caddyfile
```

### 5. Remover Traefik (Cuando Estés Seguro)

```bash
# Después de confirmar que todo funciona con Caddy
cd traefik
docker compose down -v  # -v elimina volúmenes

# Opcional: archivar la config
cd ..
tar -czf traefik-config-backup-$(date +%Y%m%d).tar.gz traefik/
```

## Troubleshooting

### Caddy No Emite Certificados

**Síntomas**: `curl` muestra "self-signed certificate" o "certificate error"

**Causas comunes**:
1. Puerto 80 no accesible desde internet (HTTP-01 challenge falla)
2. DNS no apunta al servidor
3. Staging ACME activo (certificados no confiables)

**Solución**:
```bash
# Verificar puerto 80 desde externo
curl -I http://genphenia.infra.cluster.qb.fcen.uba.ar

# Verificar DNS
dig +short genphenia.infra.cluster.qb.fcen.uba.ar

# Ver errores ACME en logs
make logs | grep -i acme
```

### Servicio Backend No Responde

**Síntomas**: Caddy logs muestran "dial tcp: lookup genphenia-api: no such host"

**Causa**: Servicio no está en la red `internal-nodo0-web`

**Solución**:
```bash
# Verificar red del servicio
docker inspect genphenia_api_nodo0 | grep -A 10 Networks

# Agregar a la red si falta
docker network connect internal-nodo0-web genphenia_api_nodo0
```

### HTTP Redirect Loop

**Síntomas**: Browser muestra "too many redirects"

**Causa**: Caddy hace redirect HTTP→HTTPS automáticamente. Si tienes un load balancer/proxy adelante, puede causar loop.

**Solución**: No suele aplicar en setup directo, pero si usas Cloudflare:
```caddyfile
# Forzar uso del protocolo del header
genphenia.infra.cluster.qb.fcen.uba.ar {
    @http {
        header X-Forwarded-Proto http
    }
    redir @http https://{host}{uri} permanent

    reverse_proxy genphenia-api:8080
}
```

## Rollback a Traefik

Si necesitas volver a Traefik:

```bash
cd nodo0-server

# 1. Detener Caddy
cd caddy
docker compose down

# 2. Restaurar Traefik
cd ../traefik
docker compose up -d

# 3. Verificar
docker compose ps
```

Los certificados de Traefik (`acme.json`) se mantienen en backup, así que no hay re-emisión.

## Checklist Final

- [ ] Backup de `traefik/config/acme.json` creado
- [ ] Todos los servicios documentados (host → servicio:puerto)
- [ ] `caddy/Caddyfile` configurado con todos los hosts
- [ ] `.env` creado con valores correctos
- [ ] `make check` pasa sin errores
- [ ] `make validate` valida Caddyfile sin errores
- [ ] Ventana de mantenimiento coordinada (si aplica)
- [ ] Traefik detenido, Caddy iniciado
- [ ] Certificados HTTPS funcionando en todos los hosts
- [ ] Logs no muestran errores críticos
- [ ] Backup automático de certificados configurado
- [ ] Documentación interna actualizada
- [ ] Traefik desmantelado (cuando estés 100% seguro)

## Soporte

Si encontrás problemas durante la migración:

1. Revisar logs: `make logs`
2. Validar configuración: `make validate`
3. Verificar conectividad red: `docker network inspect internal-nodo0-web`
4. Consultar docs oficiales: https://caddyserver.com/docs/

Para rollback rápido, seguir la sección "Rollback a Traefik" arriba.
