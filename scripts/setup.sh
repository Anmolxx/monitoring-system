#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Monitoring System - Setup & Deployment Script           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Check for required tools
echo -e "\n${BLUE}[1/6] Checking for required tools...${NC}"

REQUIRED_TOOLS=("terraform" "aws" "docker" "docker-compose" "git" "curl")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
        echo -e "${RED}✗${NC} $tool not found"
    else
        echo -e "${GREEN}✓${NC} $tool installed"
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing tools: ${MISSING_TOOLS[*]}${NC}"
    echo "Please install missing tools and try again."
    exit 1
fi

# Prompt for configuration
echo -e "\n${BLUE}[2/6] Gathering configuration...${NC}"

read -p "AWS Region (default: us-east-1): " AWS_REGION
AWS_REGION="${AWS_REGION:-us-east-1}"

read -p "Alert Email (for notifications): " ALERT_EMAIL
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"

read -p "Instance Type (default: t3.medium): " INSTANCE_TYPE
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"

read -p "Project Name (default: monitoring-system): " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-monitoring-system}"

# Create .env file
echo -e "\n${BLUE}[3/6] Creating environment file...${NC}"
cat > "$ENV_FILE" <<EOF
AWS_REGION=$AWS_REGION
ALERT_EMAIL=$ALERT_EMAIL
INSTANCE_TYPE=$INSTANCE_TYPE
PROJECT_NAME=$PROJECT_NAME
GF_SECURITY_ADMIN_PASSWORD=admin123
GF_USERS_ALLOW_SIGN_UP=false
GF_SMTP_ENABLED=false
GF_ALERT_EMAIL=$ALERT_EMAIL
EOF

echo -e "${GREEN}✓${NC} Environment file created at $ENV_FILE"
cat "$ENV_FILE"

# Initialize and plan Terraform
echo -e "\n${BLUE}[4/6] Initializing Terraform...${NC}"
cd "$PROJECT_ROOT/terraform"

terraform init

echo -e "\n${BLUE}[4/6] Planning Terraform deployment...${NC}"
terraform plan -var-file="/dev/null" \
    -var="aws_r\
    -var="aws_region=$AWS_REGIONTANCE_TYPE" \
    -var="project_name=$PROJECT_NAME" \
    -out=tfplan

echo -e "\n${YELLOW}Review the plan above.${NC}"
read -p "Do you want to proceed with terraform apply? (yes/no): " PROCEED

if [ "$PROCEED" != "yes" ]; then
    echo -e "${YELLOW}Setup cancelled by user${NC}"
    exit 0
fi

# Apply Terraform
echo -e "\n${BLUE}[5/6] Applying Terraform configuration...${NC}"
terraform apply -auto-approve tfplan

echo -e "\n${YELLOW}Terraform apply completed. Resources are being created...${NC}"
echo -e "${YELLOW}This typically takes 5-10 minutes for EC2 and initial setup.${NC}"

# Get outputs
echo -e "\n${BLUE}Getting deployment information...${NC}"
INSTANCE_IP=$(terraform output -raw instance_public_ip)
INSTANCE_DNS=$(terraform output -raw instance_public_dns)
ELASTIC_IP=$(terraform output -raw elastic_ip)

PEM_FILE=$(terraform output -raw private_key_path)
SSH_CMD=$(terraform output -raw ssh_command)

echo -e "${GREEN}✓ Instance IP: $INSTANCE_IP${NC}"
echo -e "${GREEN}✓ Instance DNS: $INSTANCE_DNS${NC}"
echo -e "${GREEN}✓ Elastic IP: $ELASTIC_IP${NC}"
echo ""
echo -e "${GREEN}PEM key saved to: $PEM_FILE${NC}"
echo -e "${GREEN}Connect with:     $SSH_CMD
# Wait for instance to boot
echo -e "\n${BLUE}[6/6] Waiting for EC2 instance to boot and initialize...${NC}"
echo "This typically takes 2-3 minutes..."

PEM_FILE=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw private_key_path)
EC2_IP=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw elastic_ip)

for i in {1..60}; do
    if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
        ubuntu@"$EC2_IP" "docker ps" &>/dev/null; then
        echo -e "${GREEN}✓ Instance is ready${NC}"
        break
    fi
    echo -n "."
    sleep 5
done

echo -e "\n"

# Verify services
echo -e "${BLUE}Verifying services...${NC}"

if ssh -i "$PEM_FILE" ubuntu@"$EC2_IP" "sudo systemctl status node_exporter" &>/dev/null; then
    echo -e "${GREEN}✓ Node Exporter is running${NC}"
else
    echo -e "${YELLOW}⚠${NC} Node Exporter status check failed"
fi

if ssh -i "$PEM_FILE" ubuntu@"$EC2_IP" "docker ps | grep -E 'demo-app|prometheus|grafana'" &>/dev/null; then
    echo -e "${GREEN}✓ Monitoring services are running${NC}"
else
    echo -e "${YELLOW}⚠${NC} Some Docker services may still be starting"
fi

# Display access information
echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}            ✅ Setup Complete - Access Your System${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}SSH Access:${NC}"
echo -e "  $SSH_CMD"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo -e "  ${YELLOW}Demo Application:${NC}  http://${INSTANCE_IP}:5000"
echo -e "  ${YELLOW}Prometheus:${NC}        http://${INSTANCE_IP}:9090"
echo -e "  ${YELLOW}Grafana:${NC}           http://${INSTANCE_IP}:3000"
echo -e "  ${YELLOW}Loki:${NC}              http://${INSTANCE_IP}:3100"
echo -e "  ${YELLOW}Promtail:${NC}          http://${INSTANCE_IP}:9080"
echo -e "  ${YELLOW}Node Exporter:${NC}     http://${INSTANCE_IP}:9100"
echo ""
echo -e "${BLUE}Grafana Login:${NC}"
echo -e "  Username: admin"
echo -e "  Password: admin123"
echo ""
echo -e "${BLUE}Test the Application:${NC}"
echo -e "  Health check: curl http://${INSTANCE_IP}:5000/health"
echo -e "  Metrics:      curl http://${INSTANCE_IP}:5000/metrics"
echo -e "  Load test:    curl http://${INSTANCE_IP}:5000/simulate/load"
echo -e "  Error test:   curl http://${INSTANCE_IP}:5000/simulate/error"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"

# Save deployment info
echo -e "\n${BLUE}Saving deployment information...${NC}"
cat > "$PROJECT_ROOT/DEPLOY_INFO.txt" <<EOF
Monitoring System Deployment Information
========================================
Date: $(date)

AWS Configuration:
  Region: $AWS_REGION
  Instance Type: $INSTANCE_TYPE

Deployment URLs:
  Instance IP: $INSTANCE_IP
  Instance DNS: $INSTANCE_DNS
  Elastic IP: $ELASTIC_IP

SSH Key:
  Location: $PEM_FILE
  Command: $SSH_CMD

Service URLs:
  Application: http://$INSTANCE_IP:5000
  Prometheus: http://$INSTANCE_IP:9090
  Grafana: http://$INSTANCE_IP:3000 (admin/admin123)
  Loki: http://$INSTANCE_IP:3100
  Promtail: http://$INSTANCE_IP:9080

Cleanup:
  cd terraform && terraform destroy
EOF

echo -e "${GREEN}✓ Deployment info saved to DEPLOY_INFO.txt${NC}"
echo ""
echo -e "${GREEN}✅ Setup completed successfully!${NC}"
