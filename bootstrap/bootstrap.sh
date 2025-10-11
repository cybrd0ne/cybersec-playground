#!/bin/bash

# AWS Cybersecurity Lab Bootstrap Script
# This script sets up the infrastructure prerequisites and project structure

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_NAME="aws-cybersec-lab"
AWS_REGION="${AWS_REGION:-us-east-1}"
KEY_PAIR_NAME="${KEY_PAIR_NAME:-cybersec-lab-key}"
DOMAIN_ADMIN_PASSWORD="${DOMAIN_ADMIN_PASSWORD:-}"
DOMAIN_NAME="${DOMAIN_NAME:-cybersec.local}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is installed and configured
check_aws_cli() {
    print_status "Checking AWS CLI installation..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        echo "Installation instructions: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        echo "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    local identity=$(aws sts get-caller-identity --output text --query 'Account')
    print_success "AWS CLI configured. Account ID: $identity"
}

# Function to check if Terraform is installed
check_terraform() {
    print_status "Checking Terraform installation..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        echo "Installation instructions: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi
    
    local version=$(terraform version -json | jq -r '.terraform_version')
    print_success "Terraform installed. Version: $version"
}

# Function to generate secure password if not provided
generate_password() {
    if [ -z "$DOMAIN_ADMIN_PASSWORD" ]; then
        print_status "Generating secure domain administrator password..."
        DOMAIN_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
        print_success "Password generated. It will be stored in AWS Secrets Manager."
    fi
}

