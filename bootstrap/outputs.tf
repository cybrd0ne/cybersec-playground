# Bootstrap Outputs

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "domain_password_secret_arn" {
  description = "ARN of the domain administrator password secret"
  value       = aws_secretsmanager_secret.domain_admin_password.arn
}

output "terraform_execution_role_arn" {
  description = "ARN of the Terraform execution role"
  value       = aws_iam_role.terraform_execution.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "setup_summary" {
  description = "Summary of bootstrap setup"
  value = {
    state_bucket      = aws_s3_bucket.terraform_state.bucket
    lock_table        = aws_dynamodb_table.terraform_lock.name
    secret_name       = aws_secretsmanager_secret.domain_admin_password.name
    terraform_role    = aws_iam_role.terraform_execution.name
    region           = var.aws_region
    project_name     = var.project_name
  }
}