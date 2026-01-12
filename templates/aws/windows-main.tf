# Windows Active Directory Module - Deploy AD environment

# Domain Controller Instance
resource "aws_instance" "domain_controller" {
  ami           = var.windows_server_ami_id
  instance_type = var.dc_instance_type
  key_name      = "${var.key_pair_name}-rsa"
  subnet_id     = var.private_subnet2_id
  
  vpc_security_group_ids = [var.windows_sg_id]
  
  private_ip = "10.0.3.30"
  
  user_data = base64encode(templatefile("${path.module}/scripts/dc-setup.ps1", {
    domain_name           = var.domain_name
    domain_admin_password = var.domain_admin_password
    pfsense_ip           = "10.0.3.10"
    username		 = var.vpn_username
    password		 = var.dummy_password
  }))

  tags = {
    Name = "${var.environment}-domain-controller"
    Role = "Domain-Controller"
  }
}

# Windows Client Instance
resource "aws_instance" "windows_client" {
  ami           = var.windows_server_ami_id
  instance_type = var.client_instance_type
  key_name      = "${var.key_pair_name}-rsa"
  subnet_id     = var.private_subnet2_id
  
  vpc_security_group_ids = [var.windows_sg_id]
  
  private_ip = "10.0.3.20"

  user_data = base64encode(templatefile("${path.module}/scripts/client-setup.ps1", {
    domain_name           = var.domain_name
    domain_controller_ip  = "10.0.3.30"
    domain_admin_password = var.domain_admin_password
    pfsense_ip           = "10.0.3.10"
  }))

  tags = {
    Name = "${var.environment}-windows-client"
    Role = "Domain-Member"
  }

  depends_on = [aws_instance.domain_controller]
}
