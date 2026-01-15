# Docker Quickstart Guide

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Access to a WANGuard API endpoint

---

## Quick Start (4 Steps)

### 1. Configure Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your WANGuard credentials
nano .env  # or vim, code, etc.
```

Required variables:
```env
# WANGuard API Configuration
WANGUARD_API_ADDRESS=http://127.0.0.1:8081/wanguard-api/
WANGUARD_API_USERNAME=admin
WANGUARD_API_PASSWORD=your-secure-password

# Exporter Configuration
WANGUARD_EXPORTER_PORT=9868

# Prometheus Configuration
PROMETHEUS_PORT=9090

# Grafana Configuration
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
```

### 2. Build the Docker Image

```bash
docker build -t wanguard-exporter:final .
```

### 3. Start the Stack

```bash
# Start full stack (exporter + prometheus + grafana + nginx)
docker-compose up -d
```

### 4. Verify It's Running

```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f wanguard_exporter

# Test metrics endpoint
curl http://localhost:9868/metrics

# Test nginx health
curl http://localhost/health
```

---

## Accessing Services

All services are accessible via nginx reverse proxy on port 80:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Grafana | http://localhost/grafana/ | admin / admin |
| Prometheus | http://localhost/prometheus/ | N/A |
| WANGuard Exporter | http://localhost:9868/metrics | N/A |
| Health Check | http://localhost/health | N/A |

---

## Architecture

```
                    +------------------+
                    |     Nginx        |
                    |   (port 80)      |
                    +--------+---------+
                             |
            +----------------+----------------+
            |                                 |
   /grafana/                         /prometheus/
            |                                 |
   +--------v---------+          +-----------v----------+
   |     Grafana      |          |     Prometheus       |
   |   (port 3000)    |          |     (port 9090)      |
   +------------------+          +-----------+----------+
                                             |
                                    scrapes metrics
                                             |
                                 +-----------v----------+
                                 | WANGuard Exporter    |
                                 |    (port 9868)       |
                                 +-----------+----------+
                                             |
                                    HTTP/HTTPS API
                                             |
                                 +-----------v----------+
                                 |   WANGuard Server    |
                                 +----------------------+
```

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WANGUARD_API_ADDRESS` | WANGuard API endpoint URL | - |
| `WANGUARD_API_USERNAME` | API username | - |
| `WANGUARD_API_PASSWORD` | API password | - |
| `WANGUARD_EXPORTER_PORT` | Exporter listen port | 9868 |
| `PROMETHEUS_PORT` | Prometheus external port | 9090 |
| `GRAFANA_PORT` | Grafana external port | 3000 |
| `GRAFANA_ADMIN_USER` | Grafana admin username | admin |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | admin |

### Security Flag

The `-api.insecure` flag is enabled by default in docker-compose.yml to allow HTTP connections to the WANGuard API (useful for SSH tunnels or internal networks).

For HTTPS connections, you can remove this flag from docker-compose.yml:
```yaml
command:
  - -api.address=${WANGUARD_API_ADDRESS}
  - -api.username=${WANGUARD_API_USERNAME}
  - -api.password=${WANGUARD_API_PASSWORD}
  # - -api.insecure  # Remove this line for HTTPS
  - -collector.firewall_rules=false
  - -web.listen-address=:${WANGUARD_EXPORTER_PORT}
```

---

## Troubleshooting

### Container Restart Loop

**Symptom:** Container keeps restarting
**Cause:** Missing environment variables or wrong credentials
**Fix:** Check `.env` file has all required variables

```bash
# Check logs
docker-compose logs wanguard_exporter

# Verify .env exists
cat .env
```

### Connection Refused

**Symptom:** `connection refused` errors in logs
**Cause:** Wrong `WANGUARD_API_ADDRESS` or WANGuard API not accessible
**Fix:**
- For SSH tunnel: Use `http://127.0.0.1:8081/wanguard-api/`
- Ensure `-api.insecure` flag is set for HTTP connections

```env
# SSH tunnel (recommended)
WANGUARD_API_ADDRESS=http://127.0.0.1:8081/wanguard-api/

# Direct HTTPS connection
WANGUARD_API_ADDRESS=https://wanguard-server:81/wanguard-api/
```

### Nginx 502 Bad Gateway

**Symptom:** 502 error when accessing /grafana/ or /prometheus/
**Cause:** Backend services not ready yet
**Fix:** Wait for services to be healthy

```bash
# Check all services are healthy
docker-compose ps

# Expected output:
# grafana             ... Up (healthy)
# nginx               ... Up (healthy)
# prometheus          ... Up (healthy)
# wanguard_exporter   ... Up (healthy)
```

### Platform Warning (ARM64/M1 Macs)

**Symptom:** `platform (linux/amd64) does not match detected host platform`
**Impact:** Runs with emulation, slightly slower but works fine
**Fix (optional):** Build native ARM64 image

```bash
docker buildx build --platform linux/arm64 -t wanguard-exporter:final .
```

---

## Useful Commands

```bash
# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f wanguard_exporter

# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart wanguard_exporter

# Stop all
docker-compose down

# Stop and remove volumes (WARNING: deletes data)
docker-compose down -v

# Rebuild image after code changes
docker build -t wanguard-exporter:final . --no-cache

# Update and restart
docker-compose pull && docker-compose up -d

# Check resource usage
docker stats

# Execute command inside container
docker-compose exec grafana /bin/sh
```

---

## Production Deployment

See full guide: [docs/docker/DEPLOYMENT_GUIDE.md](docs/docker/DEPLOYMENT_GUIDE.md)

**Key points:**
- Use Docker secrets or vault for `WANGUARD_API_PASSWORD`
- Configure SSL/TLS in nginx for production
- Configure resource limits in docker-compose.yml
- Set up log rotation (already configured with json-file driver)
- Monitor with Prometheus alerts (see `docker/alert_rules.yml`)

---

## Files Reference

| File | Description |
|------|-------------|
| `docker-compose.yml` | Main stack configuration |
| `.env.example` | Environment variables template |
| `docker/nginx/nginx.conf` | Nginx reverse proxy configuration |
| `docker/prometheus.yml` | Prometheus scrape configuration |
| `docker/alert_rules.yml` | Prometheus alerting rules |
| `docker/grafana-provisioning/` | Grafana datasources and dashboards |
