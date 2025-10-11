# pfSense Module Variables

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet"
  type        = string
}

variable "private_subnet1_id" {
  description = "ID of private subnet 1"
  type        = string
}

variable "private_subnet2_id" {
  description = "ID of private subnet 2"
  type        = string
}

variable "private1_route_table_id" {
  description = "ID of private subnet 1 route table"
  type        = string
}

variable "private2_route_table_id" {
  description = "ID of private subnet 2 route table"
  type        = string
}

variable "pfsense_ami_id" {
  description = "AMI ID for pfSense"
  type        = string
}

variable "instance_type" {
  description = "Instance type for pfSense"
  type        = string
}

variable "key_pair_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "pfsense_sg_id" {
  description = "Security Group ID for pfSense"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}