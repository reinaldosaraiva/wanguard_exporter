# WANGuard Exporter - Production Deployment Workarounds

This guide documents production workarounds for known issues in the WANGuard exporter.

## Overview

Three critical issues are addressed:
1. **Security**: HTTPS requirement for remote IPs
2. **Stability**: Firewall collector panic crashes
3. **Persistence**: Tunnel service lifecycle management

## Problem 1: HTTPS Enforcement for Remote Hosts

### Root Cause
The exporter enforces HTTPS for non-localhost connections (see `client/wg_client.go:162`):

```go
if !isLocalhost && parsedURL.Scheme == "http" {
    return nil, fmt.Errorf("HTTP not allowed for remote hosts")
}
```

### Solution: socat Tunnel

Create a local tunnel to make the remote API appear as localhost:

```bash
# 1. Create systemd service
sudo nano /etc/systemd/system/wanguard-tunnel.service
```

```ini
[Unit]
Description=WANGuard API Tunnel for Prometheus Exporter
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:8081,fork,reuseaddr TCP:10.251.196.19:80
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

```bash
# 2. Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable --now wanguard-tunnel.service

# 3. Verify tunnel
sudo systemctl status wanguard-tunnel.service
curl -s http://127.0.0.1:8081/wanguard-api/ | head -5
```

## Problem 2: Firewall Collector Panic

### Root Cause
The firewall rules collector crashes with panic errors (likely malformed JSON from API).

### Solution: Disable Collector

Use the `-collector.firewall_rules=false` flag when starting the exporter:

```bash
-collector.firewall_rules=false
```

**Note**: This disables the following metrics:
- `wanguard_firewall_rules_active`
- `wanguard_firewall_rules_activated`

## Complete Deployment Script

### Step 1: Clean Environment

```bash
# Remove old containers
sudo docker rm -f wanguard_exporter 2>/dev/null

# Free ports
sudo fuser -k 9868/tcp 8081/tcp 2>/dev/null
```

### Step 2: Setup Persistent Tunnel

```bash
# Create service (see configuration above)
sudo systemctl daemon-reload
sudo systemctl enable --now wanguard-tunnel.service
```

### Step 3: Build Docker Image

```bash
cd ~/wanguard_exporter
sudo docker build -t wanguard-exporter:final .
```

### Step 4: Run Container

```bash
sudo docker run -d \
  --name wanguard_exporter \
  --restart unless-stopped \
  --network host \
  wanguard-exporter:final \
  -api.address http://127.0.0.1:8081/wanguard-api/ \
  -api.username api \
  -api.password api \
  -collector.firewall_rules=false \
  -web.listen-address :9868
```

**Key parameters**:
- `--network host`: Allows access to tunnel on localhost:8081
- `-api.address http://127.0.0.1:8081/wanguard-api/`: Uses tunnel endpoint
- `-collector.firewall_rules=false`: Disables problematic collector
- `--restart unless-stopped`: Auto-restart on failure

### Step 5: Verification

```bash
# Check container health
sudo docker ps | grep wanguard_exporter
# Expected: "Up" status

# Check API connectivity metric
curl -s http://localhost:9868/metrics | grep wanguard_api_up
# Expected: wanguard_api_up{api_address="127.0.0.1:8081"} 1

# Check all metrics
curl -s http://localhost:9868/metrics | grep -E '^wanguard_' | head -20
```

### Step 6: Prometheus Integration

Add to `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'wanguard-metrics'
    scrape_interval: 30s
    static_configs:
      - targets: ['localhost:9868']
```

Reload Prometheus:
```bash
sudo systemctl reload prometheus
# Or if using Docker:
sudo docker exec prometheus kill -HUP 1
```

## Troubleshooting

### Issue: wanguard_api_up = 0

**Diagnosis**:
```bash
# Check tunnel
curl -s http://127.0.0.1:8081/wanguard-api/ | head -5

# Check exporter logs
sudo docker logs wanguard_exporter --tail 50
```

**Solutions**:
1. Verify WANGuard API user has "REST API Access" permission
2. Verify tunnel service is running: `sudo systemctl status wanguard-tunnel.service`
3. Test API directly: `curl -u api:api http://10.251.196.19:80/wanguard-api/`

### Issue: Container Keeps Restarting

