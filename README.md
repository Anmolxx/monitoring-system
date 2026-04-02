# 📊 Full-Stack Monitoring & Logging System on AWS

A complete, production-ready monitoring and logging system built with Terraform, Docker, Prometheus, Loki, and Grafana.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS EC2 Instance (t3.medium)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Docker Network: monitoring                  │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │                                                          │  │
│  │  ┌─────────────┐     ┌──────────────┐                  │  │
│  │  │ Demo App    │────→│ Prometheus   │                  │  │
│  │  │ (Flask)     │     │ (Metrics)    │                  │  │
│  │  │ :5000       │     │ :9090        │                  │  │
│  │  └─────────────┘     └──────┬───────┘                  │  │
│  │         │                   │                           │  │
│  │         ↓                   │                           │  │
│  │  ┌─────────────┐            │    ┌──────────────────┐  │  │
│  │  │ Promtail    │            │    │ Grafana          │  │  │
│  │  │ (Log Ship)  │            └───→│ (Dashboards)     │  │  │
│  │  │ :9080       │                 │ :3000            │  │  │
│  │  └─────────────┘                 └────────┬─────────┘  │  │
│  │         │                                 │            │  │
│  │         ↓                                 ↓            │  │
│  │  ┌─────────────┐             ┌──────────────────┐     │  │
│  │  │ Loki        │             │ Alerting         │     │  │
│  │  │ (Log Store) │             │ (Email alerts)   │     │  │
│  │  │ :3100       │             │                  │     │  │
│  │  └─────────────┘             └──────────────────┘     │  │
│  │                                                          │  │
│  │  ┌─────────────────────────────────────────────────┐   │  │
│  │  │ Node Exporter (System Metrics) :9100           │   │  │
│  │  └─────────────────────────────────────────────────┘   │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  External Services:                                             │
│  • Jenkins CI/CD (:8080) - Optional deployment pipeline       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Quick Start

### Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** ≥ 1.6
- **AWS CLI** configured with credentials
- **Docker** & **Docker Compose** (optional, for local testing)

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/your-org/monitoring-system.git
cd monitoring-system
```

2. **Run the setup script:**
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The script will:
- Validate required tools
- Prompt for AWS configuration (region, alert email, instance type)
- Initialize Terraform
- Auto-generate a new EC2 key pair and save it to `terraform/monitoring-system-key.pem`
- Apply infrastructure with SSH automatically configured
- Wait for EC2 instance to boot
- Verify all services are running

3. **Access Your System**
After setup completes, you'll get:
- Access URLs for all services
- SSH key path (automatically generated in `terraform/` directory)
- Ready-to-use SSH command (printed on screen)

## 🌐 Service URLs & Credentials

| Service | URL | Port | Credentials |
|---------|-----|------|-------------|
| **Application** | `http://<IP>:5000` | 5000 | N/A |
| **Prometheus** | `http://<IP>:9090` | 9090 | N/A |
| **Grafana** | `http://<IP>:3000` | 3000 | admin / admin123 |
| **Loki** | `http://<IP>:3100` | 3100 | N/A |
| **Promtail** | `http://<IP>:9080` | 9080 | N/A |
| **Node Exporter** | `http://<IP>:9100` | 9100 | N/A |
| **Jenkins** | `http://<IP>:8080` | 8080 | N/A (CasC) |

Replace `<IP>` with your EC2 instance's public IP address.

## 🚀 Testing the System

### Test Health Endpoints

```bash
# Check app health
curl http://<IP>:5000/health

# Get app status
curl http://<IP>:5000/

# Retrieve metrics
curl http://<IP>:5000/metrics | head -20
```

### Simulate Load & Errors

```bash
# Simulate CPU-intensive load (2 seconds)
curl http://<IP>:5000/simulate/load

# Simulate an error (returns 500)
curl http://<IP>:5000/simulate/error

# Get random data
curl http://<IP>:5000/data
```

### View Logs

```bash
# SSH into the instance
ssh -i ~/.ssh/<KEY_NAME>.pem ubuntu@<IP>

# View Docker Compose logs
cd /opt/monitoring/docker
docker compose logs -f app
docker compose logs -f prometheus
docker compose logs -f grafana
```

## 📊 Grafana Configuration

