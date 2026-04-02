#!/bin/bash
set -euo pipefail

# Update system packages
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install prerequisites
echo "Installing prerequisites..."
apt-get install -y \
  curl \
  wget \
  unzip \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

# Install Docker CE from official repository
echo "Installing Docker CE..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
echo "Configuring docker group permissions..."
usermod -aG docker ubuntu

# Set Docker daemon options for better monitoring
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker

# Wait for docker to be ready
sleep 5

# Install Node Exporter as a systemd service
echo "Installing Node Exporter..."
NODE_EXPORTER_VERSION="1.7.0"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Create node_exporter system user
if ! id -u node_exporter > /dev/null 2>&1; then
  useradd --no-create-home --shell /bin/false node_exporter
fi

# Download and extract Node Exporter
cd /tmp
wget -q "${NODE_EXPORTER_URL}"
tar xf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd service for Node Exporter
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.filesystem.mount-points-exclude=^/(dev|proc|sys)(\$|/) \
  --collector.netdev.device-exclude=^(veth.*|br-.*|docker.*)

Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "Node Exporter started and enabled"

# Create monitoring directory
echo "Creating monitoring directory..."
mkdir -p /opt/monitoring
chown ubuntu:ubuntu /opt/monitoring
cd /opt/monitoring

# Clone repository (using provided GIT_REPO_URL or fallback)
echo "Cloning monitoring system repository..."
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/your-org/monitoring-system.git}"
if git ls-remote "${GIT_REPO_URL}" > /dev/null 2>&1; then
  git clone "${GIT_REPO_URL}" . || echo "Note: Could not clone from ${GIT_REPO_URL}, continuing setup..."
else
  echo "Note: Git repository not accessible at ${GIT_REPO_URL}"
  # Repository structure should already be in place from Terraform
fi

# Create .env file if it doesn't exist
if [ ! -f /opt/monitoring/.env ]; then
  cat > /opt/monitoring/.env <<EOF
GF_SECURITY_ADMIN_PASSWORD=admin123
GF_USERS_ALLOW_SIGN_UP=false
GF_SMTP_ENABLED=false
GF_SMTP_HOST=smtp.gmail.com:587
GF_SMTP_USER=
GF_SMTP_PASSWORD=
GF_ALERT_EMAIL=admin@example.com
EOF
  chown ubuntu:ubuntu /opt/monitoring/.env
fi

# Change to docker directory and start services
if [ -f /opt/monitoring/docker/docker-compose.yml ]; then
  echo "Starting Docker Compose services..."
  cd /opt/monitoring/docker
  sudo -u ubuntu docker compose up -d --build 2>&1 || true
  sleep 30
  echo "Checking service health..."
  docker compose ps
fi

echo "Setup completed successfully!"
