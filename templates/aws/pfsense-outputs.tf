# Enhanced pfSense Module Outputs

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

# OpenVPN Related Outputs
output "vpn_server_endpoint" {
  description = "OpenVPN server endpoint for client connections"
  value       = "${aws_eip.pfsense.public_ip}:${var.vpn_port}"
}

output "vpn_protocol" {
  description = "OpenVPN protocol (UDP/TCP)"
  value       = upper(var.vpn_protocol)
}

output "vpn_subnet" {
  description = "OpenVPN client subnet"
  value       = var.vpn_subnet
}

output "vpn_secret_arn" {
  description = "ARN of the VPN credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.vpn_credentials.arn
  sensitive   = true
}

output "vpn_username" {
  description = "OpenVPN username (static)"
  value       = "vpnuser"
}

output "pfsense_iam_role_arn" {
  description = "ARN of the IAM role attached to pfSense instance"
  value       = aws_iam_role.pfsense_secrets_role.arn
}

# Connection Information
output "management_urls" {
  description = "Management access URLs and information"
  value = {
    web_interface = "https://${aws_eip.pfsense.public_ip}"
    ssh_access    = "ssh admin@${aws_eip.pfsense.public_ip}"
    vpn_endpoint  = "${aws_eip.pfsense.public_ip}:${var.vpn_port}"
  }
}

output "openvpn_client_config_path" {
  description = "Path to OpenVPN client configuration file on pfSense instance"
  value       = "/var/etc/openvpn/client-configs/vpnuser.ovpn"
}

output "setup_status_report_path" {
  description = "Path to setup status report on pfSense instance"
  value       = "/var/log/pfsense-config-report.txt"
}

# Security Information
output "security_info" {
  description = "Security configuration information"
  value = {
    certificate_authority = "/var/etc/openvpn/keys/ca.crt"
    server_certificate    = "/var/etc/openvpn/keys/server.crt"
    encryption_cipher     = "AES-256-GCM"
    authentication_hash   = "SHA-256"
    tls_version_minimum   = "1.2"
    key_size             = "2048-bit RSA"
  }
}

# Troubleshooting Information
output "log_files" {
  description = "Important log files for troubleshooting"
  value = {
    setup_log           = "/var/log/pfsense-setup.log"
    openvpn_log        = "/var/log/openvpn.log"
    openvpn_status     = "/var/log/openvpn-status.log"
    configuration_report = "/var/log/pfsense-config-report.txt"
  }
}