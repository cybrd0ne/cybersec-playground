# Bootstrap Variables

variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "aws-cybersec-lab"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "cybersec.local"
}

variable "domain_admin_password" {
  description = "Domain administrator password"
  type        = string
  sensitive   = true
}