# Enhanced pfSense Module with OpenVPN and Secrets Manager Integration

# Create VPN credentials secret in Secrets Manager
resource "aws_secretsmanager_secret" "vpn_credentials" {
  name                    = "${var.environment}-vpn-credentials"
  description             = "OpenVPN credentials for pfSense"
  recovery_window_in_days = 0  # For lab environment, allow immediate deletion

  tags = {
    Name        = "${var.environment}-vpn-credentials"
    Description = "OpenVPN user credentials"
    Component   = "pfSense"
  }
}

# Generate random VPN password
resource "random_password" "vpn_password" {
  length  = 16
  lower   = true
  upper   = true
  numeric = true
  special = true
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
  min_special = 1
}

resource "aws_secretsmanager_secret_version" "vpn_credentials" {
  secret_id = aws_secretsmanager_secret.vpn_credentials.id
  secret_string = jsonencode({
    username = "merk.vand"
    password = random_password.vpn_password.result
    server   = "openvpn-server"
    port     = 1194
    protocol = "udp"
  })
}

# IAM role for pfSense to access Secrets Manager
resource "aws_iam_role" "pfsense_secrets_role" {
  name = "${var.environment}-pfsense-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-pfsense-secrets-role"
    Description = "IAM role for pfSense to access VPN credentials"
  }
}

# IAM policy for accessing VPN credentials
resource "aws_iam_role_policy" "pfsense_secrets_policy" {
  name = "${var.environment}-pfsense-secrets-policy"
  role = aws_iam_role.pfsense_secrets_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.vpn_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.vpn_credentials.arn
      }
    ]
  })
}

# Instance profile for pfSense
resource "aws_iam_instance_profile" "pfsense_profile" {
  name = "${var.environment}-pfsense-profile"
  role = aws_iam_role.pfsense_secrets_role.name

  tags = {
    Name        = "${var.environment}-pfsense-profile"
    Description = "Instance profile for pfSense EC2 instance"
  }
}

# Create network interfaces for pfSense
resource "aws_network_interface" "pfsense_wan" {
  subnet_id       = var.public_subnet_id
  private_ips     = ["10.0.1.10"]
  security_groups = [var.pfsense_sg_id]
  source_dest_check = false

  tags = {
    Name = "${var.environment}-pfsense-wan-eni"
  }
}

resource "aws_network_interface" "pfsense_lan1" {
  subnet_id       = var.private_subnet1_id
  private_ips     = ["10.0.2.10"]
  security_groups = [var.pfsense_sg_id]
  source_dest_check = false

  tags = {
    Name = "${var.environment}-pfsense-lan1-eni"
  }
}

resource "aws_network_interface" "pfsense_lan2" {
  subnet_id       = var.private_subnet2_id
  private_ips     = ["10.0.3.10"]
  security_groups = [var.pfsense_sg_id]
  source_dest_check = false

  tags = {
    Name = "${var.environment}-pfsense-lan2-eni"
  }
}

# Elastic IP for pfSense WAN
resource "aws_eip" "pfsense" {
  domain = "vpc"
  
  tags = {
    Name = "${var.environment}-pfsense-eip"
  }
}

resource "aws_eip_association" "pfsense" {
  network_interface_id = aws_network_interface.pfsense_wan.id
  allocation_id        = aws_eip.pfsense.id
}

# pfSense EC2 Instance with enhanced configuration
resource "aws_instance" "pfsense" {
  ami           = var.pfsense_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  
  # Attach IAM instance profile for Secrets Manager access
  iam_instance_profile = aws_iam_instance_profile.pfsense_profile.name
  
  # Attach network interfaces
  network_interface {
    network_interface_id = aws_network_interface.pfsense_wan.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.pfsense_lan1.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.pfsense_lan2.id
    device_index         = 2
  }

  user_data = base64encode(templatefile("${path.module}/scripts/pfsense-config.sh", {
    wan_ip         = "10.0.1.10"
    lan1_ip        = "10.0.2.10" 
    lan2_ip        = "10.0.3.10"
    wan_gw         = "10.0.1.1"
    vpn_secret_arn = aws_secretsmanager_secret.vpn_credentials.arn
    aws_region     = var.aws_region
  }))

  # Additional storage for certificates and logs
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
    
    tags = {
      Name = "${var.environment}-pfsense-root-volume"
    }
  }

  tags = {
    Name = "${var.environment}-pfsense"
    Role = "Firewall-VPN"
  }

  depends_on = [
    aws_network_interface.pfsense_wan,
    aws_network_interface.pfsense_lan1,
    aws_network_interface.pfsense_lan2,
    aws_secretsmanager_secret_version.vpn_credentials
  ]
}

# Update route tables to route through pfSense
resource "aws_route" "private1_default" {
  route_table_id         = var.private1_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.pfsense_lan1.id
}

resource "aws_route" "private2_default" {
  route_table_id         = var.private2_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.pfsense_lan2.id
}
