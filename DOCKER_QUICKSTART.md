# Docker Quickstart Guide

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Access to a WANGuard API endpoint

---

## Quick Start (3 Steps)

### 1. Configure Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your WANGuard credentials
nano .env  # or vim, code, etc.
```

Required variables:
```env
WANGUARD_ADDRESS=http://your-wanguard-server:81
WANGUARD_USERNAME=admin
WANGUARD_PASSWORD=your-secure-password
```

### 2. Start the Exporter

```bash
# Start only the exporter
docker-compose up -d

# Or start with Prometheus
docker-compose --profile prometheus up -d

# Or start full stack (exporter + Prometheus + Grafana)
docker-compose --profile prometheus --profile grafana up -d
```

### 3. Verify It's Running

```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f wanguard_exporter

# Test metrics endpoint
curl http://localhost:9868/metrics
```

---

## Accessing Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| WANGuard Exporter | http://localhost:9868 | N/A |
| Prometheus | http://localhost:9090 | N/A |
| Grafana | http://localhost:3000 | admin / admin |

---

## Configuration

### Exporter Flags via Environment

Map environment variables to exporter flags:

```yaml
environment:
  - WANGUARD_ADDRESS=http://wanguard:81        # --api.address
  - WANGUARD_USERNAME=admin                    # --api.username
  - WANGUARD_PASSWORD=secret                   # --api.password (or env WANGUARD_PASSWORD)
  - WANGUARD_METRICS_PATH=/metrics             # --web.metrics-path
  - WANGUARD_LISTEN_ADDRESS=:9868              # --web.listen-address
```

### Command-line Flags

You can also override via command in docker-compose.yml:

```yaml
command:
  - '--api.address=http://wanguard:81'
  - '--api.username=admin'
  - '--api.password=${WANGUARD_PASSWORD}'
  - '--web.listen-address=:9868'
  - '--collector.license=true'
```

---

## Troubleshooting

### Container Restart Loop

**Symptom:** Container keeps restarting
**Cause:** Missing `WANGUARD_PASSWORD`
**Fix:** Create `.env` file with correct credentials

```bash
# Check logs
docker-compose logs wanguard_exporter

# Expected error:
# ERROR: Please set to WANGuard API Password!
```

### Connection Refused

**Symptom:** `connection refused` errors in logs
**Cause:** Wrong `WANGUARD_ADDRESS` or WANGuard API not accessible from container
**Fix:**
- Use host IP instead of `localhost` or `127.0.0.1`
- Or use `host.docker.internal` on Docker Desktop

```env
# Bad (inside container, localhost = container itself)
WANGUARD_ADDRESS=http://127.0.0.1:81

# Good (host machine)
WANGUARD_ADDRESS=http://192.168.1.100:81

# Good (Docker Desktop special hostname)
WANGUARD_ADDRESS=http://host.docker.internal:81
```

### Platform Warning (ARM64/M1 Macs)

**Symptom:** `platform (linux/amd64) does not match detected host platform (linux/arm64/v8)`
**Impact:** Runs with emulation, slightly slower but works fine
**Fix (optional):** Build native ARM64 image

```bash
# Build for ARM64
docker buildx build --platform linux/arm64 -t wanguard_exporter:1.6-arm64 .
```

---

## Production Deployment

See full guide: [docs/docker/DEPLOYMENT_GUIDE.md](docs/docker/DEPLOYMENT_GUIDE.md)

**Key points:**
- Use Docker secrets or vault for `WANGUARD_PASSWORD`
- Enable HTTPS with reverse proxy (nginx, traefik)
- Configure resource limits in docker-compose.yml
- Set up log rotation
- Monitor with Prometheus alerts

---

## Useful Commands

```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop all
docker-compose down

# Rebuild after code changes
docker-compose build --no-cache

# Check resource usage
docker stats wanguard_exporter

# Execute command inside container
docker-compose exec wanguard_exporter /bin/sh
```

---

## Next Steps

1. Configure Prometheus scraping (see `docker/prometheus.yml`)
2. Set up Grafana dashboards
3. Configure alerting rules (see `docker/alert_rules.yml`)
4. Review security checklist: [docs/docker/PRODUCTION_VALIDATION.md](docs/docker/PRODUCTION_VALIDATION.md)