### Default Dashboard
- **Name:** "System & Application Monitoring"
- **UID:** `monitoring-main`
- **Panels:**
  1. CPU Usage (timeseries with thresholds)
  2. Memory Usage (gauge)
  3. HTTP Request Rate (timeseries by method/endpoint)
  4. Request Duration p95 (histogram quantile)
  5. Error Rate (stat panel, red when > 0)
  6. Total Requests (stat)
  7. Application Logs (from Loki)
  8. Error Logs (filtered Loki query)

### Alert Rules
- **High CPU Alert:** Triggered when CPU > 85% for 2 minutes
- **Error Log Spike Alert:** Triggered when error rate > 0.1/sec for 1 minute

### Configure Email Alerts

1. Set environment variables before deployment:
```bash
export GF_SMTP_ENABLED=true
export GF_SMTP_HOST=smtp.gmail.com:587
export GF_SMTP_USER=your-email@gmail.com
export GF_SMTP_PASSWORD="your-app-password"
export GF_ALERT_EMAIL=alerts@example.com
```

2. Or edit `.env` before running `setup.sh`

3. In Grafana:
   - Navigate to Alerting → Notification Policies
   - Configure contact points with your email
   - Set notification policies to route alerts to email

## 🔄 CI/CD with Jenkins

### Deploy Jenkins

```bash
cd docker
docker-compose -f ../jenkins/jenkins-docker-compose.yml up -d
```

### Jenkins Pipeline Stages

1. **Checkout** - Clone repository
2. **Lint** - Validate Dockerfile with Hadolint
3. **Build** - Build Docker image
4. **Test** - Run integration tests
5. **Push** - Push to Docker registry (optional)
6. **Deploy** - SSH and deploy to EC2
7. **Health Check** - Verify deployment
8. **Notify** - Send email notification

### Configure Credentials

Create Jenkins credentials:
- `docker-hub-credentials` - Docker Hub login
- `ec2-ssh-key` - Private SSH key for EC2
- `ec2-host` - EC2 public IP/DNS
- `aws-credentials` - AWS credentials (optional, for ECR)
- `alert-email` - Email for notifications

## 📝 Application Endpoints

### Demo Flask Application

| Endpoint | Method | Description | Logs |
|----------|--------|-------------|------|
| `/` | GET | Status check | ✓ |
| `/health` | GET | Liveness probe | ✓ |
| `/readiness` | GET | Readiness probe | ✓ |
| `/metrics` | GET | Prometheus metrics | ✓ |
| `/data` | GET | Random JSON data | ✓ |
| `/simulate/load` | GET | CPU-intensive work (2s) | ✓ INFO |
| `/simulate/error` | GET | Trigger error (500) | ✓ ERROR |

### Prometheus Metrics Exposed

- `http_requests_total` - Counter with labels: method, endpoint, status
- `http_request_duration_seconds` - Histogram with buckets
- `http_active_requests` - Gauge for concurrent requests
- `app_errors_total` - Counter with labels: endpoint, error_type

## 🔍 Monitoring & Logging

### Log Aggregation Flow

```
Application Logs (.log file)
          ↓
    Promtail (scrapes)
          ↓
    Loki (stores)
          ↓
    Grafana (visualizes)
```

### Log Storage

Logs are stored in `/app/logs/app.log` with format:
```
2024-01-15 10:30:45 [INFO] __main__ - GET /data started
2024-01-15 10:30:45 [INFO] __main__ - GET /data completed with status 200 in 0.025s
```

### System Metrics Collection

- **Host Metrics:** Via Node Exporter
  - CPU, Memory, Disk, Network
  - System load, uptime
  
- **Application Metrics:** Via Prometheus client
  - Request counts and latencies
  - Error rates
  - Resource usage

### Data Retention

| Component | Retention |
|-----------|-----------|
| Prometheus | 7 days (default) |
| Loki | 168 hours (7 days) |
| Grafana | Persistent |

## 🔧 Configuration Files

### Key Configuration Paths

```
monitoring-system/
├── terraform/
│   ├── main.tf              # AWS infrastructure
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   └── user_data.sh         # EC2 bootstrap script
├── app/
│   ├── app.py               # Flask application
│   ├── Dockerfile           # Container image
│   └── requirements.txt      # Python dependencies
├── docker/
│   ├── docker-compose.yml   # All monitoring services
│   ├── prometheus/
│   │   └── prometheus.yml   # Scrape configs
│   ├── loki/
│   │   └── loki-config.yml  # Log storage config
│   ├── promtail/
│   │   └── promtail-config.yml  # Log collection
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/ # Prometheus & Loki
│       │   ├── dashboards/  # Dashboard provisioning
│       │   └── alerting/    # Alert rules
│       └── grafana.ini      # Grafana configuration
└── scripts/
    ├── setup.sh             # Initial setup & deployment
    └── deploy.sh            # Redeployment script
```

