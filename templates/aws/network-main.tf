# Network Module - VPC, Subnets, Route Tables, Internet Gateway

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.environment}-igw"
  }
}

# Public Subnet for pfSense WAN interface
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.environment}-public-subnet"
    Type = "Public"
  }
}

# Private Subnet 1 for JuiceShop
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet1_cidr
  availability_zone = var.availability_zone
  
  tags = {
    Name = "${var.environment}-private-subnet-1"
    Type = "Private"
    Purpose = "JuiceShop"
  }
}

# Private Subnet 2 for Windows AD
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet2_cidr
  availability_zone = var.availability_zone
  
  tags = {
    Name = "${var.environment}-private-subnet-2" 
    Type = "Private"
    Purpose = "Windows-AD"
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.environment}-public-rt"
  }
}

# Route table for private subnet 1
resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-private1-rt"
  }
}

# Route table for private subnet 2
resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.environment}-private2-rt"
  }
}

# Default route for private subnet 1 through pfSense LAN1 interface
resource "aws_route" "private1_default_via_pfsense" {
  route_table_id         = aws_route_table.private1.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.pfsense_lan1_eni_id
  depends_on             = [aws_route_table.private1]
  lifecycle {
    create_before_destroy = true
  }
}

# Default route for private subnet 2 through pfSense LAN2 interface
resource "aws_route" "private2_default_via_pfsense" {
  route_table_id         = aws_route_table.private2.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.pfsense_lan2_eni_id
  depends_on             = [aws_route_table.private2]
  lifecycle {
    create_before_destroy = true
  }
}

# Route table associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
  depends_on = [aws_route.private1_default_via_pfsense]
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
  depends_on = [aws_route.private2_default_via_pfsense]
}

# DHCP Options Set for AD integration
resource "aws_vpc_dhcp_options" "main" {
  domain_name_servers = ["10.0.3.30","10.0.2.10"]
  domain_name         = "cybersec.local"
  
  tags = {
    Name = "${var.environment}-dhcp-options"
  }
}

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}