# Function to create project directory structure
create_directory_structure() {
    print_status "Creating project directory structure..."
    
    local dirs=(
        "${PROJECT_NAME}"
        "${PROJECT_NAME}/bootstrap"
        "${PROJECT_NAME}/modules/network"
        "${PROJECT_NAME}/modules/security"
        "${PROJECT_NAME}/modules/pfsense/scripts"
        "${PROJECT_NAME}/modules/juiceshop/scripts"
        "${PROJECT_NAME}/modules/windows/scripts"
        "${PROJECT_NAME}/scripts"
        "${PROJECT_NAME}/docs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        print_status "Created directory: $dir"
    done
    
    print_success "Directory structure created successfully"
}

# Function to create EC2 Key Pair
create_key_pair() {
    print_status "Checking for existing EC2 Key Pair: $KEY_PAIR_NAME"
    
    if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$AWS_REGION" &> /dev/null; then
        print_warning "Key pair '$KEY_PAIR_NAME' already exists. Skipping creation."
        return 0
    fi
    
    print_status "Creating EC2 Key Pair: $KEY_PAIR_NAME"
    
    local key_material=$(aws ec2 create-key-pair \
        --key-name "$KEY_PAIR_NAME" \
        --key-type rsa \
        --key-format pem \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text)
    
    if [ $? -eq 0 ]; then
        echo "$key_material" > "${PROJECT_NAME}/${KEY_PAIR_NAME}.pem"
        chmod 400 "${PROJECT_NAME}/${KEY_PAIR_NAME}.pem"
        print_success "Key pair created and saved to ${PROJECT_NAME}/${KEY_PAIR_NAME}.pem"
    else
        print_error "Failed to create EC2 Key Pair"
        exit 1
    fi
}

# Function to deploy bootstrap Terraform resources
deploy_bootstrap_resources() {
    print_status "Deploying bootstrap Terraform resources..."
    
    cd "${PROJECT_NAME}/bootstrap"
    
    # Create bootstrap terraform.tfvars
    cat > terraform.tfvars <<EOF
aws_region = "$AWS_REGION"
project_name = "$PROJECT_NAME"
key_pair_name = "$KEY_PAIR_NAME"
domain_name = "$DOMAIN_NAME"
domain_admin_password = "$DOMAIN_ADMIN_PASSWORD"
EOF
    
    # Initialize and apply bootstrap
    terraform init
    terraform plan
    
    print_status "Applying bootstrap resources. This may take a few minutes..."
    terraform apply -auto-approve
    
    if [ $? -eq 0 ]; then
        print_success "Bootstrap resources deployed successfully"
        
        # Get outputs
        local secret_arn=$(terraform output -raw domain_password_secret_arn)
        local terraform_role_arn=$(terraform output -raw terraform_execution_role_arn)
        
        print_success "Domain password stored in Secrets Manager: $secret_arn"
        print_success "Terraform execution role created: $terraform_role_arn"
    else
        print_error "Failed to deploy bootstrap resources"
        exit 1
    fi
    
    cd ../..
}

# Function to create main project configuration files
create_main_config_files() {
    print_status "Creating main project configuration files..."
    
    cd "$PROJECT_NAME"
    
    # Get bootstrap outputs
    local secret_arn=$(cd bootstrap && terraform output -raw domain_password_secret_arn)
    local s3_bucket=$(cd bootstrap && terraform output -raw terraform_state_bucket)
    local dynamodb_table=$(cd bootstrap && terraform output -raw terraform_lock_table)
    
    # Create backend configuration
    cat > backend.tf <<EOF
# Terraform Backend Configuration
terraform {
  backend "s3" {
    bucket         = "$s3_bucket"
    key            = "cybersec-lab/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$dynamodb_table"
    encrypt        = true
  }
}
EOF

    # Create updated terraform.tfvars with Secrets Manager references
    cat > terraform.tfvars <<EOF
# AWS Configuration
aws_region = "$AWS_REGION"
environment = "cybersec-lab"
owner = "$(whoami)"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet1_cidr = "10.0.2.0/24"
private_subnet2_cidr = "10.0.3.0/24"

# IMPORTANT: Update this to your specific IP address for security
management_cidr = "0.0.0.0/0"  # TODO: Change to your IP/32

# Instance Configuration
pfsense_instance_type = "t3.medium"
juiceshop_instance_type = "t3.small"
dc_instance_type = "t3.medium"
client_instance_type = "t3.small"

# Key Pair Configuration
key_pair_name = "$KEY_PAIR_NAME"

# Active Directory Configuration
domain_name = "$DOMAIN_NAME"
domain_password_secret_arn = "$secret_arn"

# Bootstrap Resources
terraform_state_bucket = "$s3_bucket"
terraform_lock_table = "$dynamodb_table"
EOF
    
    print_success "Main configuration files created"
    cd ..
}

# Function to create deployment script
create_deployment_script() {
    print_status "Creating deployment script..."
    
    cat > "${PROJECT_NAME}/deploy.sh" <<'EOF'
#!/bin/bash

# Cybersecurity Lab Deployment Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_status "Initializing Terraform..."
terraform init

print_status "Planning deployment..."
terraform plan

read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deploying infrastructure..."
    terraform apply
    
    if [ $? -eq 0 ]; then
        print_success "Deployment completed successfully!"
        print_status "Infrastructure details:"
        terraform output
    fi
else
    print_status "Deployment cancelled."
fi
EOF
    
    chmod +x "${PROJECT_NAME}/deploy.sh"
    print_success "Deployment script created: ${PROJECT_NAME}/deploy.sh"
}

# Function to create cleanup script
create_cleanup_script() {
    print_status "Creating cleanup script..."
    
    cat > "${PROJECT_NAME}/cleanup.sh" <<'EOF'
#!/bin/bash

# Cybersecurity Lab Cleanup Script

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_warning "This will destroy ALL infrastructure resources!"
print_warning "This action cannot be undone!"
echo

read -p "Are you sure you want to destroy all resources? (yes/no): " -r
if [[ $REPLY == "yes" ]]; then
    print_status "Destroying main infrastructure..."
    terraform destroy
    
    print_status "Destroying bootstrap resources..."
    cd bootstrap
    terraform destroy
    cd ..
    
    print_status "Cleanup completed."
else
    print_status "Cleanup cancelled."
fi
EOF
    
    chmod +x "${PROJECT_NAME}/cleanup.sh"
    print_success "Cleanup script created: ${PROJECT_NAME}/cleanup.sh"
}

# Function to display final instructions
display_final_instructions() {
    echo
    echo "========================================"
    echo -e "${GREEN}Bootstrap Setup Complete!${NC}"
    echo "========================================"
    echo
    echo "Next steps:"
    echo "1. cd $PROJECT_NAME"
    echo "2. Update terraform.tfvars with your IP address in management_cidr"
    echo "3. Copy the main Terraform files to the project directory"
    echo "4. Run ./deploy.sh to deploy the infrastructure"
    echo
    echo "Important files created:"
    echo "- ${PROJECT_NAME}/${KEY_PAIR_NAME}.pem (EC2 Key Pair - keep secure!)"
    echo "- ${PROJECT_NAME}/terraform.tfvars (Configuration file)"
    echo "- ${PROJECT_NAME}/deploy.sh (Deployment script)"
    echo "- ${PROJECT_NAME}/cleanup.sh (Cleanup script)"
    echo
    echo "Domain administrator password is stored in AWS Secrets Manager."
    echo "Terraform state will be stored remotely in S3 with DynamoDB locking."
    echo
    echo -e "${YELLOW}Don't forget to update management_cidr in terraform.tfvars!${NC}"
}

# Main execution flow
main() {
    echo "========================================"
    echo -e "${BLUE}AWS Cybersecurity Lab Bootstrap${NC}"
    echo "========================================"
    echo
    
    check_aws_cli
    check_terraform
    generate_password
    create_directory_structure
    create_key_pair
    deploy_bootstrap_resources
    create_main_config_files
    create_deployment_script
    create_cleanup_script
    display_final_instructions
}

# Run main function
main "$@"