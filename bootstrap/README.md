# AWS Cybersecurity Lab Bootstrap Guide

This comprehensive bootstrap system sets up your AWS cybersecurity lab infrastructure with proper security practices, including AWS Secrets Manager integration, remote state management, and automated resource provisioning.

## 🎯 What the Bootstrap System Does

### 1. Infrastructure Prerequisites
- **S3 Backend**: Creates S3 bucket for Terraform state with encryption and versioning
- **DynamoDB Locking**: Sets up state locking to prevent concurrent modifications
- **IAM Roles**: Creates execution roles with least-privilege permissions
- **Secrets Manager**: Securely stores domain administrator password
- **EC2 Key Pair**: Generates SSH key pair for instance access

### 2. Project Organization
- **Directory Structure**: Creates proper Terraform module hierarchy
- **File Organization**: Places all Terraform files in correct locations
- **Script Management**: Sets up deployment and cleanup scripts
- **Configuration**: Generates customized terraform.tfvars

### 3. Security Best Practices
- **Network Isolation**: Automatically detects and configures your management IP
- **Password Security**: Generates and stores complex passwords securely
- **Access Control**: Implements least-privilege IAM policies
- **Encryption**: Enables encryption for all storage components

## 📋 Prerequisites

### Required Software
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
curl -fsSL https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip -o terraform.zip
unzip terraform.zip
sudo mv terraform /usr/local/bin/

# jq (JSON processor)
sudo apt-get install jq  # Ubuntu/Debian
sudo yum install jq      # RHEL/CentOS
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]  
# Default region: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### Required AWS Permissions
Your AWS user/role needs these permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "vpce:*",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:PutBucketPolicy",
                "s3:PutBucketVersioning",
                "s3:PutEncryptionConfiguration",
                "dynamodb:CreateTable",
                "dynamodb:DeleteTable",
                "secretsmanager:CreateSecret",
                "secretsmanager:DeleteSecret",
                "secretsmanager:PutSecretValue",
                "ssm:PutParameter",
                "ssm:DeleteParameter"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🚀 Quick Start

### 1. Download Bootstrap Script
```bash
# Download the enhanced bootstrap script
curl -O https://raw.githubusercontent.com/your-repo/aws-cybersec-lab/main/bootstrap-enhanced.sh
chmod +x bootstrap-enhanced.sh
```

### 2. Download All Terraform Files
```bash
# Download all required Terraform files to current directory
# Place all *.tf files in the same directory as bootstrap-enhanced.sh
```

### 3. Run Bootstrap
```bash
# Basic usage (will prompt for inputs)
./bootstrap-enhanced.sh

# With environment variables
AWS_REGION=us-east-1 \
KEY_PAIR_NAME=my-cybersec-key \
DOMAIN_NAME=lab.local \
MANAGEMENT_IP=203.0.113.1 \
./bootstrap-enhanced.sh
```

### 4. Deploy Infrastructure
```bash
cd aws-cybersec-lab
./deploy.sh
```

## ⚙️ Configuration Options

### Environment Variables
```bash
export AWS_REGION="us-east-1"              # AWS region for deployment
export KEY_PAIR_NAME="cybersec-lab-key"    # EC2 key pair name
export DOMAIN_NAME="cybersec.local"        # AD domain name
export DOMAIN_ADMIN_PASSWORD=""             # Leave empty for auto-generation
export MANAGEMENT_IP="203.0.113.1"         # Your public IP (auto-detected if empty)
```

### Project Structure Created
```
aws-cybersec-lab/
├── bootstrap/                      # Bootstrap Terraform configuration
│   ├── main.tf                    # S3, DynamoDB, Secrets Manager, IAM
│   ├── variables.tf               # Bootstrap variables
│   ├── outputs.tf                 # Bootstrap outputs
│   └── terraform.tfvars           # Bootstrap configuration
├── modules/                       # Infrastructure modules
│   ├── network/                   # VPC, subnets, routing
│   ├── security/                  # Security groups
│   ├── pfsense/                   # pfSense firewall
│   ├── juiceshop/                 # Vulnerable web application
│   └── windows/                   # Active Directory environment
├── main.tf                        # Main infrastructure configuration
├── variables.tf                   # Main variables (with Secrets Manager)
├── outputs.tf                     # Infrastructure outputs
├── backend.tf                     # Remote state configuration
├── terraform.tfvars               # Your customized configuration
├── deploy.sh                      # Deployment automation script
├── cleanup.sh                     # Resource cleanup script
├── cybersec-lab-key.pem          # EC2 SSH private key
└── docs/
    └── DEPLOYMENT_GUIDE.md        # Detailed deployment guide
```

