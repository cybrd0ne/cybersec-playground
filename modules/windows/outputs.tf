# Windows Module Outputs

output "domain_controller_instance_id" {
  description = "Instance ID of Domain Controller"
  value       = aws_instance.domain_controller.id
}

output "domain_controller_private_ip" {
  description = "Private IP of Domain Controller"
  value       = aws_instance.domain_controller.private_ip
}

output "windows_client_instance_id" {
  description = "Instance ID of Windows client"
  value       = aws_instance.windows_client.id
}

output "windows_client_private_ip" {
  description = "Private IP of Windows client"
  value       = aws_instance.windows_client.private_ip
}