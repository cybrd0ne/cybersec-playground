# Security Module Variables

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "management_cidr" {
  description = "CIDR block for management access"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}