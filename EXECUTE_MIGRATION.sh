#!/bin/bash
# WANGuard Exporter - Migration Execution Guide
# Execute este script do seu Mac para fazer a migração completa

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "WANGuard Exporter - Migration Execution"
echo -e "==========================================${NC}"
echo ""

# Step 1: Upload files
echo -e "${BLUE}Step 1: Uploading files to server...${NC}"
echo "Uploading docker-compose.yml, .env, docker/, scripts/"

scp docker-compose.yml .env ubuntu@10.251.196.19:~/wanguard_exporter/
scp -r docker/ ubuntu@10.251.196.19:~/wanguard_exporter/
scp -r scripts/ ubuntu@10.251.196.19:~/wanguard_exporter/

echo -e "${GREEN}✓ Files uploaded${NC}"
echo ""

# Step 2: Make scripts executable
echo -e "${BLUE}Step 2: Setting executable permissions...${NC}"
ssh ubuntu@10.251.196.19 'chmod +x ~/wanguard_exporter/scripts/*.sh'
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Step 3: Check current logs BEFORE migration
echo -e "${BLUE}Step 3: Checking current exporter logs...${NC}"
echo "Looking for errors in current deployment:"
ssh ubuntu@10.251.196.19 'sudo docker logs wanguard_exporter --tail 30 2>&1 | grep -i "error\|panic\|fatal" || echo "No critical errors found"'
echo ""

# Step 4: Verify tunnel service
echo -e "${BLUE}Step 4: Verifying tunnel service...${NC}"
ssh ubuntu@10.251.196.19 'sudo systemctl is-active wanguard-tunnel.service && echo "✓ Tunnel is running" || echo "✗ Tunnel is NOT running"'
echo ""

# Step 5: Execute migration script
echo -e "${BLUE}Step 5: Running migration script...${NC}"
echo "This will:"
echo "  - Backup current container"
echo "  - Stop and remove old container"
echo "  - Start docker-compose stack (exporter + Prometheus + Grafana)"
echo "  - Validate services"
echo ""
read -p "Press ENTER to continue or Ctrl+C to cancel..."

ssh ubuntu@10.251.196.19 'cd ~/wanguard_exporter && sudo bash scripts/migrate-to-compose.sh'
echo ""

# Step 6: Verify deployment
echo -e "${BLUE}Step 6: Verifying deployment...${NC}"
ssh ubuntu@10.251.196.19 'cd ~/wanguard_exporter && ./scripts/verify-deployment.sh'
echo ""

# Step 7: Show service URLs
echo -e "${GREEN}=========================================="
echo "MIGRATION COMPLETE!"
echo -e "==========================================${NC}"
echo ""
echo "Service URLs:"
echo "  Exporter:   http://10.251.196.19:9868/metrics"
echo "  Prometheus: http://10.251.196.19:9090"
echo "  Grafana:    http://10.251.196.19:3000 (admin/admin)"
echo ""
echo "Dashboard: 'WANGuard DDoS Monitoring' (auto-imported)"
echo ""
echo "Management commands (on server):"
echo "  docker-compose ps           # View status"
echo "  docker-compose logs -f      # View logs"
echo "  docker-compose restart      # Restart services"
echo ""
