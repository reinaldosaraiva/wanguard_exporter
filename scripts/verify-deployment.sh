#!/bin/bash
# WANGuard Exporter Deployment Verification Script
# Based on: docs/DEPLOYMENT_WORKAROUNDS.md

set -e

echo "=========================================="
echo "WANGuard Exporter - Deployment Check"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check socat tunnel service
echo "1. Checking socat tunnel service..."
if systemctl is-active --quiet wanguard-tunnel.service; then
    echo -e "${GREEN}✓ wanguard-tunnel.service is RUNNING${NC}"
    systemctl status wanguard-tunnel.service --no-pager | head -5
else
    echo -e "${RED}✗ wanguard-tunnel.service is NOT RUNNING${NC}"
    echo "Fix: sudo systemctl start wanguard-tunnel.service"
fi
echo ""

# 2. Check tunnel port
echo "2. Checking tunnel port 8081..."
if ss -tulpn 2>/dev/null | grep -q ":8081"; then
    echo -e "${GREEN}✓ Port 8081 is LISTENING${NC}"
    ss -tulpn 2>/dev/null | grep ":8081"
else
    echo -e "${RED}✗ Port 8081 is NOT LISTENING${NC}"
fi
echo ""

# 3. Check Docker container
echo "3. Checking wanguard_exporter container..."
if sudo docker ps --filter name=wanguard_exporter --format "{{.Status}}" | grep -q "Up"; then
    echo -e "${GREEN}✓ Container is RUNNING${NC}"
    sudo docker ps --filter name=wanguard_exporter --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo -e "${RED}✗ Container is NOT RUNNING${NC}"
    sudo docker ps -a --filter name=wanguard_exporter --format "table {{.Names}}\t{{.Status}}"
fi
echo ""

# 4. Check exporter port
echo "4. Checking exporter port 9868..."
if ss -tulpn 2>/dev/null | grep -q ":9868"; then
    echo -e "${GREEN}✓ Port 9868 is LISTENING${NC}"
    ss -tulpn 2>/dev/null | grep ":9868"
else
    echo -e "${RED}✗ Port 9868 is NOT LISTENING${NC}"
fi
echo ""

# 5. Test tunnel connectivity
echo "5. Testing tunnel connectivity to WANGuard API..."
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/wanguard-api/ | grep -q "200\|401"; then
    echo -e "${GREEN}✓ Tunnel is forwarding traffic${NC}"
else
    echo -e "${YELLOW}⚠ Tunnel may not be working (check WANGuard API)${NC}"
fi
echo ""

# 6. Test exporter metrics
echo "6. Testing exporter metrics endpoint..."
if curl -s http://localhost:9868/metrics | grep -q "wanguard_api_up"; then
    echo -e "${GREEN}✓ Exporter is responding${NC}"
    API_STATUS=$(curl -s http://localhost:9868/metrics | grep "wanguard_api_up" | tail -1)
    echo "Metric: $API_STATUS"

    if echo "$API_STATUS" | grep -q "wanguard_api_up.*1$"; then
        echo -e "${GREEN}✓ API connection is UP${NC}"
    else
        echo -e "${RED}✗ API connection is DOWN${NC}"
    fi
else
    echo -e "${RED}✗ Exporter is NOT responding${NC}"
fi
echo ""

# 7. Check recent container logs
echo "7. Recent container logs (last 10 lines)..."
sudo docker logs wanguard_exporter --tail 10 2>&1
echo ""

# 8. Check tunnel logs
echo "8. Recent tunnel logs (last 10 lines)..."
sudo journalctl -u wanguard-tunnel.service -n 10 --no-pager
echo ""

# 9. Summary metrics
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
METRIC_COUNT=$(curl -s http://localhost:9868/metrics 2>/dev/null | grep -c "^wanguard_" || echo "0")
echo "Total wanguard metrics: $METRIC_COUNT"

if [ "$METRIC_COUNT" -gt 10 ]; then
    echo -e "${GREEN}✓ Deployment appears HEALTHY${NC}"
else
    echo -e "${YELLOW}⚠ Low metric count - check configuration${NC}"
fi
echo ""

# 10. System health
echo "=========================================="
echo "SYSTEM HEALTH"
echo "=========================================="
echo "Uptime: $(uptime -p)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"

if [ -f /var/run/reboot-required ]; then
    echo -e "${YELLOW}⚠ System restart required (kernel update pending)${NC}"
fi
echo ""

echo "=========================================="
echo "VERIFICATION COMPLETE"
echo "=========================================="
