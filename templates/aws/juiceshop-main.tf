# JuiceShop Module - Deploy vulnerable web application

resource "aws_instance" "juiceshop" {
  ami           = var.amazon_linux_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  subnet_id     = var.private_subnet1_id
  
  vpc_security_group_ids = [var.juiceshop_sg_id]
  
  private_ip = "10.0.2.10"
  
  user_data = base64encode(templatefile("${path.module}/scripts/juiceshop-setup.sh", {
    pfsense_ip = "10.0.2.1"
  }))

  tags = {
    Name = "${var.environment}-juiceshop"
    Role = "Vulnerable-Web-App"
  }
}