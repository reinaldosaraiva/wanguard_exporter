# 🐳 WANGuard Exporter - Docker Deployment Guide

**Version:** 1.6
**Architecture:** x86_64 (amd64)
**Status:** ✅ Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Configuration](#configuration)
5. [Docker Compose](#docker-compose)
6. [Health Checks](#health-checks)
7. [Monitoring](#monitoring)
8. [Security](#security)
9. [Troubleshooting](#troubleshooting)
10. [Production Best Practices](#production-best-practices)

---

## 🚀 Overview

WANGuard Exporter is a Prometheus exporter for WANGuard with security and robustness improvements.

**Image Details:**
- **Base Image:** alpine:3.19
- **Go Version:** 1.21.5
- **Architecture:** linux/amd64 (x86_64)
- **Image Size:** 21MB
- **User:** non-root (wanguard:1000)

---

## ✅ Prerequisites

### Required
- Docker 20.10+ or Docker Compose 2.0+
- 50MB disk space
- WANGuard API access (address, username, password)

### Optional
- Prometheus server (for metrics collection)
- Grafana (for visualization)
- Reverse proxy (nginx, traefik, etc.)

---

## ⚡ Quick Start

### Using Docker Run

```bash
docker run -d \
  --name wanguard_exporter \
  -p 9868:9868 \
  -e WANGUARD_ADDRESS=http://your-wanguard-server:81 \
  -e WANGUARD_USERNAME=admin \
  -e WANGUARD_PASSWORD=your-password \
  wanguard_exporter:1.6
```

### Using Docker Compose

```bash
# Start exporter only
docker-compose up -d wanguard_exporter

# Start with Prometheus
docker-compose --profile prometheus up -d

# Start with Prometheus and Grafana
docker-compose --profile grafana up -d
```

### Verify Deployment

```bash
# Check container status
docker ps | grep wanguard_exporter

# Check health
docker inspect wanguard_exporter | grep -A 5 Health

# Test metrics endpoint
curl http://localhost:9868/metrics | head -20

# Check version
docker run --rm wanguard_exporter:1.6 --version
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default | Required |
|-----------|-------------|----------|----------|
| `WANGUARD_ADDRESS` | WANGuard API address | `http://127.0.0.1:81` | Yes |
| `WANGUARD_USERNAME` | WANGuard API username | `admin` | Yes |
| `WANGUARD_PASSWORD` | WANGuard API password | - | Yes |
| `WANGUARD_LISTEN_ADDRESS` | HTTP server listen address | `:9868` | No |
| `WANGUARD_METRICS_PATH` | Metrics endpoint path | `/metrics` | No |

### Command Line Flags

```bash
docker run -d \
  --name wanguard_exporter \
  -e WANGUARD_ADDRESS=http://your-server:81 \
  -e WANGUARD_USERNAME=admin \
  -e WANGUARD_PASSWORD=your-password \
  wanguard_exporter:1.6 \
  --web.listen-address=:9868 \
  --web.metrics-path=/metrics
```

### Collectors

Enable/disable specific collectors:

```bash
docker run -d \
  --name wanguard_exporter \
  -e WANGUARD_ADDRESS=http://your-server:81 \
  -e WANGUARD_USERNAME=admin \
  -e WANGUARD_PASSWORD=your-password \
  wanguard_exporter:1.6 \
  --collector.license=false \
  --collector.actions=false
```

**Available Collectors:**
- `collector.license` (default: true)
- `collector.announcements` (default: true)
- `collector.anomalies` (default: true)
- `collector.components` (default: true)
- `collector.actions` (default: true)
- `collector.sensors` (default: true)
- `collector.traffic` (default: true)
- `collector.firewall_rules` (default: true)

---

## 🐳 Docker Compose

### Basic Setup

```yaml
version: '3.8'

services:
  wanguard_exporter:
    image: wanguard_exporter:1.6
    container_name: wanguard_exporter
    ports:
      - "9868:9868"
    environment:
      - WANGUARD_ADDRESS=http://your-wanguard-server:81
      - WANGUARD_USERNAME=admin
      - WANGUARD_PASSWORD=${WANGUARD_PASSWORD}
    restart: unless-stopped
```

### Full Monitoring Stack

```bash
# Start with Prometheus and Grafana
docker-compose --profile grafana up -d

# Access:
# - WANGuard Exporter: http://localhost:9868
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000 (admin/admin)
```

---

## ❤️ Health Checks

### Docker Health Check

The container includes a built-in health check:

```bash
# Check health status
docker inspect wanguard_exporter | grep -A 5 Health

# Expected output:
# "Status": "healthy"
```

### Health Check Details

- **Interval:** 30 seconds
- **Timeout:** 10 seconds
- **Start Period:** 5 seconds
- **Retries:** 3
- **Command:** `wget --spider http://localhost:9868/metrics`

### Custom Health Check Endpoint

```bash
# Test health manually
curl -f http://localhost:9868/metrics || echo "Health check failed"
```

---

## 📊 Monitoring

### Prometheus Configuration

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'wanguard_exporter'
    static_configs:
      - targets: ['wanguard_exporter:9868']
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: '/metrics'
```

### Available Metrics

#### API Health
- `wanguard_api_up{api_address}` - Whether WANGuard API is reachable (1 = up, 0 = down)

#### License Metrics
- `wanguard_license_sensors_available`
- `wanguard_license_sensors_used`
- `wanguard_license_sensors_remaining`
- `wanguard_license_dpdk_engines_available`
- `wanguard_license_filters_available`
- `wanguard_license_license_seconds_remaining`

#### Anomalies Metrics
- `wanguard_anomaliesactive`
- `wanguard_anomaliesfinished`

#### Traffic Metrics
- `wanguard_sensor_live_bits_inbound`
- `wanguard_sensor_live_bits_outbound`
- `wanguard_sensor_live_packets_inbound`
- `wanguard_sensor_live_packets_outbound`

#### Go Process Metrics
- `go_goroutines`
- `go_memstats_alloc_bytes`
- `go_info`

### Alert Rules

Example alert rules:

```yaml
groups:
  - name: wanguard_alerts
    rules:
      - alert: WANGuardAPIDown
        expr: wanguard_api_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "WANGuard API is down"
```

---

## 🔒 Security

### Security Features

1. **Non-Root User**
   - Container runs as user `wanguard` (UID 1000)
   - No root privileges

2. **Minimal Base Image**
   - Alpine Linux 3.19 (small attack surface)
   - Only necessary packages installed

3. **Static Binary**
   - CGO_ENABLED=0
   - No external dependencies
   - No shared libraries

4. **TLS 1.2+**
   - Minimum TLS version 1.2
   - Certificate validation enabled

5. **Input Validation**
   - API address validated
   - Host validation
   - Scheme validation (http/https only)

6. **No Credential Leakage**
   - Authorization header not forwarded on cross-origin redirects
   - HTTPS required for redirects

### Security Best Practices

1. **Use Environment Variables for Secrets**
   ```bash
   # Good
   docker run -e WANGUARD_PASSWORD=${WANGUARD_PASSWORD} ...

   # Bad
   docker run -e WANGUARD_PASSWORD=mypassword ...
   ```

2. **Use HTTPS in Production**
   ```bash
   docker run -e WANGUARD_ADDRESS=https://your-server:81 ...
   ```

3. **Network Isolation**
   ```yaml
   networks:
     monitoring:
       driver: bridge
   ```

4. **Read-Only Filesystem**
   ```yaml
   read_only: true
   tmpfs:
     - /tmp
   ```

5. **Resource Limits**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '0.5'
         memory: 256M
       reservations:
         cpus: '0.1'
         memory: 64M
   ```

---

## 🐛 Troubleshooting

### Container Not Starting

```bash
# Check logs
docker logs wanguard_exporter

# Common issues:
# - Missing WANGUARD_PASSWORD
# - Invalid WANGUARD_ADDRESS
# - Network connectivity issues
```

### Health Check Failing

```bash
# Check health status
docker inspect wanguard_exporter | grep -A 5 Health

# Test endpoint manually
docker exec wanguard_exporter wget -O- http://localhost:9868/metrics

# Check if port is accessible
docker port wanguard_exporter
```

### Metrics Not Updating

```bash
# Check API connectivity
docker logs wanguard_exporter | grep "HTTP request failed"

# Verify wanguard_api_up metric
curl http://localhost:9868/metrics | grep wanguard_api_up

# Expected: wanguard_api_up{api_address="..."} 1 (up) or 0 (down)
```

### Connection Refused Errors

```bash
# Check WANGUARD_ADDRESS
docker exec wanguard_exporter printenv | grep WANGUARD

# Test API connectivity
docker exec wanguard_exporter wget -O- http://your-wanguard:81/wanguard-api/v1/license_manager

# Check network
docker network inspect bridge
```

### Common Error Messages

| Error | Cause | Solution |
|--------|--------|-----------|
| `dial tcp: connection refused` | WANGuard server unreachable | Check WANGUARD_ADDRESS and network |
| `401 Unauthorized` | Wrong credentials | Check WANGUARD_USERNAME and WANGUARD_PASSWORD |
| `API returned status 404` | Invalid API endpoint | Check WANGuard API version |
| `timeout` | API not responding | Increase timeout or check network |

---

## ✅ Production Best Practices

### 1. Resource Management

```yaml
services:
  wanguard_exporter:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 64M
    restart: unless-stopped
```

### 2. Logging

```yaml
services:
  wanguard_exporter:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 3. Health Checks

```yaml
services:
  wanguard_exporter:
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:9868/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
```

### 4. Network Isolation

```yaml
services:
  wanguard_exporter:
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
    internal: false
```

### 5. Security Hardening

```yaml
services:
  wanguard_exporter:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp
```

### 6. Reverse Proxy (Optional)

**Nginx Example:**

```nginx
server {
    listen 80;
    server_name wanguard-exporter.example.com;

    location /metrics {
        proxy_pass http://localhost:9868;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Security
        allow 192.168.1.0/24;
        deny all;
    }
}
```

### 7. Monitoring

- **Prometheus:** Scrape metrics every 15s
- **Grafana:** Create dashboards for WANGuard metrics
- **Alertmanager:** Set up alerts for:
  - `wanguard_api_up == 0`
  - `wanguard_license_seconds_remaining < 86400` (1 day)
  - `wanguard_anomaliesactive > 10`

### 8. Backup and Recovery

```bash
# Backup configuration
docker cp wanguard_exporter:/app/ ./backup/

# Test restore
docker run -d \
  --name wanguard_exporter_restored \
  -p 9868:9868 \
  -e WANGUARD_ADDRESS=http://backup-server:81 \
  -e WANGUARD_USERNAME=admin \
  -e WANGUARD_PASSWORD=your-password \
  wanguard_exporter:1.6
```

### 9. Updates

```bash
# Pull latest image
docker pull wanguard_exporter:1.6

# Recreate container
docker-compose up -d --force-recreate

# Verify
curl http://localhost:9868/metrics
```

---

## 📝 Validation Checklist

Before deploying to production:

- [ ] Image architecture is amd64 (x86_64)
- [ ] Container runs as non-root user
- [ ] Health checks are configured
- [ ] Resource limits are set
- [ ] Logging is configured
- [ ] Network isolation is enabled
- [ ] HTTPS is used for WANGUARD_ADDRESS
- [ ] Secrets are stored in environment variables
- [ ] Prometheus configuration is updated
- [ ] Alert rules are configured
- [ ] Monitoring is set up
- [ ] Backup strategy is in place
- [ ] Update procedure is documented
- [ ] Rollback procedure is documented

---

## 📞 Support

For issues or questions:
- Check logs: `docker logs wanguard_exporter`
- Validate: `docker inspect wanguard_exporter`
- Test: `curl http://localhost:9868/metrics`

---

## 📄 License

MIT License - See LICENSE file for details

---

**Last Updated:** 2026-01-13
**Version:** 1.6
**Status:** ✅ Production Ready
