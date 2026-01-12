# Windows Module Variables

variable "private_subnet2_id" {
  description = "ID of private subnet 2"
  type        = string
}

variable "windows_server_ami_id" {
  description = "AMI ID for Windows Server"
  type        = string
}

variable "dc_instance_type" {
  description = "Instance type for Domain Controller"
  type        = string
}

variable "client_instance_type" {
  description = "Instance type for Windows client"
  type        = string
}

variable "key_pair_name" {
  description = "Key pair name for access"
  type        = string
}

variable "windows_sg_id" {
  description = "Security Group ID for Windows"
  type        = string
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
}

variable "domain_admin_password" {
  description = "Password for domain administrator"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpn_username" {
  description = "same windows user as OpenVPN username"
  type        = string
}

variable "dummy_password" {
  description = "weak password to introduce weak account into domain"
  type        = string
  default     = "ChangeMe"
}
