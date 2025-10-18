# Enhanced Security Module Outputs

output "pfsense_sg_id" {
  description = "Security Group ID for pfSense with OpenVPN support"
  value       = aws_security_group.pfsense.id
}

output "juiceshop_sg_id" {
  description = "Security Group ID for JuiceShop"
  value       = aws_security_group.juiceshop.id
}

output "windows_sg_id" {
  description = "Security Group ID for Windows AD environment"
  value       = aws_security_group.windows.id
}

output "vpn_clients_sg_id" {
  description = "Security Group ID for OpenVPN clients"
  value       = aws_security_group.vpn_clients.id
}

# Additional security information
output "security_group_info" {
  description = "Security groups configuration summary"
  value = {
    pfsense = {
      id          = aws_security_group.pfsense.id
      name        = aws_security_group.pfsense.name
      description = aws_security_group.pfsense.description
      vpn_ports   = ["1194/udp", "1194/tcp"]
      mgmt_ports  = ["80/tcp", "443/tcp", "22/tcp", "7505/tcp"]
    }
    juiceshop = {
      id          = aws_security_group.juiceshop.id
      name        = aws_security_group.juiceshop.name
      description = aws_security_group.juiceshop.description
      app_ports   = ["3000/tcp"]
    }
    windows_ad = {
      id          = aws_security_group.windows.id
      name        = aws_security_group.windows.name
      description = aws_security_group.windows.description
      ad_ports    = ["389/tcp", "636/tcp", "3268-3269/tcp", "88/tcp", "88/udp", "53/tcp", "53/udp"]
      mgmt_ports  = ["3389/tcp", "5985/tcp", "5986/tcp"]
    }
    vpn_clients = {
      id          = aws_security_group.vpn_clients.id
      name        = aws_security_group.vpn_clients.name
      description = aws_security_group.vpn_clients.description
      client_subnet = "10.8.0.0/24"
    }
  }
}

output "firewall_rules_summary" {
  description = "Summary of firewall rules configured"
  value = {
    external_access = [
      "OpenVPN: 0.0.0.0/0 → pfSense:1194 (UDP/TCP)",
      "Management: ${var.management_cidr} → pfSense:80,443,22,7505 (TCP)",
      "RDP: ${var.management_cidr} → Windows:3389 (TCP)"
    ]
    internal_access = [
      "VPC: ${var.vpc_cidr} → JuiceShop:3000 (TCP)",
      "VPC: ${var.vpc_cidr} → Windows AD:389,636,3268-3269,88,53,445,137-139,5985-5986",
      "VPN Clients: 10.8.0.0/24 → All Internal Resources"
    ]
    security_notes = [
      "Source/destination checks disabled on pfSense ENIs",
      "All traffic between subnets routed through pfSense",
      "OpenVPN uses AES-256-GCM encryption with SHA-256 authentication",
      "VPN credentials stored securely in AWS Secrets Manager"
    ]
  }
}