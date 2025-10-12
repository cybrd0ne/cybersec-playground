# JuiceShop Module Variables

variable "private_subnet1_id" {
  description = "ID of private subnet 1"
  type        = string
}

variable "amazon_linux_ami_id" {
  description = "AMI ID for Amazon Linux"
  type        = string
}

variable "instance_type" {
  description = "Instance type for JuiceShop"
  type        = string
}

variable "key_pair_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "juiceshop_sg_id" {
  description = "Security Group ID for JuiceShop"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}