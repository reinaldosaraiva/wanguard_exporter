# SSH Commands - WANGuard Server

Comandos para executar no servidor `ubuntu@10.251.196.19` (w-console).

## Quick Health Check (Copy & Paste)

```bash
# Run all checks in one command
echo "=== TUNNEL SERVICE ===" && \
sudo systemctl status wanguard-tunnel.service --no-pager | head -5 && \
echo "" && \
echo "=== DOCKER CONTAINER ===" && \
sudo docker ps --filter name=wanguard_exporter --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" && \
echo "" && \
echo "=== METRICS ENDPOINT ===" && \
curl -s http://localhost:9868/metrics | grep "wanguard_api_up" && \
echo "" && \
echo "=== METRIC COUNT ===" && \
curl -s http://localhost:9868/metrics 2>/dev/null | grep -c "^wanguard_" && \
echo "" && \
echo "=== PORTS ===" && \
ss -tulpn 2>/dev/null | grep -E "9868|8081"
```

## Individual Checks

### 1. Check Tunnel Service
```bash
# Status
sudo systemctl status wanguard-tunnel.service

# Is it enabled?
sudo systemctl is-enabled wanguard-tunnel.service

# Logs
sudo journalctl -u wanguard-tunnel.service -n 20 --no-pager
```

### 2. Check Docker Container
```bash
# Status
sudo docker ps --filter name=wanguard_exporter

# All states (including stopped)
sudo docker ps -a --filter name=wanguard_exporter

# Logs
sudo docker logs wanguard_exporter --tail 50

# Real-time logs
sudo docker logs wanguard_exporter --follow
```

### 3. Check Metrics
```bash
# API connection status
curl -s http://localhost:9868/metrics | grep wanguard_api_up

# All wanguard metrics
curl -s http://localhost:9868/metrics | grep "^wanguard_"

# Count metrics
curl -s http://localhost:9868/metrics | grep -c "^wanguard_"

# Sample metrics (first 20)
curl -s http://localhost:9868/metrics | grep "^wanguard_" | head -20
```

### 4. Check Ports
```bash
# Check both ports
ss -tulpn | grep -E "9868|8081"

# Check tunnel port only
ss -tulpn | grep 8081

# Check exporter port only
ss -tulpn | grep 9868
```

### 5. Test Tunnel
```bash
# Test tunnel forwards to WANGuard API
curl -s -I http://127.0.0.1:8081/wanguard-api/

# Should show HTTP response from WANGuard
```

## Troubleshooting Commands

### If Tunnel Service is Down
```bash
# Start tunnel
sudo systemctl start wanguard-tunnel.service

# Enable auto-start on boot
sudo systemctl enable wanguard-tunnel.service

# Restart tunnel
sudo systemctl restart wanguard-tunnel.service

# Check why it failed
sudo journalctl -u wanguard-tunnel.service -xe
```

### If Container is Down
```bash
# Check why it stopped
sudo docker logs wanguard_exporter --tail 100

# Restart container
sudo docker restart wanguard_exporter

# Remove and recreate (CAREFUL!)
sudo docker rm -f wanguard_exporter
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

### If Metrics Show API Down (wanguard_api_up = 0)
```bash
# 1. Test tunnel
curl -s -I http://127.0.0.1:8081/wanguard-api/

# 2. Test direct API (should fail if HTTPS enforcement works)
curl -s -I http://10.251.196.19:80/wanguard-api/

# 3. Check container logs for errors
sudo docker logs wanguard_exporter --tail 50 | grep -i error

# 4. Restart both tunnel and container
sudo systemctl restart wanguard-tunnel.service
sleep 2
sudo docker restart wanguard_exporter
```

### Check System Resources
```bash
# Memory
free -h

# Disk
df -h

# CPU and load
top -bn1 | head -15

# Process count
ps aux | wc -l

# Docker stats
sudo docker stats --no-stream
```

## Verification Script

Upload and run the complete verification script:

```bash
# On your local machine (in wanguard_exporter directory)
scp scripts/verify-deployment.sh ubuntu@10.251.196.19:~/

