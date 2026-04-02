output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.monitoring_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.monitoring_server.public_dns
}

output "elastic_ip" {
  description = "Elastic IP address associated with the instance"
  value       = aws_eip.monitoring_eip.public_ip
}

output "security_group_id" {
  description = "Security group ID for the monitoring server"
  value       = aws_security_group.monitoring_sg.id
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_eip.monitoring_eip.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_eip.monitoring_eip.public_ip}:9090"
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_eip.monitoring_eip.public_ip}:8080"
}

output "app_url" {
  description = "URL to access the demo application"
  value       = "http://${aws_eip.monitoring_eip.public_ip}:5000"
}

output "private_key_path" {
  value       = local_file.private_key_pem.filename
  description = "Local path to the generated PEM file"
}

output "ssh_command" {
  value       = "ssh -i ${local_file.private_key_pem.filename} ubuntu@${aws_eip.monitoring_eip.public_ip}"
  description = "Ready-to-use SSH command to connect to the instance"
}
