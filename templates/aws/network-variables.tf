# Network Module Variables

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
}

variable "private_subnet1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
}

variable "private_subnet2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for subnets"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "pfsense_lan1_eni_id" {
  description = "ENI ID of pfSense LAN1 interface for private subnet 1 routing"
  type        = string
}

variable "pfsense_lan2_eni_id" {
  description = "ENI ID of pfSense LAN2 interface for private subnet 2 routing"
  type        = string
}