**Diagnosis**:
```bash
sudo docker logs wanguard_exporter | grep -i "panic\|error"
```

**Solutions**:
1. Confirm `-collector.firewall_rules=false` is set
2. Check if other collectors are failing (add more `-collector.X=false` flags)
3. Verify API credentials are correct

### Issue: Tunnel Service Fails

**Diagnosis**:
```bash
sudo systemctl status wanguard-tunnel.service
sudo journalctl -u wanguard-tunnel.service -n 50
```

**Solutions**:
1. Verify socat is installed: `sudo apt-get install socat`
2. Check if port 8081 is already in use: `sudo lsof -i :8081`
3. Verify remote API is reachable: `telnet 10.251.196.19 80`

## Monitoring

### Key Metrics to Monitor

```promql
# API health (should always be 1)
wanguard_api_up

# License expiration (seconds remaining)
wanguard_license_seconds_remaining

# Active anomalies (DDoS detection)
wanguard_anomalies_active

# Sensor health
wanguard_sensor_load
wanguard_sensor_cpu
wanguard_sensor_ram
```

### Alerting Rules

Example Prometheus alert rules (`/etc/prometheus/rules/wanguard.yml`):

```yaml
groups:
  - name: wanguard
    interval: 30s
    rules:
      - alert: WANGuardAPIDown
        expr: wanguard_api_up == 0
        for: 2m
        annotations:
          summary: "WANGuard API is unreachable"

      - alert: WANGuardLicenseExpiringSoon
        expr: wanguard_license_seconds_remaining < 86400
        annotations:
          summary: "WANGuard license expires in < 24h"

      - alert: WANGuardActiveAnomaly
        expr: wanguard_anomalies_active > 0
        annotations:
          summary: "DDoS anomaly detected: {{ $labels.prefix }}"
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  PRODUCTION ARCHITECTURE                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Prometheus ─────scrape:30s───→ localhost:9868         │
│       │                              ↑                  │
│       │                              │                  │
│       │                    wanguard_exporter            │
│       │                       (Docker container)        │
│       │                              │                  │
│       │                    HTTP to 127.0.0.1:8081      │
│       │                              │                  │
│       │                              ↓                  │
│       │                      socat tunnel               │
│       │                    (systemd service)            │
│       │                              │                  │
│       │                    TCP forward to               │
│       │                    10.251.196.19:80             │
│       │                              │                  │
│       │                              ↓                  │
│       └──────query────→         WANGuard Server         │
│                              (Andrisoft DDoS)           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Security Considerations

### Tunnel Security

The socat tunnel bypasses HTTPS enforcement. Consider these mitigations:

1. **Network isolation**: Ensure tunnel only listens on 127.0.0.1
2. **Firewall rules**: Block external access to port 8081
3. **VPN**: Deploy exporter and WANGuard in same private network
4. **Certificate**: Add SSL certificate to WANGuard API (best solution)

### Firewall Collector Disabled

Without firewall metrics, you lose visibility into:
- Active firewall rules
- Rule activation count

**Mitigation**: Monitor firewall rules directly via WANGuard UI or separate integration.

## Alternative Solutions

### Option 1: Fix WANGuard API (Recommended)

Enable HTTPS on WANGuard server:
```bash
# On WANGuard server
/usr/local/wanguard/bin/wanguard-ssl-setup
```

Then use:
```bash
-api.address https://10.251.196.19:443/wanguard-api/
```

### Option 2: Patch Exporter Code

Modify `client/wg_client.go` to allow HTTP for specific IPs:

```go
// Add to allowlist
var trustedHosts = []string{"10.251.196.19"}

func isTrustedHost(host string) bool {
    for _, trusted := range trustedHosts {
        if host == trusted {
            return true
        }
    }
    return false
}

// In NewWanguardAPIClient:
if !isLocalhost && !isTrustedHost(parsedURL.Hostname()) && parsedURL.Scheme == "http" {
    return nil, fmt.Errorf("HTTP not allowed for untrusted remote hosts")
}
```

**Note**: This weakens security. Only use in isolated networks.

## References

- Original issue: HTTPS enforcement (client/wg_client.go:162)
- Firewall collector: collectors/firewall_rules_collector.go
- Security hardening: docs/security/FASE2_HTTP_CLIENT_ROBUSTO.md
- Docker setup: DOCKER_QUICKSTART.md
