# pfSense Module - Deploy and configure pfSense firewall

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

# pfSense EC2 Instance
resource "aws_instance" "pfsense" {
  ami           = var.pfsense_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  
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
    wan_ip    = "10.0.1.10"
    lan1_ip   = "10.0.2.10" 
    lan2_ip   = "10.0.3.10"
    wan_gw    = "10.0.1.1"
  }))

  tags = {
    Name = "${var.environment}-pfsense"
    Role = "Firewall"
  }

  depends_on = [
    aws_network_interface.pfsense_wan,
    aws_network_interface.pfsense_lan1,
    aws_network_interface.pfsense_lan2
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
