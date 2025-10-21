# Genphenia API Example Service

Este directorio muestra cómo habilitar un servicio existente para exponerse a través del proxy de Traefik.

## Puntos clave

- El servicio se conecta a la red externa declarada en `.env` (`${TRAEFIK_DOCKER_NETWORK}`).
- Las labels de Traefik definen routers HTTPS y HTTP→HTTPS para el host `genphenia.infra.cluster.qb.fcen.uba.ar`.
- El middleware `https_redirect@file` ya está definido en la configuración dinámica de Traefik.
- Ajustá el `loadbalancer.server.port` al puerto interno real de tu aplicación.
- El bloque `deploy.resources` es opcional, pero sirve como plantilla para definir límites y reservas.

Copiá o adaptá este `docker-compose.yml` dentro del repositorio del servicio real para integrarlo con el reverse proxy.