## 🔐 Security Features

### Password Management
```bash
# Domain password is automatically generated and stored in Secrets Manager
# Format: CyberSec[8-random-chars]!
# Example: CyberSecX7k9mP2q!

# Retrieve password from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id aws-cybersec-lab/domain-admin-password \
  --query SecretString --output text | jq -r '.password'
```

### Network Security
```bash
# Management access automatically limited to your IP
management_cidr = "203.0.113.1/32"

# Update if your IP changes
sed -i 's/management_cidr = ".*"/management_cidr = "NEW.IP.ADDRESS\/32"/' terraform.tfvars
```

### State Security
```bash
# S3 bucket with encryption and versioning
# DynamoDB table with encryption
# IAM roles with least-privilege access
```

## 📊 Cost Management

### Estimated Monthly Costs
| Component | Instance Type | Monthly Cost |
|-----------|---------------|--------------|
| pfSense Firewall | t3.medium | ~$30 |
| JuiceShop Server | t3.small | ~$15 |
| Domain Controller | t3.medium | ~$30 |
| Windows Client | t3.small | ~$15 |
| **Total** | | **~$90** |

### Cost Optimization
```bash
# Stop instances when not in use
aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=CybersecurityLab" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

# Start instances when needed
aws ec2 start-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=CybersecurityLab" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

# Complete cleanup
./cleanup.sh
```

## 🛠️ Troubleshooting

### Bootstrap Issues
```bash
# Check AWS permissions
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names s3:CreateBucket ec2:CreateKeyPair secretsmanager:CreateSecret

# Check AWS CLI configuration
aws sts get-caller-identity
aws configure list

# Verify region availability
aws ec2 describe-availability-zones --region us-east-1
```

### Deployment Issues
```bash
# Check Terraform state
terraform show
terraform state list

# Verify secrets access
aws secretsmanager get-secret-value --secret-id aws-cybersec-lab/domain-admin-password

# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=CybersecurityLab"
```

### Network Connectivity
```bash
# Update security groups for new management IP
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr NEW.IP.ADDRESS/32

# Test connectivity
curl -k https://PFSENSE-PUBLIC-IP
telnet PFSENSE-PUBLIC-IP 443
```

## 🎓 Usage Scenarios

### Development/Learning
```bash
# Deploy for learning session
./deploy.sh

# Use the lab
# ... perform security exercises ...

# Cleanup when done
./cleanup.sh
```

### Production Training
```bash
# Deploy with custom configuration
vim terraform.tfvars
# Update instance types, network ranges, etc.

# Deploy with review
terraform plan
terraform apply
```

### Multi-Region Deployment
```bash
# Deploy in different region
AWS_REGION=eu-west-1 ./bootstrap-enhanced.sh

# Each region maintains separate state
```

## 📚 Next Steps After Bootstrap

1. **Review Configuration**: Check `terraform.tfvars` for accuracy
2. **Deploy Infrastructure**: Run `./deploy.sh`
3. **Configure pfSense**: Access web interface and set up firewall rules
4. **Test Connectivity**: Verify all components are accessible
5. **Start Learning**: Begin cybersecurity exercises

## 🆘 Support and Resources

### Documentation
- [AWS Terraform Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [pfSense Documentation](https://docs.netgate.com/pfsense/en/latest/)
- [OWASP JuiceShop](https://owasp-juice.shop/)

### Community
- [GitHub Issues](https://github.com/your-repo/aws-cybersec-lab/issues)
- [Security Stack Exchange](https://security.stackexchange.com/)
- [AWS Forums](https://forums.aws.amazon.com/)

### Emergency Cleanup
```bash
# If bootstrap fails midway
cd aws-cybersec-lab/bootstrap 2>/dev/null && terraform destroy -auto-approve
cd ../.. && rm -rf aws-cybersec-lab

# If stuck with resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=CybersecurityLab
```

---

**Happy Learning! 🎓🔐**

*Remember: This infrastructure is for educational purposes. Always follow responsible disclosure practices and obtain proper authorization before conducting security testing.*
