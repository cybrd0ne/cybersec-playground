# Updated Variables for AWS Cybersecurity Lab Infrastructure (with Secrets Manager)

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "cybersec-lab"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "cybersec-team"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (pfSense WAN)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet1_cidr" {
  description = "CIDR block for private subnet 1 (JuiceShop)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet2_cidr" {
  description = "CIDR block for private subnet 2 (Windows AD)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "management_cidr" {
  description = "CIDR block for management access (your IP)"
  type        = string
  default     = "0.0.0.0/0"  # Change this to your specific IP for security
}

# Instance Configuration
variable "pfsense_instance_type" {
  description = "Instance type for pfSense firewall"
  type        = string
  default     = "t3.medium"
}

variable "juiceshop_instance_type" {
  description = "Instance type for JuiceShop server"
  type        = string
  default     = "t3.small"
}

variable "dc_instance_type" {
  description = "Instance type for Domain Controller"
  type        = string
  default     = "t3.medium"
}

variable "client_instance_type" {
  description = "Instance type for Windows client"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of AWS key pair for EC2 instances"
  type        = string
}

# Active Directory Configuration
variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "cybersec.local"
}

# Secrets Manager Configuration
variable "domain_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing domain admin password"
  type        = string
}

# Bootstrap Resources (optional - for reference)
variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state (created by bootstrap)"
  type        = string
  default     = ""
}

variable "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking (created by bootstrap)"
  type        = string
  default     = ""
}