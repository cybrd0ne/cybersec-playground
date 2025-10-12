#!/bin/bash

# Enhanced AWS Cybersecurity Playground Bootstrap Script
# This script downloads Terraform files and sets up the complete infrastructure

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_NAME="projects/${CYBERSEC_PLAYGROUND_PROJECT:aws-cybersec-lab}"
AWS_REGION="${CYBERSEC_PLAYGROUND_AWS_REGION:-eu-west-1}"
KEY_PAIR_NAME="${CYBERSEC_PLAYGROUND_KEY_PAIR_NAME:-cybersec-playground-key}"
DOMAIN_ADMIN_PASSWORD="${CYBERSEC_PLAYGROUND_DOMAIN_ADMIN_PASSWORD:-}"
DOMAIN_NAME="${CYBERSEC_PLAYGROUND_DOMAIN_NAME:-cybersec.local}"
MANAGEMENT_IP="${CYBERSEC_PLAYGROUND_MANAGEMENT_IP:-}"
OWNER="${CYBERSEC_PLAYGROUND_OWNER:$(whoami)}

# File mapping for organizing Terraform files
declare -A FILE_MAPPING=(
    # Bootstrap files
    ["bootstrap-main.tf"]="bootstrap/main.tf"
    ["bootstrap-variables.tf"]="bootstrap/variables.tf"
    ["bootstrap-outputs.tf"]="bootstrap/outputs.tf"
    
    # Main files (use updated versions with Secrets Manager)
    ["main.tf"]="main.tf"
    ["variables.tf"]="variables.tf"
    ["outputs.tf"]="outputs.tf"
    
    # Network module
    ["network-main.tf"]="modules/network/main.tf"
    ["network-variables.tf"]="modules/network/variables.tf"
    ["network-outputs.tf"]="modules/network/outputs.tf"
    
    # Security module
    ["security-main.tf"]="modules/security/main.tf"
    ["security-variables.tf"]="modules/security/variables.tf"
    ["security-outputs.tf"]="modules/security/outputs.tf"
    
    # pfSense module
    ["pfsense-main.tf"]="modules/pfsense/main.tf"
    ["pfsense-variables.tf"]="modules/pfsense/variables.tf"
    ["pfsense-outputs.tf"]="modules/pfsense/outputs.tf"
    ["pfsense-config.sh"]="modules/pfsense/scripts/pfsense-config.sh"
    
    # JuiceShop module
    ["juiceshop-main.tf"]="modules/juiceshop/main.tf"
    ["juiceshop-variables.tf"]="modules/juiceshop/variables.tf"
    ["juiceshop-outputs.tf"]="modules/juiceshop/outputs.tf"
    ["juiceshop-setup.sh"]="modules/juiceshop/scripts/juiceshop-setup.sh"
    
    # Windows module
    ["windows-main.tf"]="modules/windows/main.tf"
    ["windows-variables.tf"]="modules/windows/variables.tf"
    ["windows-outputs.tf"]="modules/windows/outputs.tf"
    ["windows-dc-setup.ps1"]="modules/windows/scripts/dc-setup.ps1"
    ["windows-client-setup.ps1"]="modules/windows/scripts/client-setup.ps1"
    
    # Documentation
    ["README.md"]="README.md"
    ["DEPLOYMENT_GUIDE.md"]="docs/DEPLOYMENT_GUIDE.md"
)

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

# Function to get user's public IP
get_public_ip() {
    if [ -z "$MANAGEMENT_IP" ]; then
        print_status "Detecting your public IP address..."
        MANAGEMENT_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null | tr -d '\n')
        if [ -n "$MANAGEMENT_IP" ]; then
            print_success "Detected public IP: $MANAGEMENT_IP"
            read -p "Use this IP for management access? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                read -p "Enter your public IP address: " MANAGEMENT_IP
            fi
        else
            print_warning "Could not detect public IP automatically"
            read -p "Enter your public IP address for management access: " MANAGEMENT_IP
        fi
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    elif ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is installed but not configured properly"
        echo "Please run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    # Check jq (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --output text --query 'Account')
    print_success "Prerequisites check passed. AWS Account ID: $account_id"
}

# Function to generate secure password
generate_password() {
    if [ -z "$DOMAIN_ADMIN_PASSWORD" ]; then
        print_status "Generating secure domain administrator password..."
        # Generate a complex password that meets Windows requirements
        DOMAIN_ADMIN_PASSWORD="CyberSec$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-8)!"
        print_success "Password generated. It will be stored securely in AWS Secrets Manager."
    fi
}

