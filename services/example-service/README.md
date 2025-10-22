# Example Service - Plantilla con Auto-Discovery

Este directorio es una **plantilla completa** para agregar nuevos servicios con auto-discovery Caddy.

##  Cómo Usar Esta Plantilla

### 1. Copiar el Directorio

```bash
cd services
cp -r example-service mi-nuevo-servicio
cd mi-nuevo-servicio
```

### 2. Editar docker-compose.yml

Abrir `docker-compose.yml` y reemplazar:

```yaml
# Cambiar estos valores:
services:
  example-app:              → mi-app:
    image: traefik/whoami   → tu-registry/tu-imagen:tag
    container_name: example_app_nodo0  → mi_app_nodo0

    expose:
      - "80"                → puerto de tu app (ej: 8080)

    labels:
      caddy: "example.infra.cluster.qb.fcen.uba.ar"  → tu-dominio.com
      caddy.reverse_proxy: "{{upstreams 80}}"        → {{upstreams PUERTO}}
```

### 3. Configurar Variables de Entorno (si es necesario)

```yaml
environment:
  - PORT=8080
  - DATABASE_URL=${DATABASE_URL}
  - API_KEY=${API_KEY}
  # etc.
```

### 4. Levantar el Servicio

```bash
# Asegurarte de tener .env si usas variables
cp ../../.env.example .env  # si es necesario
nano .env

# Levantar
docker compose up -d

# Ver logs
docker compose logs -f
```

### 5. Verificar Auto-Discovery

```bash
# Esperar 5-10 segundos para que Caddy detecte el servicio

# Ver si fue detectado
cd ../../  # volver a nodo0-server/
make logs.discovery | grep mi-app

# Ver configuración generada
docker exec caddy_nodo0 caddy config | grep mi-dominio

# Probar HTTPS
curl -I https://tu-dominio.com
```

##  Ejemplo: whoami (actual)

Este servicio usa la imagen `traefik/whoami` que muestra información del request. Es útil para:
- Probar que Caddy está ruteando correctamente
- Ver qué headers llegan al backend
- Verificar auto-discovery funciona

```bash
# Levantar el ejemplo
docker compose up -d

# Esperar 10 segundos

# Probar
curl https://example.infra.cluster.qb.fcen.uba.ar
# Debería mostrar:
# Hostname: example_app_nodo0
# IP: ...
# RemoteAddr: ...
# GET / HTTP/1.1
# Host: example.infra.cluster.qb.fcen.uba.ar
# ...

# Detener
docker compose down
```

##  Labels Caddy Disponibles

### Básicos (Mínimo)

```yaml
labels:
  # Hostname público
  caddy: "miapp.example.com"

  # Reverse proxy al puerto interno
  caddy.reverse_proxy: "{{upstreams 8080}}"
```

### Headers Personalizados

```yaml
labels:
  caddy.header_up.X-Real-IP: "{remote_host}"
  caddy.header_up.X-Forwarded-Proto: "{scheme}"
  caddy.header_up.X-Custom-Header: "valor"
```

### Logging por Servicio

```yaml
labels:
  caddy.log: "output file /var/log/caddy/miapp.log"
```

### Basic Auth

```bash
# Generar hash
htpasswd -nbB admin password

# Agregar label
caddy.basicauth: "/admin/*"
caddy.basicauth.admin: "$2y$05$hash..."
```

### Health Check del Upstream

```yaml
labels:
  caddy.reverse_proxy.health_uri: "/health"
  caddy.reverse_proxy.health_interval: "30s"
```

### Múltiples Dominios

```yaml
labels:
  caddy: "app.example.com www.app.example.com"
```

### Subpath Routing

```yaml
labels:
  caddy: "example.com"
  caddy.reverse_proxy: "/api/* {{upstreams 8080}}"
```

Ver **AUTO_DISCOVERY.md** para más ejemplos avanzados.

##  Casos de Uso Comunes

### API REST

```yaml
services:
  api:
    image: mi-registry/api:latest
    container_name: api_nodo0
    expose:
      - "8080"
    networks:
      - edge
    labels:
      caddy: "api.example.com"
      caddy.reverse_proxy: "{{upstreams 8080}}"
      caddy.header.Access-Control-Allow-Origin: "*"
```

### Frontend SPA (React, Vue, etc.)

```yaml
services:
  frontend:
    image: nginx:alpine
    container_name: frontend_nodo0
    expose:
      - "80"
    networks:
      - edge
    volumes:
      - ./dist:/usr/share/nginx/html:ro
    labels:
      caddy: "app.example.com"
      caddy.reverse_proxy: "{{upstreams 80}}"
```

### App con Base de Datos

```yaml
services:
  app:
    image: mi-app:latest
    container_name: app_nodo0
    expose:
      - "3000"
    networks:
      - edge
    environment:
      - DATABASE_URL=postgresql://postgres:5432/mydb
    depends_on:
      - postgres
    labels:
      caddy: "app.example.com"
      caddy.reverse_proxy: "{{upstreams 3000}}"

  postgres:
    image: postgres:15-alpine
    container_name: postgres_app_nodo0
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - edge

volumes:
  postgres_data:
```

##  Troubleshooting

### Servicio no se detecta

```bash
# Verificar labels
docker inspect mi_contenedor | grep caddy

# Ver si Caddy lo vio
cd ../../
make logs.discovery | grep mi-servicio

# Forzar re-scan
make restart
```

### 502 Bad Gateway

```bash
# Verificar que el servicio está running
docker ps | grep mi-servicio

# Ver logs del servicio
docker logs mi_contenedor_nodo0

# Probar conectividad desde Caddy
docker exec caddy_nodo0 wget -qO- http://mi-servicio:8080

# Verificar que el servicio escucha en 0.0.0.0, no 127.0.0.1
```

### Certificado no se emite

```bash
# Ver logs ACME
cd ../../
make logs.acme

# Verificar DNS
dig +short tu-dominio.com

# Verificar puerto 80 accesible
curl -I http://tu-dominio.com
```

##  Documentación Adicional

- **AUTO_DISCOVERY.md** - Todos los labels disponibles
- **LOGGING.md** - Debugging y logs
- **README.md** (nodo0-server/) - Guía general
- **QUICKSTART.md** - Inicio rápido

##  Resumen

1. **Copiar**: `cp -r example-service mi-servicio`
2. **Editar**: docker-compose.yml (imagen, hostname, puerto)
3. **Levantar**: `docker compose up -d`
4. **Verificar**: `make logs.discovery | grep mi-servicio`

¡Listo! Caddy detecta y rutea automáticamente en 5-10 segundos. 
