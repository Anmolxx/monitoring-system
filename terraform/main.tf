terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.6"
}

provider "aws" {
  region = var.aws_region
}

# Data source to get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Create VPC
resource "aws_vpc" "monitoring_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "monitoring_igw" {
  vpc_id = aws_vpc.monitoring_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create public subnet
resource "aws_subnet" "monitoring_subnet" {
  vpc_id                  = aws_vpc.monitoring_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create route table
resource "aws_route_table" "monitoring_rt" {
  vpc_id = aws_vpc.monitoring_vpc.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.monitoring_igw.id
  }

  tags = {
    Name = "${var.project_name}-rt"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "monitoring_rt_assoc" {
  subnet_id      = aws_subnet.monitoring_subnet.id
  route_table_id = aws_route_table.monitoring_rt.id
}

# Create security group
resource "aws_security_group" "monitoring_sg" {
  name_prefix = "${var.project_name}-sg-"
  description = "Security group for monitoring system"
  vpc_id      = aws_vpc.monitoring_vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana web UI"
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus web UI"
  }

  # Loki
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Loki API"
  }

  # Demo App
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Demo application"
  }

  # Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Jenkins web UI"
  }

  # Promtail
  ingress {
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Promtail API"
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node Exporter metrics"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate TLS private key for EC2 SSH access
resource "tls_private_key" "monitoring_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair from the generated public key
resource "aws_key_pair" "monitoring_keypair" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.monitoring_key.public_key_openssh
}

# Save the private key to a local file with restricted permissions
resource "local_file" "private_key_pem" {
  content         = tls_private_key.monitoring_key.private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

# Create EC2 instance
resource "aws_instance" "monitoring_server" {
  ami                       = data.aws_ami.ubuntu.id
  instance_type             = var.instance_type
  key_name                  = aws_key_pair.monitoring_keypair.key_name
  subnet_id                 = aws_subnet.monitoring_subnet.id
  vpc_security_group_ids    = [aws_security_group.monitoring_sg.id]
  associate_public_ip_address = true
  iam_instance_profile      = aws_iam_instance_profile.monitoring_profile.name

  user_data = base64encode(file("${path.module}/user_data.sh"))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  tags = {
    Name = "monitoring-server"
  }

  depends_on = [aws_internet_gateway.monitoring_igw]
}

# Create Elastic IP
resource "aws_eip" "monitoring_eip" {
  domain            = "vpc"
  instance          = aws_instance.monitoring_server.id
  public_ipv4_pool  = "amazon"

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_internet_gateway.monitoring_igw]
}

# Create IAM role for EC2 instance
resource "aws_iam_role" "monitoring_role" {
  name_prefix = "${var.project_name}-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-role"
  }
}

# Create IAM policy for CloudWatch and ECR (optional)
resource "aws_iam_policy" "monitoring_policy" {
  name_prefix = "${var.project_name}-policy-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/monitoring/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-policy"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "monitoring_policy_attach" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

# Create instance profile
resource "aws_iam_instance_profile" "monitoring_profile" {
  name_prefix = "${var.project_name}-profile-"
  role        = aws_iam_role.monitoring_role.name
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Create CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "monitoring_logs" {
  name_prefix      = "/aws/monitoring/${var.project_name}-"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}
