# Main Infrastructure Outputs
output "aws_region" {
  description = "AWS Configured Region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "pfsense_public_ip" {
  description = "Public IP of pfSense firewall for management access"
  value       = module.pfsense.pfsense_public_ip
}

output "pfsense_management_url" {
  description = "URL for pfSense web management"
  value       = "https://${module.pfsense.pfsense_public_ip}"
}

output "juiceshop_private_ip" {
  description = "Private IP of JuiceShop application"
  value       = module.juiceshop.juiceshop_private_ip
}

output "juiceshop_url" {
  description = "Internal URL for JuiceShop (accessible through pfSense)"
  value       = "http://${module.juiceshop.juiceshop_private_ip}:3000"
}

output "domain_controller_ip" {
  description = "Private IP of Active Directory Domain Controller"
  value       = module.windows_ad.domain_controller_private_ip
}

output "windows_client_ip" {
  description = "Private IP of Windows client machine"
  value       = module.windows_ad.windows_client_private_ip
}

output "domain_name" {
  description = "Active Directory domain name"
  value       = var.domain_name
}

# Connection information
output "connection_info" {
  description = "Connection information for lab access"
  value = {
    pfsense_management = "https://${module.pfsense.pfsense_public_ip} (admin/pfsense - change after first login)"
    juiceshop_app     = "Configure port forwarding in pfSense to access ${module.juiceshop.juiceshop_private_ip}:3000"
    rdp_access        = "Configure port forwarding in pfSense for RDP to Windows machines"
    ssh_access        = "SSH through pfSense for Linux machines"
    domain_info       = "Domain: ${var.domain_name}, DC: ${module.windows_ad.domain_controller_private_ip}"
    vpn_creds         = "ssh ${module.pfsense.pfsense_public_ip} -o RemoteCommand='cat /usr/local/etc/openvpn/client-configs/${var.vpn_username}-credentials.txt'"
    vpn_config        = "Ready to be imported from your local folder in /tmp/${var.vpn_username}.ovpn"
  }
}
