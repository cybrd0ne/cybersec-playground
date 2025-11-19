# Updated Main Configuration with Secrets Manager Integration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "CybersecurityLab"
      Owner       = var.owner
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Retrieve domain admin password from Secrets Manager
data "aws_secretsmanager_secret_version" "domain_admin_password" {
  secret_id = var.domain_password_secret_arn
}

locals {
  # Parse the secret JSON
  domain_credentials = jsondecode(data.aws_secretsmanager_secret_version.domain_admin_password.secret_string)
}

# Get the latest pfSense Plus AMI
data "aws_ami" "pfsense" {
  most_recent = true
  owners      = ["679593333241"]
  
  filter {
    name   = "name"
    values = ["pfSense-plus-ec2*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get the latest Amazon Linux 2023 AMI for JuiceShop
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get the latest Windows Server 2022 AMI
data "aws_ami" "windows_server" {
  most_recent = true
  owners      = ["801119661308"]
  
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Call modules
module "network" {
  source = "./modules/network"
  
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet1_cidr = var.private_subnet1_cidr
  private_subnet2_cidr = var.private_subnet2_cidr
  availability_zone    = data.aws_availability_zones.available.names[0]
  environment         = var.environment
  pfsense_lan1_eni_id  = module.pfsense.lan1_eni_id
  pfsense_lan2_eni_id  = module.pfsense.lan2_eni_id
}

module "security_groups" {
  source = "./modules/security"
  
  vpc_id              = module.network.vpc_id
  vpc_cidr           = var.vpc_cidr
  management_cidr    = var.management_cidr
  environment        = var.environment
}

module "pfsense" {
  source = "./modules/pfsense"
  
  aws_region		   = var.aws_region
  vpc_id                   = module.network.vpc_id
  public_subnet_id         = module.network.public_subnet_id
  private_subnet1_id       = module.network.private_subnet1_id
  private_subnet2_id       = module.network.private_subnet2_id
  private1_route_table_id  = module.network.private1_route_table_id
  private2_route_table_id  = module.network.private2_route_table_id
  pfsense_ami_id          = data.aws_ami.pfsense.id
  instance_type           = var.pfsense_instance_type
  key_pair_name           = var.key_pair_name
  pfsense_sg_id           = module.security_groups.pfsense_sg_id
  environment             = var.environment
  vpn_username		  = var.vpn_username
  fqdn			  = var.fqdn
}

module "juiceshop" {
  source = "./modules/juiceshop"
  
  private_subnet1_id    = module.network.private_subnet1_id
  amazon_linux_ami_id   = data.aws_ami.amazon_linux.id
  instance_type         = var.juiceshop_instance_type
  key_pair_name         = var.key_pair_name
  juiceshop_sg_id       = module.security_groups.juiceshop_sg_id
  environment           = var.environment
}

module "windows_ad" {
  source = "./modules/windows"
  
  private_subnet2_id      = module.network.private_subnet2_id
  windows_server_ami_id   = data.aws_ami.windows_server.id
  dc_instance_type        = var.dc_instance_type
  client_instance_type    = var.client_instance_type
  key_pair_name           = var.key_pair_name
  windows_sg_id           = module.security_groups.windows_sg_id
  domain_name             = local.domain_credentials.domain  # Use domain from secret
  domain_admin_password   = local.domain_credentials.password  # Use password from secret
  environment             = var.environment
}
