# genphenia-api Service

Real application service that connects to Caddy reverse proxy via the shared `internal-nodo0-web` network.

## Configuration

- **Host**: `genphenia.infra.cluster.qb.fcen.uba.ar`
- **Internal Port**: 8080 (exposed to Docker network only)
- **Public Access**: HTTPS via Caddy with automatic Let's Encrypt certificates
- **Network**: `internal-nodo0-web` (shared with Caddy)
- **Auto-Discovery**: ✅ Enabled via Docker labels

## Auto-Discovery con Labels

**Igual que Traefik**: Este servicio usa labels Docker para que Caddy lo detecte automáticamente. No hay que editar Caddyfile ni reiniciar Caddy.

```yaml
labels:
  # Hostname público
  caddy: "genphenia.infra.cluster.qb.fcen.uba.ar"

  # Reverse proxy al puerto 8080
  caddy.reverse_proxy: "{{upstreams 8080}}"

  # Headers personalizados
  caddy.header_up.X-Real-IP: "{remote_host}"
  caddy.header_up.X-Forwarded-Proto: "{scheme}"

  # Logging específico
  caddy.log: "output file /var/log/caddy/genphenia.log"
```

El servicio es detectado automáticamente en 5-10 segundos después de `docker compose up -d`.

## Deployment

```bash
cd services/genphenia-api

# Use the shared network from .env
CADDY_DOCKER_NETWORK=internal-nodo0-web docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

## Updating the Service

1. Update the image in `docker-compose.yml`
2. Pull and restart:
   ```bash
   docker compose pull
   docker compose up -d
   ```

## Modificar Routing

Para agregar rutas o cambiar configuración:

1. Editar labels en `docker-compose.yml`
2. Recrear contenedor: `docker compose up -d`
3. Caddy detecta los cambios automáticamente (no restart necesario)

Ejemplo - agregar path específico:
```yaml
labels:
  caddy: "genphenia.infra.cluster.qb.fcen.uba.ar"
  caddy.reverse_proxy: "/api/v1/* {{upstreams 8080}}"
```

## Health Checks

The service includes a health check that pings `http://localhost:8080/health`. Adjust the path if your application uses a different health endpoint.

## Troubleshooting

**Service not accessible:**
- Verify network: `docker network inspect internal-nodo0-web`
- Check Caddy discovered it: `docker exec caddy_nodo0 caddy config | grep genphenia`
- Check labels present: `docker inspect genphenia_api_nodo0 | grep caddy`
- Check Caddy can reach service: `docker exec caddy_nodo0 wget -qO- http://genphenia-api:8080`
- Review Caddy logs: `cd nodo0-server && make logs`

**Certificate issues:**
- Ensure DNS points to server IP
- Check Caddy logs for ACME errors
- Verify port 80 is accessible from internet (HTTP-01 challenge)

**Connection refused:**
- Verify the service is listening on 0.0.0.0:8080 (not 127.0.0.1)
- Check the PORT environment variable matches expose directive
