# JuiceShop Module Outputs

output "juiceshop_instance_id" {
  description = "Instance ID of JuiceShop server"
  value       = aws_instance.juiceshop.id
}

output "juiceshop_private_ip" {
  description = "Private IP of JuiceShop server"
  value       = aws_instance.juiceshop.private_ip
}