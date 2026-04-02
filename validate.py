#!/usr/bin/env python3
"""
Project Structure Validator
Verifies all required files exist and have content
"""

import os
import sys
from pathlib import Path

# Define expected files
REQUIRED_FILES = {
    # Terraform
    "terraform/main.tf": "AWS infrastructure",
    "terraform/variables.tf": "Terraform variables",
    "terraform/outputs.tf": "Terraform outputs",
    "terraform/user_data.sh": "EC2 bootstrap script",
    
    # Application
    "app/app.py": "Flask application",
    "app/Dockerfile": "Container image",
    "app/requirements.txt": "Python dependencies",
    
    # Docker Compose
    "docker/docker-compose.yml": "Service orchestration",
    
    # Prometheus
    "docker/prometheus/prometheus.yml": "Prometheus config",
    
    # Loki
    "docker/loki/loki-config.yml": "Loki config",
    
    # Promtail
    "docker/promtail/promtail-config.yml": "Promtail config",
    
    # Grafana
    "docker/grafana/grafana.ini": "Grafana server config",
    "docker/grafana/provisioning/datasources/datasources.yml": "Grafana datasources",
    "docker/grafana/provisioning/dashboards/dashboards.yml": "Grafana dashboard provider",
    "docker/grafana/provisioning/dashboards/monitoring.json": "Main dashboard",
    "docker/grafana/provisioning/alerting/contact-points.yml": "Alert contact points",
    "docker/grafana/provisioning/alerting/notification-policies.yml": "Alert policies",
    
    # Jenkins
    "jenkins/jenkins-docker-compose.yml": "Jenkins container",
    "jenkins/Jenkinsfile": "CI/CD pipeline",
    
    # Scripts
    "scripts/setup.sh": "Setup automation",
    "scripts/deploy.sh": "Deployment automation",
    
    # Documentation
    "README.md": "Main documentation",
    "QUICK-START.md": "Quick start guide",
    "IMPLEMENTATION.md": "Implementation details",
    ".gitignore": "Git ignore rules",
}

def validate_files():
    """Check if all required files exist and have content"""
    print("=" * 70)
    print("  📋 MONITORING SYSTEM - PROJECT STRUCTURE VALIDATION")
    print("=" * 70)
    print()
    
    root = Path(".")
    missing = []
    empty = []
    valid = []
    
    for filepath, description in REQUIRED_FILES.items():
        full_path = root / filepath
        
        if not full_path.exists():
            missing.append((filepath, description))
            print(f"❌ MISSING: {filepath}")
        elif full_path.stat().st_size == 0:
            empty.append((filepath, description))
            print(f"⚠️  EMPTY:   {filepath}")
        else:
            valid.append((filepath, description))
            size_kb = full_path.stat().st_size / 1024
            print(f"✅ OK:      {filepath:60} ({size_kb:.1f} KB)")
    
    print()
    print("=" * 70)
    print(f"  SUMMARY: {len(valid)} valid, {len(missing)} missing, {len(empty)} empty (Total: {len(REQUIRED_FILES)})")
    print("=" * 70)
    
    if missing:
        print("\n❌ MISSING FILES:")
        for filepath, desc in missing:
            print(f"   • {filepath}: {desc}")
        return False
    
    if empty:
        print("\n⚠️  EMPTY FILES:")
        for filepath, desc in empty:
            print(f"   • {filepath}: {desc}")
        return False
    
    print("\n✅ ALL FILES PRESENT AND VALID!")
    return True

def count_lines():
    """Count lines of code/config"""
    print("\n" + "=" * 70)
    print("  📊 PROJECT STATISTICS")
    print("=" * 70)
    print()
    
    root = Path(".")
    total_lines = 0
    file_count = 0
    
    categories = {
        "Terraform": [],
        "Python": [],
        "Docker/YAML": [],
        "Configuration": [],
        "Scripts": [],
        "Documentation": [],
    }
    
    for filepath in REQUIRED_FILES.keys():
        full_path = root / filepath
        
        if full_path.exists() and full_path.stat().st_size > 0:
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = len(f.readlines())
                total_lines += lines
                file_count += 1
                
                # Categorize
                if "terraform" in filepath:
                    categories["Terraform"].append((filepath, lines))
                elif filepath.endswith(".py"):
                    categories["Python"].append((filepath, lines))
                elif filepath.endswith((".yml", ".yaml", "docker-compose")):
                    categories["Docker/YAML"].append((filepath, lines))
                elif filepath.endswith((".ini", ".json")):
                    categories["Configuration"].append((filepath, lines))
                elif filepath.endswith(".sh"):
                    categories["Scripts"].append((filepath, lines))
                elif filepath.endswith(".md"):
                    categories["Documentation"].append((filepath, lines))
    
    for category, files in categories.items():
        if files:
            cat_lines = sum(lines for _, lines in files)
            print(f"{category}:")
            for filepath, lines in files:
                print(f"  • {filepath:60} {lines:5} lines")
            print(f"  → Subtotal: {cat_lines} lines\n")
    
    print("=" * 70)
    print(f"Total Files Generated: {file_count}")
    print(f"Total Lines of Code:   {total_lines:,}")
    print("=" * 70)

if __name__ == "__main__":
    if validate_files():
        count_lines()
        print("\n🎉 PROJECT STRUCTURE IS COMPLETE AND READY FOR DEPLOYMENT! 🎉\n")
        sys.exit(0)
    else:
        print("\n❌ VALIDATION FAILED - Some files are missing or empty\n")
        sys.exit(1)
