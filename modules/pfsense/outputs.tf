# pfSense Module Outputs

output "pfsense_instance_id" {
  description = "Instance ID of pfSense firewall"
  value       = aws_instance.pfsense.id
}

output "pfsense_public_ip" {
  description = "Public IP of pfSense firewall"
  value       = aws_eip.pfsense.public_ip
}

output "pfsense_wan_private_ip" {
  description = "WAN private IP of pfSense"
  value       = aws_network_interface.pfsense_wan.private_ip
}

output "pfsense_lan1_ip" {
  description = "LAN1 IP of pfSense"
  value       = aws_network_interface.pfsense_lan1.private_ip
}

output "pfsense_lan2_ip" {
  description = "LAN2 IP of pfSense"
  value       = aws_network_interface.pfsense_lan2.private_ip
}