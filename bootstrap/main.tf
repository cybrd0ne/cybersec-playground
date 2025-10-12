# Bootstrap Terraform Configuration
# This creates the prerequisite resources for the main infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "bootstrap"
      ManagedBy   = "Terraform"
      Purpose     = "CybersecurityLab"
    }
  }
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# Current AWS caller identity
data "aws_caller_identity" "current" {}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Description = "Terraform state storage for cybersecurity lab"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "${var.project_name}-terraform-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-lock"
    Description = "Terraform state locking for cybersecurity lab"
  }
}

# AWS Secrets Manager Secret for Domain Administrator Password
resource "aws_secretsmanager_secret" "domain_admin_password" {
  name                    = "${var.project_name}/domain-admin-password"
  description             = "Domain Administrator password for Active Directory"
  recovery_window_in_days = 0  # For lab environment, allow immediate deletion

  tags = {
    Name        = "${var.project_name}-domain-password"
    Description = "Active Directory domain administrator password"
    Component   = "WindowsAD"
  }
}

resource "aws_secretsmanager_secret_version" "domain_admin_password" {
  secret_id     = aws_secretsmanager_secret.domain_admin_password.id
  secret_string = jsonencode({
    username = "Administrator"
    password = var.domain_admin_password
    domain   = var.domain_name
  })
}

# IAM Role for Terraform Execution
resource "aws_iam_role" "terraform_execution" {
  name = "${var.project_name}-terraform-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-terraform-execution-role"
    Description = "IAM role for Terraform execution with required permissions"
  }
}

# IAM Policy for Terraform Execution
resource "aws_iam_role_policy" "terraform_execution" {
  name = "${var.project_name}-terraform-execution-policy"
  role = aws_iam_role.terraform_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 Permissions
      {
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      # VPC Permissions
      {
        Effect = "Allow"
        Action = [
          "vpc:*"
        ]
        Resource = "*"
      },
      # IAM Permissions (limited)
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:AWSServiceName": [
              "ec2.amazonaws.com"
            ]
          }
        }
      },
      # Secrets Manager Permissions
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.domain_admin_password.arn
      },
      # S3 State Backend Permissions
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      # DynamoDB State Lock Permissions
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
      },
      # CloudFormation Permissions (for some Terraform operations)
      {
        Effect = "Allow"
        Action = [
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# SSM Parameter for Terraform Role ARN (for easy reference)
resource "aws_ssm_parameter" "terraform_role_arn" {
  name  = "/${var.project_name}/terraform-role-arn"
  type  = "String"
  value = aws_iam_role.terraform_execution.arn

  tags = {
    Name        = "${var.project_name}-terraform-role-arn"
    Description = "ARN of Terraform execution role"
  }
}

# SSM Parameter for S3 State Bucket (for easy reference)
resource "aws_ssm_parameter" "state_bucket" {
  name  = "/${var.project_name}/terraform-state-bucket"
  type  = "String"
  value = aws_s3_bucket.terraform_state.bucket

  tags = {
    Name        = "${var.project_name}-state-bucket"
    Description = "S3 bucket for Terraform state"
  }
}

# SSM Parameter for DynamoDB Lock Table (for easy reference)
resource "aws_ssm_parameter" "lock_table" {
  name  = "/${var.project_name}/terraform-lock-table"
  type  = "String"
  value = aws_dynamodb_table.terraform_lock.name

  tags = {
    Name        = "${var.project_name}-lock-table"
    Description = "DynamoDB table for Terraform state locking"
  }
}
