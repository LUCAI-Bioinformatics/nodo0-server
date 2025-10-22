# Servicio de ejemplo (whoami)

Snippets mínimos para validar que Traefik enruta correctamente hacia contenedores conectados a la red `edge`.

- Imagen usada: [`traefik/whoami`](https://hub.docker.com/r/traefik/whoami), muestra información básica del request.
- Host virtual de ejemplo: `example.infra.cluster.qb.fcen.uba.ar`. Cambiá ambas labels `Host(...)` por tu dominio real antes de levantarlo.
- El servicio escucha en el puerto 80 dentro del contenedor, por eso el `loadbalancer.server.port=80`.

Para probarlo:

```bash
cd services/example-service
TRAEFIK_DOCKER_NETWORK=internal-nodo0-web docker compose up -d
```

Después visitá `https://<tu-host>` o ejecutá `curl -H 'Host: example.infra.cluster.qb.fcen.uba.ar' https://127.0.0.1 --insecure` desde el servidor. Detenelo con `docker compose down` cuando termines.

> Nota: el directory solo sirve como referencia. No olvides ajustar nombres e imagen al publicar un servicio definitivo.
