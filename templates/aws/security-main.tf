# Enhanced Security Groups Module - Include OpenVPN support

# Security Group for pfSense Firewall with OpenVPN support
resource "aws_security_group" "pfsense" {
  name        = "${var.environment}-pfsense-sg"
  description = "Security group for pfSense firewall with OpenVPN"
  vpc_id      = var.vpc_id

  # SSH access from management network
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.management_cidr]
  }

  # HTTPS for web management interface
  ingress {
    description = "HTTPS Management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.management_cidr]
  }

  # HTTP for web management interface
  ingress {
    description = "HTTP Management"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.management_cidr]
  }

  # OpenVPN UDP port
  ingress {
    description = "OpenVPN UDP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # OpenVPN TCP port (alternative)
  ingress {
    description = "OpenVPN TCP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Additional OpenVPN management port
  ingress {
    description = "OpenVPN Management"
    from_port   = 7505
    to_port     = 7505
    protocol    = "tcp"
    cidr_blocks = [var.management_cidr]
  }

  # ICMP for ping
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All traffic from VPC (pfSense will handle filtering)
  ingress {
    description = "All VPC Traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "All VPC UDP Traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound rules
  egress {
    description = "All Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-pfsense-sg"
  }
}

# Security Group for JuiceShop
resource "aws_security_group" "juiceshop" {
  name        = "${var.environment}-juiceshop-sg"
  description = "Security group for JuiceShop vulnerable application"
  vpc_id      = var.vpc_id

  # HTTP access for JuiceShop application
  ingress {
    description = "HTTP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr, "10.8.0.0/24"]
  }

  # SSH access from management network
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ICMP for ping
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound rules
  egress {
    description = "All Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-juiceshop-sg"
  }
}

# Security Group for Windows AD Environment
resource "aws_security_group" "windows" {
  name        = "${var.environment}-windows-sg"
  description = "Security group for Windows AD environment"
  vpc_id      = var.vpc_id

  # RDP access
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.management_cidr]
  }

  # Active Directory ports
  ingress {
    description = "AD LDAP"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "AD LDAP SSL"
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "AD Global Catalog"
    from_port   = 3268
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kerberos
  ingress {
    description = "Kerberos"
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Kerberos UDP"
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # DNS
  ingress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SMB/CIFS
  ingress {
    description = "SMB"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # NetBIOS
  ingress {
    description = "NetBIOS Name Service"
    from_port   = 137
    to_port     = 137
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "NetBIOS Datagram"
    from_port   = 138
    to_port     = 138
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "NetBIOS Session"
    from_port   = 139
    to_port     = 139
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # WinRM for PowerShell remoting
  ingress {
    description = "WinRM HTTP"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "WinRM HTTPS"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ICMP for ping
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Dynamic RPC ports for AD replication
  ingress {
    description = "Dynamic RPC"
    from_port   = 1024
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound rules
  egress {
    description = "All Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-windows-sg"
  }
}

# Additional Security Group for VPN Clients
resource "aws_security_group" "vpn_clients" {
  name        = "${var.environment}-vpn-clients-sg"
  description = "Security group for OpenVPN clients accessing internal resources"
  vpc_id      = var.vpc_id

  # Allow VPN clients to access internal resources
  ingress {
    description = "VPN Client Access"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.8.0.0/24"]  # OpenVPN client subnet
  }

  ingress {
    description = "VPN Client UDP Access"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["10.8.0.0/24"]  # OpenVPN client subnet
  }

  # ICMP for VPN clients
  ingress {
    description = "VPN Client ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.8.0.0/24"]  # OpenVPN client subnet
  }

  # Outbound rules
  egress {
    description = "All Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-vpn-clients-sg"
  }
}
