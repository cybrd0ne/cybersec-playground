# Security Module Outputs

output "pfsense_sg_id" {
  description = "Security Group ID for pfSense"
  value       = aws_security_group.pfsense.id
}

output "juiceshop_sg_id" {
  description = "Security Group ID for JuiceShop"
  value       = aws_security_group.juiceshop.id
}

output "windows_sg_id" {
  description = "Security Group ID for Windows"
  value       = aws_security_group.windows.id
}