### Environment Variables

Create `.env` file in project root:

```bash
# AWS Configuration
AWS_REGION=us-east-1
KEY_NAME=my-key-pair
INSTANCE_TYPE=t3.medium
PROJECT_NAME=monitoring-system

# Grafana Configuration
GF_SECURITY_ADMIN_PASSWORD=admin123
GF_USERS_ALLOW_SIGN_UP=false

# SMTP Configuration (optional)
GF_SMTP_ENABLED=false
GF_SMTP_HOST=smtp.gmail.com:587
GF_SMTP_USER=your-email@gmail.com
GF_SMTP_PASSWORD=your-app-password
GF_ALERT_EMAIL=alerts@example.com
```

## 📈 Scaling & Optimization

### Performance Tuning

**Prometheus:**
```yaml
global:
  scrape_interval: 15s       # Adjust based on needs
  evaluation_interval: 15s
```

**Loki:**
- Increase `ingestion_rate_mb` for high-volume logs
- Use `boltdb-shipper` for better performance
- Configure compactor for old data cleanup

**Grafana:**
- Use caching for dashboard queries
- Set appropriate refresh intervals
- Use recording rules in Prometheus for expensive queries

### Resource Limits

Update `docker-compose.yml` to set limits:

```yaml
services:
  prometheus:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 2G
```

## 🛡️ Security Best Practices

- [ ] Change default Grafana password
- [ ] Enable HTTPS/TLS for all services
- [ ] Restrict security group to your IP
- [ ] Rotate AWS credentials regularly
- [ ] Use AWS ECS for production Prometheus
- [ ] Enable VPC Flow Logs for EC2 monitoring
- [ ] Use Secrets Manager for sensitive data
- [ ] Enable CloudTrail for audit logging

## 🧹 Cleanup

To destroy all AWS resources:

```bash
cd terraform
terraform destroy
```

**Note:** `terraform destroy` will remove the key pair from AWS, but the local `.pem` file (`terraform/monitoring-system-key.pem`) must be deleted manually if desired.

To remove local Docker resources:

```bash
cd docker
docker compose down -v
docker system prune -a
```

## 📊 Troubleshooting

### Services won't start
```bash
# SSH into EC2
ssh -i ~/.ssh/<KEY_NAME>.pem ubuntu@<IP>

# Check Docker daemon
sudo systemctl status docker

# Check logs
cd /opt/monitoring/docker
docker compose logs
```

### Promtail not collecting logs
```bash
# Verify log files exist and are readable
docker exec promtail ls -la /app/logs/

# Check Promtail logs
docker compose logs promtail
```

### Grafana dashboard is empty
1. Verify Prometheus is scraping targets: `http://<IP>:9090/targets`
2. Check dashboard queries in Prometheus UI first
3. Verify data datasource name matches provisioning file

### Out of disk space
```bash
# Clean up old Docker resources
docker system prune -a --volumes

# Check disk usage
df -h
du -sh /var/lib/docker/*
```

## 📚 Documentation

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboard Guide](https://grafana.com/docs/grafana/latest/)
- [Loki Log Aggregation](https://grafana.com/docs/loki/latest/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 💡 Advanced Features

### Custom Alert Rules

Edit `prometheus/prometheus.yml` and add:

```yaml
rule_files:
  - "/etc/prometheus/alert.rules"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

### Custom Dashboards

1. Create a dashboard in Grafana UI
2. Export as JSON
3. Save to `docker/grafana/provisioning/dashboards/`
4. Update `dashboards.yml` to include new file

### Multi-Environment Setup

Create separate directories:
```
monitoring-system-prod/
monitoring-system-staging/
monitoring-system-dev/
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review component logs
3. Check Prometheus `/targets` status page
4. Review Grafana alert history

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Contributing

Contributions welcome! Please submit pull requests with:
- Clear description of changes
- Tests/validation for new features
- Updated documentation

---

**Last Updated:** 2024  
**Version:** 1.0.0