# Function to create directory structure
create_directory_structure() {
    print_status "Creating project directory structure..."
    
    if [ -d "$PROJECT_NAME" ]; then
        print_warning "Directory $PROJECT_NAME already exists. Contents may be overwritten."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Operation cancelled."
            exit 0
        fi
    fi
    
    local dirs=(
        "projects"
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
	mkdir -p "projects"
	cd "projects"
        mkdir -p "$dir"
	cd ../
    done
    
    print_success "Directory structure created"
}

# Function to organize Terraform files
organize_terraform_files() {
    print_status "Organizing Terraform files..."
    
    local files_moved=0
    local missing_files=()
    
    for source_file in "${!FILE_MAPPING[@]}"; do
        local target_path="${PROJECT_NAME}/${FILE_MAPPING[$source_file]}"
        
        if [ -f "$source_file" ]; then
            # Create target directory if it doesn't exist
            mkdir -p "$(dirname "$target_path")"
            
            # Move and rename the file
            cp templates/aws/"$source_file" "$target_path"
            files_moved=$((files_moved + 1))
            print_status "Moved: $source_file → ${FILE_MAPPING[$source_file]}"
        else
            missing_files+=("$source_file")
        fi
    done
    
    if [ templates/aws/${#missing_files[@]} -ne 0 ]; then
        print_warning "Missing files (will need to be added manually):"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
    fi
    
    print_success "Organized $files_moved Terraform files"
}

# Function to make scripts executable
make_scripts_executable() {
    print_status "Making scripts executable..."
    
    local script_files=(
        "${PROJECT_NAME}/modules/pfsense/scripts/pfsense-config.sh"
        "${PROJECT_NAME}/modules/juiceshop/scripts/juiceshop-setup.sh"
    )
    
    for script in "${script_files[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            print_status "Made executable: $script"
        fi
    done
}

# Function to create EC2 Key Pair
create_key_pair() {
    print_status "Managing EC2 Key Pair: $KEY_PAIR_NAME"
    
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

# Function to deploy bootstrap resources
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
    
    print_status "Planning bootstrap deployment..."
    terraform plan
    
    read -p "Deploy bootstrap resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deploying bootstrap resources. This may take a few minutes..."
        terraform apply -auto-approve
        
        if [ $? -eq 0 ]; then
            print_success "Bootstrap resources deployed successfully"
        else
            print_error "Failed to deploy bootstrap resources"
            exit 1
        fi
    else
        print_warning "Bootstrap deployment skipped. You'll need to deploy manually."
        cd ../..
        return 1
    fi
    
    cd ../..
    return 0
}

# Function to create main project configuration
create_main_config() {
    print_status "Creating main project configuration..."
    
    cd "$PROJECT_NAME"
    
    # Only proceed if bootstrap was deployed
    if [ ! -d "bootstrap" ] || [ ! -f "bootstrap/terraform.tfstate" ]; then
        print_warning "Bootstrap not deployed. Creating basic configuration."
        create_basic_config
        cd ..
        return
    fi
    
    # Get bootstrap outputs
    local secret_arn=$(cd bootstrap && terraform output -raw domain_password_secret_arn 2>/dev/null || echo "")
    local s3_bucket=$(cd bootstrap && terraform output -raw terraform_state_bucket 2>/dev/null || echo "")
    local dynamodb_table=$(cd bootstrap && terraform output -raw terraform_lock_table 2>/dev/null || echo "")
    
    # Create backend configuration
    if [ -n "$s3_bucket" ] && [ -n "$dynamodb_table" ]; then
        cat > backend.tf <<EOF
# Terraform Backend Configuration
terraform {
  backend "s3" {
    bucket         = "$s3_bucket"
    key            = "cybersec-lab/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    use_lockfile   = true
  }
}
EOF
        print_success "Remote backend configuration created"
    fi
    
    # Create terraform.tfvars
    cat > terraform.tfvars <<EOF
# AWS Configuration
aws_region = "$AWS_REGION"
environment = "cybersec-playground"
owner = "$OWNER"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet1_cidr = "10.0.2.0/24"
private_subnet2_cidr = "10.0.3.0/24"

# Security Configuration
management_cidr = "${MANAGEMENT_IP}/32"

# Instance Configuration
pfsense_instance_type = "t3.medium"
juiceshop_instance_type = "t3.small"
dc_instance_type = "t3.medium"
client_instance_type = "t3.small"

# Access Configuration
key_pair_name = "$KEY_PAIR_NAME"

# Active Directory Configuration
domain_name = "$DOMAIN_NAME"
domain_password_secret_arn = "$secret_arn"

# Bootstrap Resources (for reference)
terraform_state_bucket = "$s3_bucket"
terraform_lock_table = "$dynamodb_table"
EOF
    
    print_success "Main configuration created with Secrets Manager integration"
    cd ..
}

# Function to create basic config (fallback)
create_basic_config() {
    cat > terraform.tfvars <<EOF
# AWS Configuration
aws_region = "$AWS_REGION"
environment = "cybersec-playground"
owner = "$(whoami)"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet1_cidr = "10.0.2.0/24"
private_subnet2_cidr = "10.0.3.0/24"

# Security Configuration - UPDATE THIS TO YOUR IP!
management_cidr = "${MANAGEMENT_IP}/32"

# Instance Configuration
pfsense_instance_type = "t3.medium"
juiceshop_instance_type = "t3.small"
dc_instance_type = "t3.medium"
client_instance_type = "t3.small"

# Access Configuration
key_pair_name = "$KEY_PAIR_NAME"

# Active Directory Configuration
domain_name = "$DOMAIN_NAME"
domain_admin_password = "$DOMAIN_ADMIN_PASSWORD"  # TODO: Move to Secrets Manager
EOF
}

# Function to create deployment scripts
create_deployment_scripts() {
    print_status "Creating deployment and management scripts..."
    
    # Create deployment script
    cat > "${PROJECT_NAME}/deploy.sh" <<'EOF'
#!/bin/bash

# Cybersecurity Playground Deployment Script for $PROJECT_NAME

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_warning "This will deploy AWS resources that incur costs (~$90/month)"
print_warning "Make sure you understand the costs before proceeding"
echo

read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deployment cancelled."
    exit 0
fi

print_status "Initializing Terraform..."
terraform init

print_status "Planning deployment..."
terraform plan

echo
read -p "Apply the deployment plan? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deploying infrastructure..."
    terraform apply
    
    if [ $? -eq 0 ]; then
        print_success "Deployment completed successfully!"
        echo
        print_status "Infrastructure access details:"
        terraform output
    fi
else
    print_status "Deployment cancelled."
fi
EOF

    # Create cleanup script
    cat > "${PROJECT_NAME}/cleanup.sh" <<'EOF'
#!/bin/bash

# Cybersecurity Lab Cleanup Script

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error "⚠️  DESTRUCTIVE OPERATION WARNING ⚠️"
print_warning "This will permanently destroy ALL infrastructure resources!"
print_warning "This includes:"
echo "  • All EC2 instances and data"
echo "  • VPC and network configuration"
echo "  • Security groups and settings"
echo "  • Any data stored on the instances"
echo
print_warning "This action CANNOT be undone!"
echo

read -p "Type 'destroy' to confirm permanent deletion: " -r
if [[ $REPLY != "destroy" ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

echo
read -p "Are you absolutely sure? (yes/no): " -r
if [[ $REPLY != "yes" ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

print_status "Destroying main infrastructure..."
terraform destroy

if [ -d "bootstrap" ]; then
    echo
    read -p "Also destroy bootstrap resources (S3, DynamoDB, Secrets)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Destroying bootstrap resources..."
        cd bootstrap
        terraform destroy
        cd ..
    fi
fi

print_success "Cleanup completed."
print_status "Don't forget to delete the EC2 key pair if you no longer need it:"
echo "  aws ec2 delete-key-pair --key-name [your-key-name] --region [your-region]"
EOF

    # Make scripts executable
    chmod +x "${PROJECT_NAME}/deploy.sh"
    chmod +x "${PROJECT_NAME}/cleanup.sh"
    
    print_success "Deployment scripts created"
}

# Function to display summary
display_summary() {
    echo
    echo "========================================"
    echo -e "${GREEN}🎉 Bootstrap Setup Complete! 🎉${NC}"
    echo "========================================"
    echo
    echo "📁 Project Structure:"
    echo "   $PROJECT_NAME/"
    echo "   ├── projects/            # Projects using Terraform config"
    echo "   ├── bootstrap/           # Bootstrap Terraform config"
    echo "   ├── modules/             # Main infrastructure modules"
    echo "   ├── *.tf                 # Main Terraform files"
    echo "   ├── terraform.tfvars     # Your configuration"
    echo "   ├── deploy.sh            # Deployment script"
    echo "   ├── cleanup.sh           # Cleanup script"
    echo "   └── ${KEY_PAIR_NAME}.pem # EC2 Key Pair (keep secure!)"
    echo
    echo "🚀 Next Steps:"
    echo "   1. cd $PROJECT_NAME"
    echo "   2. Review terraform.tfvars (especially management_cidr)"
    echo "   3. Run: ./deploy.sh"
    echo
    echo "🔑 Important Security Notes:"
    echo "   • Domain password is stored in AWS Secrets Manager"
    echo "   • Management access limited to: ${MANAGEMENT_IP}/32"
    echo "   • EC2 key pair saved as ${KEY_PAIR_NAME}.pem"
    echo
    echo "💰 Cost Estimate: ~$90/month while running"
    echo "   • Use ./cleanup.sh to destroy resources when done"
    echo
    echo "📚 Documentation:"
    echo "   • README.md - Project overview"
    echo "   • docs/DEPLOYMENT_GUIDE.md - Detailed setup guide"
    echo
    echo -e "${YELLOW}Happy Learning! 🎓🔐${NC}"
}

# Main execution
main() {
    echo "========================================"
    echo -e "${BLUE}🔧 AWS Cybersecurity Lab Bootstrap 🔧${NC}"
    echo "========================================"
    echo
    
    check_prerequisites
    get_public_ip
    generate_password
    create_directory_structure
    organize_terraform_files
    make_scripts_executable
    create_key_pair
    
    if deploy_bootstrap_resources; then
        create_main_config
    else
        print_warning "Continuing without bootstrap deployment"
        cd "$PROJECT_NAME"
        create_basic_config
        cd ..
    fi
    
    create_deployment_scripts
    display_summary
}

# Execute main function
main "$@"
