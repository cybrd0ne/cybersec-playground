# Bootstrap Variables

variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cybersec-playground"
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

# OpenVPN Configuration Variables
variable "vpn_username" {
  description = "OpenVPN username for remote access"
  type        = string
  default     = "merk.vand"
}

variable "vpn_port" {
  description = "OpenVPN server port"
  type        = number
  default     = 1194

   validation {
    condition     = var.vpn_port > 0 && var.vpn_port <= 65535
    error_message = "VPN port must be between 1 and 65535."
  }
}

variable "vpn_protocol" {
  description = "OpenVPN protocol (udp or tcp)"
  type        = string
  default     = "udp"

  validation {
    condition     = contains(["udp", "tcp"], var.vpn_protocol)
    error_message = "VPN protocol must be either 'udp' or 'tcp'."
  }
}

# Additional Security Settings
variable "enable_backup_retention" {
  description = "Enable backup retention for bootstrap resources"
  type        = bool
  default     = false
}

variable "resource_encryption" {
  description = "Enable encryption for all bootstrap resources"
  type        = bool
  default     = true
}
