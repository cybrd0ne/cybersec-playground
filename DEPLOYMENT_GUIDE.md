# AWS Cybersecurity Lab Deployment Guide

## File Organization Structure

Create the following directory structure for your Terraform project:

```
aws-cybersec-lab-terraform/
├── main.tf                     # Main configuration file
├── variables.tf                # Main variables file
├── outputs.tf                  # Main outputs file
├── terraform.tfvars.example    # Example configuration file
├── README.md                   # Project documentation
├── modules/
│   ├── network/
│   │   ├── main.tf            # Network module (network-main.tf)
│   │   ├── variables.tf       # Network variables (network-variables.tf)
│   │   └── outputs.tf         # Network outputs (network-outputs.tf)
│   ├── security/
│   │   ├── main.tf            # Security groups (security-main.tf)
│   │   ├── variables.tf       # Security variables (security-variables.tf)
│   │   └── outputs.tf         # Security outputs (security-outputs.tf)
│   ├── pfsense/
│   │   ├── main.tf            # pfSense deployment (pfsense-main.tf)
│   │   ├── variables.tf       # pfSense variables (pfsense-variables.tf)
│   │   ├── outputs.tf         # pfSense outputs (pfsense-outputs.tf)
│   │   └── scripts/
│   │       └── pfsense-config.sh  # pfSense configuration script
│   ├── juiceshop/
│   │   ├── main.tf            # JuiceShop deployment (juiceshop-main.tf)
│   │   ├── variables.tf       # JuiceShop variables (juiceshop-variables.tf)
│   │   ├── outputs.tf         # JuiceShop outputs (juiceshop-outputs.tf)
│   │   └── scripts/
│   │       └── juiceshop-setup.sh  # JuiceShop setup script
│   └── windows/
│       ├── main.tf            # Windows AD deployment (windows-main.tf)
│       ├── variables.tf       # Windows variables (windows-variables.tf)
│       ├── outputs.tf         # Windows outputs (windows-outputs.tf)
│       └── scripts/
│           ├── dc-setup.ps1   # Domain Controller setup script
│           └── client-setup.ps1  # Windows client setup script
└── .gitignore                 # Git ignore file (optional)
```

## File Mapping

The downloaded files should be renamed and placed as follows:

| Downloaded File | Target Location |
|----------------|-----------------|
| main.tf | `./main.tf` |
| variables.tf | `./variables.tf` |
| outputs.tf | `./outputs.tf` |
| terraform.tfvars.example | `./terraform.tfvars.example` |
| network-main.tf | `./modules/network/main.tf` |
| network-variables.tf | `./modules/network/variables.tf` |
| network-outputs.tf | `./modules/network/outputs.tf` |
| security-main.tf | `./modules/security/main.tf` |
| security-variables.tf | `./modules/security/variables.tf` |
| security-outputs.tf | `./modules/security/outputs.tf` |
| pfsense-main.tf | `./modules/pfsense/main.tf` |
| pfsense-variables.tf | `./modules/pfsense/variables.tf` |
| pfsense-outputs.tf | `./modules/pfsense/outputs.tf` |
| pfsense-config.sh | `./modules/pfsense/scripts/pfsense-config.sh` |
| juiceshop-main.tf | `./modules/juiceshop/main.tf` |
| juiceshop-variables.tf | `./modules/juiceshop/variables.tf` |
| juiceshop-outputs.tf | `./modules/juiceshop/outputs.tf` |
| juiceshop-setup.sh | `./modules/juiceshop/scripts/juiceshop-setup.sh` |
| windows-main.tf | `./modules/windows/main.tf` |
| windows-variables.tf | `./modules/windows/variables.tf` |
| windows-outputs.tf | `./modules/windows/outputs.tf` |
| dc-setup.ps1 | `./modules/windows/scripts/dc-setup.ps1` |
| client-setup.ps1 | `./modules/windows/scripts/client-setup.ps1` |
| README.md | `./README.md` |

## Quick Setup Commands

### 1. Create Directory Structure
```bash
mkdir -p aws-cybersec-lab-terraform/modules/{network,security,pfsense,juiceshop,windows}/scripts
cd aws-cybersec-lab-terraform
```

### 2. Place Files in Correct Locations
Move the downloaded files to their respective locations as shown in the table above.

### 3. Make Scripts Executable
```bash
chmod +x modules/pfsense/scripts/pfsense-config.sh
chmod +x modules/juiceshop/scripts/juiceshop-setup.sh
```

### 4. Create Configuration File
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

### 5. Initialize and Deploy
```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

## Prerequisites Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform v1.0+ installed
- [ ] EC2 Key Pair created in AWS
- [ ] Appropriate AWS permissions (EC2, VPC, IAM)
- [ ] Updated `terraform.tfvars` with your values

## Important Notes

1. **Security**: Update `management_cidr` in `terraform.tfvars` to your specific IP address
2. **Key Pair**: Create an EC2 Key Pair before running Terraform
3. **Domain Password**: Use a strong password for the Active Directory domain administrator
4. **Region**: Ensure you're deploying to the correct AWS region
5. **Costs**: Review the estimated costs before deployment (~$90/month for all resources)

## Post-Deployment Steps

1. **pfSense Configuration**: Access web interface at the public IP and complete setup
2. **Port Forwarding**: Configure port forwarding rules in pfSense for applications
3. **Testing**: Verify connectivity to JuiceShop and Windows machines through pfSense
4. **Domain Management**: Access Domain Controller for Active Directory administration

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

This will remove all AWS resources and stop incurring charges.

## Support

If you encounter issues:
1. Check the AWS CloudFormation console for detailed error messages
2. Review EC2 instance logs through Systems Manager Session Manager
3. Verify security group rules and network connectivity
4. Ensure your AWS account has sufficient service limits

Happy learning! 🎓🔐