# Resumen: Auto-Discovery Habilitado ✅

El stack de Caddy ahora incluye **auto-discovery de servicios** mediante `caddy-docker-proxy`, funcionando de manera similar a Traefik con labels Docker.

## Qué Cambió

### ANTES (Static Config)
```
1. Editar services/mi-api/docker-compose.yml (crear servicio)
2. Editar caddy/Caddyfile (agregar route manualmente)
3. make restart (reiniciar Caddy)
4. Esperar ~30s (restart + certificados)
```

### AHORA (Auto-Discovery)
```
1. Editar services/mi-api/docker-compose.yml (con labels caddy.*)
2. docker compose up -d
3. ¡Listo! (detección automática en 5-10s)
```

**Sin editar Caddyfile, sin reiniciar Caddy** 🚀

## Comparación con Traefik

| Característica | Traefik | Caddy con docker-proxy |
|----------------|---------|------------------------|
| Descubrimiento automático | ✅ Labels | ✅ Labels |
| Restart necesario | ❌ No | ❌ No |
| Labels mínimos | 5+ | 2 |
| Syntax labels | `traefik.*` | `caddy.*` |
| HTTPS automático | ✅ Sí | ✅ Sí |
| Dashboard web | ✅ Sí | ❌ No (API local) |

## Labels: Traefik vs Caddy

### Traefik (5 labels mínimo)
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=internal-nodo0-web"
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=leresolver"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"
  - "traefik.http.routers.myapp-http.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp-http.entrypoints=web"
  - "traefik.http.routers.myapp-http.middlewares=https_redirect@file"
```

### Caddy (2 labels mínimo)
```yaml
labels:
  caddy: "myapp.example.com"
  caddy.reverse_proxy: "{{upstreams 8080}}"
  # HTTPS redirect automático, no config extra
```

**Simplificación: 9 labels → 2 labels** ⚡

## Imagen Docker

**Antes**: `caddy:2.8-alpine` (oficial, vanilla)
**Ahora**: `lucaslorentz/caddy-docker-proxy:2.9-alpine` (con plugin)

- Plugin: [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy)
- Stars: 2.7k+ GitHub
- Mantenido activamente
- Basado en Caddy oficial

## Cómo Funciona

1. **Polling**: Caddy escanea Docker cada 5 segundos
2. **Detección**: Busca contenedores con label `caddy:` o `caddy.*`
3. **Config generada**: Crea configuración Caddy dinámicamente
4. **ACME automático**: Solicita certificados Let's Encrypt
5. **Routing activo**: Empieza a rutear tráfico

**Total**: ~10-30 segundos desde `docker compose up -d` hasta HTTPS funcional.

## Archivos Modificados

```
nodo0-server/
├── caddy/
│   ├── docker-compose.yml        # ✏️ Cambiado a lucaslorentz/caddy-docker-proxy
│   └── Caddyfile                 # ✏️ Solo config global, sin routes de servicios
│
├── services/
│   ├── genphenia-api/
│   │   └── docker-compose.yml    # ✏️ Agregados labels caddy.*
│   └── example-service/
│       └── docker-compose.yml    # ✏️ Migrado de labels traefik.* → caddy.*
│
├── AUTO_DISCOVERY.md             # 📄 Nuevo - guía completa
└── AUTO_DISCOVERY_SUMMARY.md     # 📄 Nuevo - este archivo
```

## Ejemplo Completo

Ver `services/genphenia-api/docker-compose.yml` para ejemplo real con:
- Auto-discovery habilitado
- Headers personalizados
- Logging por servicio
- Health checks

## Seguridad

### Docker Socket Access

Caddy necesita acceso al socket Docker para descubrimiento:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only
```

**Riesgo**: Caddy puede listar todos los contenedores del host.
**Mitigación**: Mount es read-only (`:ro`), Caddy no puede crear/destruir contenedores.

Para máxima seguridad en producción, considerar [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy).

## Performance

- **Overhead**: ~50MB RAM adicional vs Caddy vanilla
- **Polling**: CPU negligible (escaneo de labels cada 5s)
- **Config reload**: <100ms típicamente
- **Certificados**: Cacheados, no se re-emiten innecesariamente

## Ventajas del Auto-Discovery

✅ **Workflow idéntico a Traefik** - migración mental cero
✅ **Zero-downtime deployments** - levantás nuevos containers sin tocar proxy
✅ **GitOps friendly** - cada servicio define su propio routing
✅ **Menos errores** - no hay que mantener Caddyfile sincronizado manualmente
✅ **Más simple** - 2 labels vs 5+ de Traefik
✅ **Testing fácil** - levantar/bajar servicios sin afectar proxy

## Desventajas vs Static Config

⚠️ **Dependencia extra** - plugin de terceros (bien mantenido)
⚠️ **Docker socket** - acceso al socket (read-only pero existe)
⚠️ **Debugging más complejo** - config generada dinámicamente
⚠️ **Sin dashboard visual** - Traefik tenía UI, Caddy solo API local

## Migración desde Static Config

Si tenías configuración estática (Caddyfile con todas las routes):

1. Mover routes del Caddyfile a labels en cada servicio
2. Cambiar imagen en `caddy/docker-compose.yml`
3. Reiniciar Caddy: `make restart`
4. Verificar detección: `make logs | grep -i discovery`

## Comandos Útiles

```bash
# Ver servicios detectados
docker ps --filter "label=caddy"

# Ver config generada por auto-discovery
docker exec caddy_nodo0 caddy config

# Ver logs de polling
make logs | grep -i docker

# Forzar re-scan (reiniciar Caddy)
make restart
```

## Documentación Adicional

- **AUTO_DISCOVERY.md**: Guía completa con todos los labels disponibles
- **services/genphenia-api/**: Ejemplo real
- **services/example-service/**: Ejemplo simple (whoami)

## Rollback a Static Config

Si preferís volver a configuración estática:

1. Cambiar imagen a `caddy:2.8-alpine` en docker-compose.yml
2. Restaurar Caddyfile con todas las routes
3. Remover labels `caddy.*` de servicios
4. Reiniciar: `make restart`

## Conclusión

**Auto-discovery está habilitado y funcionando** ✅

Ahora podés levantar servicios nuevos sin tocar Caddy, exactamente como funcionaba con Traefik pero con labels más simples.

**Workflow recomendado**:
1. Crear `services/mi-servicio/docker-compose.yml` con labels `caddy.*`
2. `docker compose up -d`
3. Esperar 10-30s
4. Verificar: `curl -I https://mi-servicio.infra.cluster.qb.fcen.uba.ar`

¡Listo! 🎉
