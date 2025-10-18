# Enhanced Bootstrap Outputs with VPN Configuration

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "domain_password_secret_arn" {
  description = "ARN of the domain administrator password secret"
  value       = aws_secretsmanager_secret.domain_admin_password.arn
}

output "vpn_credentials_secret_arn" {
  description = "ARN of the VPN credentials secret"
  value       = aws_secretsmanager_secret.vpn_credentials.arn
}

output "terraform_execution_role_arn" {
  description = "ARN of the Terraform execution role"
  value       = aws_iam_role.terraform_execution.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Enhanced setup summary
output "setup_summary" {
  description = "Comprehensive summary of bootstrap setup"
  value = {
    # Core Infrastructure
    state_bucket      = aws_s3_bucket.terraform_state.bucket
    lock_table        = aws_dynamodb_table.terraform_lock.name
    terraform_role    = aws_iam_role.terraform_execution.name
    
    # Secrets Management
    domain_secret_name = aws_secretsmanager_secret.domain_admin_password.name
    vpn_secret_name   = aws_secretsmanager_secret.vpn_credentials.name
    
    # Configuration
    region           = var.aws_region
    project_name     = var.project_name
    domain_name      = var.domain_name
    
    # VPN Configuration
    vpn_username     = var.vpn_username
    vpn_port        = var.vpn_port
    vpn_protocol    = var.vpn_protocol
  }
}

# VPN Configuration Details
output "vpn_configuration" {
  description = "OpenVPN configuration details"
  value = {
    username        = var.vpn_username
    port           = var.vpn_port
    protocol       = var.vpn_protocol
    client_subnet  = "10.8.0.0/24"
    encryption     = "AES-256-GCM"
    authentication = "SHA-256"
    secret_arn     = aws_secretsmanager_secret.vpn_credentials.arn
  }
}

# Security Information
output "security_summary" {
  description = "Security configuration summary"
  value = {
    encryption_enabled = var.resource_encryption
    secrets_manager = {
      domain_secret = {
        name = aws_secretsmanager_secret.domain_admin_password.name
        arn  = aws_secretsmanager_secret.domain_admin_password.arn
      }
      vpn_secret = {
        name = aws_secretsmanager_secret.vpn_credentials.name
        arn  = aws_secretsmanager_secret.vpn_credentials.arn
      }
    }
    s3_encryption     = "AES256"
    dynamodb_encryption = true
    backup_retention  = var.enable_backup_retention
  }
}

# Connection Commands
output "connection_commands" {
  description = "Useful commands for accessing secrets and configuration"
  value = {
    get_domain_password = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.domain_admin_password.arn} --query SecretString --output text | jq -r '.password'"
    get_vpn_credentials = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.vpn_credentials.arn} --query SecretString --output text | jq -r '.username, .password'"
    list_terraform_state = "aws s3 ls s3://${aws_s3_bucket.terraform_state.bucket}/"
    check_terraform_lock = "aws dynamodb scan --table-name ${aws_dynamodb_table.terraform_lock.name}"
  }
}

# Resource ARNs for Reference
output "resource_arns" {
  description = "ARNs of all created resources for reference"
  value = {
    s3_bucket            = aws_s3_bucket.terraform_state.arn
    domain_secret        = aws_secretsmanager_secret.domain_admin_password.arn
    vpn_secret           = aws_secretsmanager_secret.vpn_credentials.arn
    terraform_role       = aws_iam_role.terraform_execution.arn
    ssm_terraform_role   = aws_ssm_parameter.terraform_role_arn.arn
    ssm_state_bucket     = aws_ssm_parameter.state_bucket.arn
    ssm_lock_table       = aws_ssm_parameter.lock_table.arn
    ssm_domain_secret    = aws_ssm_parameter.domain_secret_arn.arn
    ssm_vpn_secret       = aws_ssm_parameter.vpn_secret_arn.arn
  }
}

# Post-Deployment Instructions
output "next_steps" {
  description = "Next steps after bootstrap completion"
  value = [
    "1. Review the generated terraform.tfvars file in the main project",
    "2. Update management_cidr to your specific IP address for security",
    "3. Run terraform init in the main project directory to configure remote state",
    "4. Deploy the main infrastructure using terraform apply",
    "5. Access pfSense web interface and complete OpenVPN configuration",
    "6. Download OpenVPN client configuration from pfSense",
    "7. Test VPN connectivity and internal resource access"
  ]
}