# On the server
chmod +x ~/verify-deployment.sh
./verify-deployment.sh
```

## Prometheus Integration Check

### If Prometheus is on the same server
```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="wanguard-metrics")'

# Check if scraping is working
curl -s http://localhost:9090/api/v1/query?query=wanguard_api_up
```

### Check Prometheus config
```bash
# View config
cat /etc/prometheus/prometheus.yml | grep -A 5 wanguard

# Or if using Docker
sudo docker exec prometheus cat /etc/prometheus/prometheus.yml | grep -A 5 wanguard
```

## Quick Fixes

### Restart Everything
```bash
# Nuclear option - restart all services
sudo systemctl restart wanguard-tunnel.service && \
sudo docker restart wanguard_exporter && \
sleep 5 && \
curl -s http://localhost:9868/metrics | grep wanguard_api_up
```

### Check for Port Conflicts
```bash
# Check what's using port 9868
sudo lsof -i :9868

# Check what's using port 8081
sudo lsof -i :8081

# Kill process on port (if needed)
sudo fuser -k 9868/tcp
```

### View All WANGuard Processes
```bash
# Find all related processes
ps aux | grep -E "wanguard|socat|docker.*exporter"

# Check systemd services
systemctl list-units --type=service | grep wanguard
```

## System Maintenance

### Reboot (System Restart Required)
```bash
# Check why reboot is needed
cat /var/run/reboot-required.pkgs

# Schedule reboot
sudo shutdown -r +5 "System reboot for kernel update"

# Or reboot now
sudo reboot
```

### Update System (if needed)
```bash
# List updates
apt list --upgradable

# Apply updates (CAREFUL in production!)
sudo apt update && sudo apt upgrade -y

# Security updates only
sudo apt update && sudo apt upgrade -y --security
```

## Logs Export

### Export all relevant logs
```bash
# Create logs directory
mkdir -p ~/wanguard_logs

# Export tunnel logs
sudo journalctl -u wanguard-tunnel.service -n 500 > ~/wanguard_logs/tunnel.log

# Export container logs
sudo docker logs wanguard_exporter --tail 500 > ~/wanguard_logs/exporter.log

# Export metrics snapshot
curl -s http://localhost:9868/metrics > ~/wanguard_logs/metrics.txt

# Create tarball
tar -czf ~/wanguard_logs_$(date +%Y%m%d_%H%M%S).tar.gz -C ~ wanguard_logs/

# Download to local machine
# scp ubuntu@10.251.196.19:~/wanguard_logs_*.tar.gz .
```

## Expected Outputs

### Healthy System
```
# wanguard_api_up should be 1
wanguard_api_up{api_address="127.0.0.1:8081"} 1

# Metric count should be > 20
curl -s http://localhost:9868/metrics | grep -c "^wanguard_"
# Output: 25-50 (depending on collectors enabled)

# Container status
wanguard_exporter   Up 5 hours   0.0.0.0:9868->9868/tcp

# Tunnel service
Active: active (running) since ...
```

### Unhealthy System
```
# API down
wanguard_api_up{api_address="127.0.0.1:8081"} 0

# Low metric count
curl -s http://localhost:9868/metrics | grep -c "^wanguard_"
# Output: 0-5

# Container restarting
wanguard_exporter   Restarting (1) 5 seconds ago
```

## Next Steps After Verification

1. **If everything is healthy**: Import Grafana dashboard
2. **If API is down**: Check tunnel and WANGuard API credentials
3. **If container is crashing**: Check logs and disable more collectors
4. **If metrics are missing**: Verify collector flags and API permissions

## Reference Docs
- Deployment Workarounds: `docs/DEPLOYMENT_WORKAROUNDS.md`
- Grafana Dashboard: `docs/GRAFANA_DASHBOARD_GUIDE.md`
- Docker Quickstart: `DOCKER_QUICKSTART.md`
