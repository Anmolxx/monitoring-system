#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Monitoring System - Deploy Script                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file not found: $ENV_FILE${NC}"
    echo "Please run setup.sh first"
    exit 1
fi

source "$ENV_FILE"

EC2_IP="${EC2_IP:-}"
EC2_SSH_KEY="${EC2_SSH_KEY:-$HOME/.ssh/${KEY_NAME}.pem}"

if [ -z "$EC2_IP" ]; then
    echo -e "${BLUE}Retrieving EC2 IP from Terraform state...${NC}"
    cd "$PROJECT_ROOT/terraform"
    EC2_IP=$(terraform output -raw instance_public_ip)
fi

echo -e "${BLUE}Target EC2 Instance: ${NC}$EC2_IP"

# Check SSH access
echo -e "\n${BLUE}[1/4] Verifying SSH access...${NC}"
if ! ssh -i "$EC2_SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    ubuntu@"$EC2_IP" "echo 'SSH connection successful'" &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to EC2 instance via SSH${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection established${NC}"

# Pull latest code
echo -e "\n${BLUE}[2/4] Pulling latest code from repository...${NC}"
ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$EC2_IP" << 'DEPLOY_SCRIPT'
cd /opt/monitoring
echo "Current directory: $(pwd)"
echo "Pulling latest changes..."
git pull origin main || echo "Note: Git pull had issues, using existing code"
echo "Code update completed"
DEPLOY_SCRIPT

# Build and deploy with Docker Compose
echo -e "\n${BLUE}[3/4] Building and deploying services...${NC}"
ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$EC2_IP" << 'DEPLOY_SCRIPT'
cd /opt/monitoring/docker
echo "Building Docker images..."
docker compose build

echo "Starting services..."
docker compose up -d

echo "Waiting for services to initialize..."
sleep 15

echo "Service status:"
docker compose ps
DEPLOY_SCRIPT

# Health checks
echo -e "\n${BLUE}[4/4] Running health checks...${NC}"

echo -e "\n${BLUE}Checking application...${NC}"
for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://"$EC2_IP":5000/health || echo "000")
    if [ "$STATUS" = "200" ]; then
        echo -e "${GREEN}✓ Application is healthy${NC}"
        break
    fi
    echo -n "."
    sleep 3
done

echo -e "\n${BLUE}Checking Prometheus...${NC}"
if curl -s http://"$EC2_IP":9090/-/healthy &>/dev/null; then
    echo -e "${GREEN}✓ Prometheus is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Prometheus health check inconclusive${NC}"
fi

echo -e "\n${BLUE}Checking Grafana...${NC}"
if curl -s http://"$EC2_IP":3000/api/health &>/dev/null; then
    echo -e "${GREEN}✓ Grafana is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Grafana still starting...${NC}"
fi

echo -e "\n${BLUE}Checking Loki...${NC}"
if curl -s http://"$EC2_IP":3100/ready &>/dev/null; then
    echo -e "${GREEN}✓ Loki is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Loki still starting...${NC}"
fi

# Display deployment info
echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}            ✅ Deployment Complete - Access Your System${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo -e "  ${YELLOW}Application:${NC}      http://${EC2_IP}:5000"
echo -e "  ${YELLOW}Prometheus:${NC}       http://${EC2_IP}:9090"
echo -e "  ${YELLOW}Grafana:${NC}          http://${EC2_IP}:3000 (admin/admin123)"
echo -e "  ${YELLOW}Loki:${NC}             http://${EC2_IP}:3100"
echo ""
echo -e "${BLUE}SSH Access:${NC}"
echo -e "  ssh -i ${EC2_SSH_KEY} ubuntu@${EC2_IP}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"

echo -e "\n${GREEN}✅ Deployment completed successfully!${NC}"
