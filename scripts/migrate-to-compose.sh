#!/bin/bash
# Migration script: docker run → docker-compose
# Safe migration with log checks and rollback capability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "WANGuard Exporter - Docker Compose Migration"
echo -e "==========================================${NC}"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠ This script requires sudo for Docker commands${NC}"
    echo "Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# Step 1: Check if old container exists
echo -e "${BLUE}Step 1: Checking existing deployment...${NC}"
if docker ps -a --filter name=wanguard_exporter --format "{{.Names}}" | grep -q wanguard_exporter; then
    echo -e "${GREEN}✓ Found existing container 'wanguard_exporter'${NC}"
    CONTAINER_EXISTS=true
else
    echo -e "${YELLOW}⚠ No existing container found - fresh install${NC}"
    CONTAINER_EXISTS=false
fi
echo ""

# Step 2: Check tunnel service (CRITICAL)
echo -e "${BLUE}Step 2: Verifying socat tunnel service...${NC}"
if systemctl is-active --quiet wanguard-tunnel.service; then
    echo -e "${GREEN}✓ wanguard-tunnel.service is RUNNING${NC}"

    # Test tunnel connectivity
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/wanguard-api/ | grep -q "200\|401"; then
        echo -e "${GREEN}✓ Tunnel is forwarding traffic${NC}"
    else
        echo -e "${RED}✗ Tunnel is not responding correctly${NC}"
        echo "Fix: sudo systemctl restart wanguard-tunnel.service"
        exit 1
    fi
else
    echo -e "${RED}✗ wanguard-tunnel.service is NOT RUNNING${NC}"
    echo "The exporter REQUIRES the tunnel to bypass HTTPS enforcement."
    echo ""
    read -p "Start tunnel service now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        systemctl start wanguard-tunnel.service
        sleep 2
        if systemctl is-active --quiet wanguard-tunnel.service; then
            echo -e "${GREEN}✓ Tunnel started successfully${NC}"
        else
            echo -e "${RED}✗ Failed to start tunnel${NC}"
            exit 1
        fi
    else
        exit 1
    fi
fi
echo ""

# Step 3: Check logs for errors (if container exists)
if [ "$CONTAINER_EXISTS" = true ]; then
    echo -e "${BLUE}Step 3: Checking exporter logs for errors...${NC}"

    # Check if container is running
    if docker ps --filter name=wanguard_exporter --format "{{.Status}}" | grep -q "Up"; then
        LOGS=$(docker logs wanguard_exporter --tail 50 2>&1)

        # Check for critical errors
        if echo "$LOGS" | grep -iq "panic\|fatal\|error.*critical"; then
            echo -e "${YELLOW}⚠ Found potential errors in logs:${NC}"
            echo "$LOGS" | grep -i "panic\|fatal\|error" | tail -10
            echo ""
            read -p "Continue with migration? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Migration cancelled."
                exit 1
            fi
        else
            echo -e "${GREEN}✓ No critical errors in logs${NC}"
        fi

        # Check API connection
        API_UP=$(echo "$LOGS" | grep -o "wanguard_api_up.*" | tail -1 || echo "")
        if echo "$API_UP" | grep -q "wanguard_api_up.*1"; then
            echo -e "${GREEN}✓ API connection is UP${NC}"
        elif echo "$API_UP" | grep -q "wanguard_api_up.*0"; then
            echo -e "${RED}✗ API connection is DOWN${NC}"
            echo "This may affect the new deployment."
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Container is not running - checking last logs${NC}"
        docker logs wanguard_exporter --tail 20 2>&1 || true
    fi
else
    echo -e "${BLUE}Step 3: Skipped (no existing container)${NC}"
fi
echo ""

# Step 4: Check if docker-compose.yml exists
echo -e "${BLUE}Step 4: Verifying docker-compose.yml...${NC}"
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}✗ docker-compose.yml not found in current directory${NC}"
    echo "Please run this script from the wanguard_exporter directory."
    exit 1
fi
echo -e "${GREEN}✓ docker-compose.yml found${NC}"
echo ""

# Step 5: Check .env file
echo -e "${BLUE}Step 5: Verifying .env file...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env file not found - creating from template${NC}"
    cat > .env <<EOF
# WANGuard API Configuration
WANGUARD_API_ADDRESS=http://127.0.0.1:8081/wanguard-api/
WANGUARD_API_USERNAME=api
WANGUARD_API_PASSWORD=api

# Collectors Configuration
WANGUARD_DISABLED_COLLECTORS=firewall_rules

# Exporter Configuration
WANGUARD_EXPORTER_PORT=9868

# Prometheus Configuration
PROMETHEUS_PORT=9090

# Grafana Configuration
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
EOF
    echo -e "${GREEN}✓ Created default .env file${NC}"
    echo -e "${YELLOW}⚠ Please review .env and update credentials if needed${NC}"
    echo ""
    read -p "Edit .env now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        nano .env
    fi
else
    echo -e "${GREEN}✓ .env file found${NC}"
fi
echo ""

# Step 6: Backup old container (if exists)
if [ "$CONTAINER_EXISTS" = true ]; then
    echo -e "${BLUE}Step 6: Creating backup...${NC}"
    BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    # Export logs
    docker logs wanguard_exporter > "$BACKUP_DIR/container.log" 2>&1 || true

    # Export container config
    docker inspect wanguard_exporter > "$BACKUP_DIR/container.json" 2>&1 || true

    echo -e "${GREEN}✓ Backup created in: $BACKUP_DIR${NC}"
