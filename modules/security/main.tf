# Security Groups Module - Define firewall rules for each component

# Security Group for pfSense Firewall
resource "aws_security_group" "pfsense" {
  name        = "${var.environment}-pfsense-sg"
  description = "Security group for pfSense firewall"
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
    cidr_blocks = [var.vpc_cidr]
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