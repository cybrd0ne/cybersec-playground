# Example terraform.tfvars file
# Copy this file to terraform.tfvars and customize values

# AWS Configuration
aws_region = "eu-west-1"
environment = "cybersec-playground"
owner = "cybrd0ne"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet1_cidr = "10.0.2.0/24"
private_subnet2_cidr = "10.0.3.0/24"

# IMPORTANT: Change this to your specific IP address for security
management_cidr = "YOUR_PUBLIC_IP/32"  # e.g., "203.0.113.1/32"

# Instance Configuration
pfsense_instance_type = "t3.medium"     # Minimum recommended for pfSense
juiceshop_instance_type = "t3.small"
dc_instance_type = "t3.medium"          # Recommended for AD DC
client_instance_type = "t3.small"

# REQUIRED: Create an EC2 Key Pair in AWS Console first
key_pair_name = "your-key-pair-name"

# Active Directory Configuration
domain_name = "cybersec.local"
domain_admin_password = "ComplexPassword123!"  # Use a strong password

# Additional Notes:
# 1. Make sure to create an EC2 Key Pair before running terraform
# 2. Update management_cidr to your specific IP for security
# 3. Consider using AWS Secrets Manager for the domain password in production
# 4. Review instance types based on your performance requirements
# 5. Ensure you have sufficient AWS service limits for the resources