else
    echo -e "${BLUE}Step 6: Skipped (no existing container)${NC}"
fi
echo ""

# Step 7: Stop and remove old container
if [ "$CONTAINER_EXISTS" = true ]; then
    echo -e "${BLUE}Step 7: Stopping old container...${NC}"

    if docker ps --filter name=wanguard_exporter --format "{{.Names}}" | grep -q wanguard_exporter; then
        docker stop wanguard_exporter
        echo -e "${GREEN}✓ Container stopped${NC}"
    fi

    docker rm wanguard_exporter
    echo -e "${GREEN}✓ Container removed${NC}"
else
    echo -e "${BLUE}Step 7: Skipped (no existing container)${NC}"
fi
echo ""

# Step 8: Pull/build images
echo -e "${BLUE}Step 8: Verifying images...${NC}"

# Check if wanguard-exporter:final exists
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "wanguard-exporter:final"; then
    echo -e "${GREEN}✓ Image 'wanguard-exporter:final' exists${NC}"
else
    echo -e "${YELLOW}⚠ Image 'wanguard-exporter:final' not found${NC}"
    echo "Building image..."
    docker build -t wanguard-exporter:final .
fi

# Pull Prometheus and Grafana
docker-compose pull prometheus grafana
echo ""

# Step 9: Start docker-compose stack
echo -e "${BLUE}Step 9: Starting docker-compose stack...${NC}"
docker-compose up -d
echo ""

# Step 10: Wait for services to start
echo -e "${BLUE}Step 10: Waiting for services to start...${NC}"
sleep 10

# Check exporter health
echo "Checking wanguard-exporter..."
if docker ps --filter name=wanguard_exporter --format "{{.Status}}" | grep -q "Up"; then
    echo -e "${GREEN}✓ wanguard-exporter is running${NC}"
else
    echo -e "${RED}✗ wanguard-exporter failed to start${NC}"
    docker logs wanguard_exporter --tail 20
    exit 1
fi

# Check Prometheus
echo "Checking Prometheus..."
if docker ps --filter name=prometheus --format "{{.Status}}" | grep -q "Up"; then
    echo -e "${GREEN}✓ Prometheus is running${NC}"
else
    echo -e "${RED}✗ Prometheus failed to start${NC}"
    docker logs prometheus --tail 20
fi

# Check Grafana
echo "Checking Grafana..."
if docker ps --filter name=grafana --format "{{.Status}}" | grep -q "Up"; then
    echo -e "${GREEN}✓ Grafana is running${NC}"
else
    echo -e "${RED}✗ Grafana failed to start${NC}"
    docker logs grafana --tail 20
fi
echo ""

# Step 11: Verify metrics
echo -e "${BLUE}Step 11: Verifying metrics endpoint...${NC}"
sleep 5  # Wait a bit more for exporter to initialize

if curl -s http://localhost:9868/metrics | grep -q "wanguard_api_up"; then
    echo -e "${GREEN}✓ Metrics endpoint is responding${NC}"

    API_STATUS=$(curl -s http://localhost:9868/metrics | grep "wanguard_api_up" | tail -1)
    echo "Status: $API_STATUS"

    if echo "$API_STATUS" | grep -q "wanguard_api_up.*1$"; then
        echo -e "${GREEN}✓ API connection is UP${NC}"
    else
        echo -e "${YELLOW}⚠ API connection is DOWN - check credentials${NC}"
    fi
else
    echo -e "${RED}✗ Metrics endpoint is not responding${NC}"
    echo "Checking logs..."
    docker logs wanguard_exporter --tail 20
fi
echo ""

# Step 12: Summary
echo -e "${BLUE}=========================================="
echo "MIGRATION SUMMARY"
echo -e "==========================================${NC}"

# Service URLs
echo -e "${GREEN}Service URLs:${NC}"
echo "  Exporter: http://localhost:9868/metrics"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana: http://localhost:3000"
echo ""

echo -e "${GREEN}Grafana Credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin (from .env)"
echo ""

echo -e "${GREEN}Management Commands:${NC}"
echo "  View logs: docker-compose logs -f"
echo "  Restart: docker-compose restart"
echo "  Stop: docker-compose down"
echo "  Update: docker-compose pull && docker-compose up -d"
echo ""

# Count metrics
METRIC_COUNT=$(curl -s http://localhost:9868/metrics 2>/dev/null | grep -c "^wanguard_" || echo "0")
echo "Total wanguard metrics: $METRIC_COUNT"
echo ""

if [ "$METRIC_COUNT" -gt 10 ]; then
    echo -e "${GREEN}✓ Migration SUCCESSFUL!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Access Grafana: http://localhost:3000"
    echo "2. Dashboard auto-imported: 'WANGuard DDoS Monitoring'"
    echo "3. Monitor logs: docker-compose logs -f wanguard-exporter"
else
    echo -e "${YELLOW}⚠ Migration completed but metric count is low${NC}"
    echo "Check exporter logs: docker-compose logs wanguard-exporter"
fi

echo ""
echo -e "${BLUE}=========================================="
echo "MIGRATION COMPLETE"
echo -e "==========================================${NC}"
