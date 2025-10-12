# Cybersecurity Playground Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-v1.0+-623CE4?style=flat&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=flat&logo=amazon-aws)](https://aws.amazon.com/)
[![pfSense](https://img.shields.io/badge/pfSense-Firewall-blue?style=flat)](https://www.pfsense.org/)
[![OWASP](https://img.shields.io/badge/OWASP-JuiceShop-red?style=flat&logo=owasp)](https://owasp-juice.shop/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Terraform-based AWS infrastructure for cybersecurity training and penetration testing exercises. This lab environment provides a realistic, segmented network architecture with vulnerable applications and enterprise services for hands-on security education.
Using boostrap process multiple projects can be created using separate config files.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────────────────┐
│                    AWS VPC (10.0.0.0/16)                   │
│                                                             │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │ Public      │    │        Internet Gateway            │ │
│  │ Subnet      │◄───┤                                     │ │
│  │ 10.0.1.0/24 │    └─────────────────────────────────────┘ │
│  │             │                                           │
│  │ ┌─────────┐ │                                           │
│  │ │pfSense  │ │                                           │
│  │ │Firewall │ │                                           │
│  │ │3 x ENI  │ │                                           │
│  │ └─────────┘ │                                           │
│  └─────────────┘                                           │
│         │                    │                             │
│  ┌─────────────┐       ┌─────────────┐                     │
│  │ Private     │       │ Private     │                     │
│  │ Subnet 1    │       │ Subnet 2    │                     │
│  │ 10.0.2.0/24 │       │ 10.0.3.0/24 │                     │
│  │             │       │             │                     │
│  │┌───────────┐│       │┌───────────┐│                     │
│  ││JuiceShop  ││       ││Windows DC ││                     │
│  ││Docker     ││       ││10.0.3.10  ││                     │
│  ││10.0.2.10  ││       │└───────────┘│                     │
│  │└───────────┘│       │┌───────────┐│                     │
│  └─────────────┘       ││Windows    ││                     │
│                        ││Client     ││                     │
│                        ││10.0.3.20  ││                     │
│                        │└───────────┘│                     │
│                        └─────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## ✨ Features

### 🔥 pfSense Firewall
- **Multi-interface Configuration**: 3 ENIs for WAN/LAN1/LAN2 segmentation
- **Web Management Interface**: HTTPS access for configuration
- **Traffic Filtering**: Network segmentation and access control
- **Port Forwarding**: External access to internal services
- **VPN Capabilities**: Remote access configuration

### 🧃 OWASP JuiceShop
- **Vulnerable Web Application**: OWASP Top 10 vulnerabilities
- **Docker Deployment**: Containerized for easy management
- **Automated Setup**: Self-configuring with systemd service
- **Penetration Testing Target**: Realistic attack scenarios

### 🪟 Windows Active Directory
- **Domain Controller**: Windows Server 2022 with AD DS
- **Client Machine**: Domain-joined Windows workstation
- **Automated Deployment**: PowerShell scripted domain promotion
- **Enterprise Simulation**: Realistic AD environment for testing

### 🌐 Network Architecture
- **VPC Isolation**: Dedicated virtual private cloud (10.0.0.0/16)
- **Subnet Segmentation**: Separate networks for different services
- **Route Management**: Traffic routing through pfSense firewall
- **Security Groups**: Granular firewall rules for each component

## 📋 Prerequisites

### Required Tools
- **AWS CLI**: Configured with appropriate credentials
- **Terraform**: Version 1.0 or higher
- **SSH Key Pair**: For EC2 instance access
- **Git**: For repository cloning

### AWS Permissions
Your AWS user/role requires the following permissions:
- `EC2FullAccess` or equivalent EC2 permissions
- `VPCFullAccess` or equivalent networking permissions
- `IAMReadOnlyAccess` for instance profiles (if needed)

### System Requirements
- **Operating System**: Linux, macOS, or Windows with WSL
- **Memory**: 4GB RAM minimum for Terraform operations
- **Storage**: 1GB free space for Terraform state and modules

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/cybrd0ne/cybersec-playground.git
cd cybersec-playground
mkdir projects
cd projects
mkdir `your project`
cd `your `project`
```

### 2. Create SSH Key Pair
```bash
aws ec2 create-key-pair \
  --key-name cybersec-playground-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/cybersec-lab-key.pem
chmod 400 ~/.ssh/cybersec-lab-key.pem
```

### 3. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific configuration
```

### 4. Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

## ⚙️ Configuration

### terraform.tfvars Example
```hcl
# AWS Configuration
aws_region = "eu-west-1"
environment = "cybersec-playground"
owner = "security-team"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet1_cidr = "10.0.2.0/24"
private_subnet2_cidr = "10.0.3.0/24"

# Security Configuration
management_cidr = "203.0.113.1/32"  # Your IP address

# Instance Configuration
pfsense_instance_type = "t3.medium"
juiceshop_instance_type = "t3.small"
dc_instance_type = "t3.medium"
client_instance_type = "t3.small"

# Access Configuration
key_pair_name = "cybersec-playground-key"

# Active Directory Configuration
domain_name = "cybersec.local"
# domain_admin_password = "ChangeMe or use boostrap and AWS Secrets Manager!"
```

### Infrastructure Components

| Component | Instance Type | Private IP | Purpose |
|-----------|---------------|------------|---------|
| pfSense Firewall | t3.medium | 10.0.1.10 (WAN)<br>10.0.2.1 (LAN1)<br>10.0.3.1 (LAN2) | Network segmentation and security |
| JuiceShop Server | t3.small | 10.0.2.10 | Vulnerable web application |
| Domain Controller | t3.medium | 10.0.3.10 | Active Directory services |
| Windows Client | t3.small | 10.0.3.20 | Domain-joined workstation |

### Security Groups

#### pfSense Firewall
- **HTTPS (443)**: Web management interface
- **HTTP (80)**: Web management interface  
- **SSH (22)**: Command line access
- **All VPC Traffic**: Inter-VLAN routing

#### JuiceShop Application
- **HTTP (3000)**: Web application port
- **SSH (22)**: Administrative access
- **ICMP**: Network diagnostics

#### Windows Environment
- **RDP (3389)**: Remote desktop access
- **DNS (53)**: Domain name resolution
- **LDAP (389/636)**: Directory services
- **Kerberos (88)**: Authentication
- **SMB (445)**: File sharing
- **NetBIOS (137-139)**: Windows networking

## 🔧 Post-Deployment Configuration

### pfSense Setup
1. **Access Web Interface**: `https://<pfsense-public-ip>`
2. **Default Credentials**: admin/pfsense (change immediately)
3. **Complete Setup Wizard**: Configure interfaces and basic settings
4. **Configure Port Forwarding**: 
   ```
   External Port 8080 → 10.0.2.10:3000 (JuiceShop)
   External Port 3389 → 10.0.3.10:3389 (DC RDP)
   External Port 3390 → 10.0.3.20:3389 (Client RDP)
   ```

### JuiceShop Access
- **Internal Access**: http://10.0.2.10:3000
- **External Access**: http://<pfsense-public-ip>:8080 (after port forwarding)
- **Docker Management**: SSH to JuiceShop server for container management

### Windows Active Directory
- **Domain Controller**: RDP to 10.0.3.10 through pfSense port forwarding
- **Client Access**: RDP to 10.0.3.20 through pfSense port forwarding
- **Domain Management**: Use Active Directory Users and Computers

## 🎯 Lab Exercises

### Network Security
- [ ] Configure pfSense firewall rules
- [ ] Set up site-to-site VPN connections
- [ ] Implement network access control (NAC)
- [ ] Monitor network traffic with pfSense logs

### Web Application Security
- [ ] Complete OWASP JuiceShop challenges
- [ ] Perform automated vulnerability scanning
- [ ] Test web application firewall (WAF) rules
- [ ] Practice SQL injection and XSS attacks

### Active Directory Security
- [ ] Enumerate domain users and computers
- [ ] Test Kerberos authentication attacks
- [ ] Practice privilege escalation techniques
- [ ] Implement security hardening measures

### Penetration Testing
- [ ] Conduct network reconnaissance
- [ ] Perform lateral movement exercises
- [ ] Test social engineering scenarios
- [ ] Document findings and remediation steps

## 🛠️ Troubleshooting

### Common Issues

#### pfSense Not Accessible
```bash
# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=*pfsense*"

# Verify elastic IP association
aws ec2 describe-addresses --filters "Name=tag:Name,Values=*pfsense*"

# Check instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=*pfsense*"
```

#### JuiceShop Connectivity Issues
```bash
# SSH to JuiceShop server
ssh -i ~/.ssh/cybersec-lab-key.pem ec2-user@<juiceshop-private-ip>

# Check Docker container status
sudo docker ps
sudo docker logs juice-shop

# Verify network routing
ip route show
```

#### Windows Domain Issues
```bash
# Check domain controller logs
# RDP to DC and review Event Viewer
# Windows Logs > System and Application

# Verify DNS resolution
nslookup cybersec.local <dc-ip>

# Test domain connectivity
Test-NetConnection -ComputerName cybersec.local -Port 389
```

### Resource Cleanup
```bash
# Destroy all resources
terraform destroy

# Verify all resources are deleted
aws ec2 describe-instances --filters "Name=tag:Project,Values=CybersecurityPlayground"
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=cybersec-playground"
```

## 💰 Cost Optimization

### Estimated Monthly Costs
| Component | Instance Type | Hours/Month | Estimated Cost |
|-----------|---------------|-------------|----------------|
| pfSense | t3.medium | 730 | ~$30 |
| JuiceShop | t3.small | 730 | ~$15 |
| Domain Controller | t3.medium | 730 | ~$30 |
| Windows Client | t3.small | 730 | ~$15 |
| **Total** | | | **~$90/month** |

### Cost Reduction Strategies
- Use `t3.micro` instances where possible (free tier eligible)
- Stop instances when not in use
- Implement auto-shutdown schedules
- Use spot instances for testing environments
- Set up AWS billing alerts

## 📁 Project Structure

```
aws-cybersec-lab-terraform/
├── README.md
├── main.tf                     # Main configuration
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── terraform.tfvars.example    # Example configuration
├── modules/
│   ├── network/
│   │   ├── main.tf            # VPC and networking
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/
│   │   ├── main.tf            # Security groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── pfsense/
│   │   ├── main.tf            # pfSense deployment
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── scripts/
│   │       └── pfsense-config.sh
│   ├── juiceshop/
│   │   ├── main.tf            # JuiceShop deployment
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── scripts/
│   │       └── juiceshop-setup.sh
│   └── windows/
│       ├── main.tf            # Windows AD deployment
│       ├── variables.tf
│       ├── outputs.tf
│       └── scripts/
│           ├── dc-setup.ps1
│           └── client-setup.ps1
└── docs/
    ├── DEPLOYMENT.md
    ├── TROUBLESHOOTING.md
    └── EXERCISES.md
```

## 🤝 Contributing

We welcome contributions to improve this cybersecurity lab infrastructure!

### How to Contribute
1. **Fork the Repository**: Click the fork button on GitHub
2. **Create Feature Branch**: `git checkout -b feature/amazing-feature`
3. **Make Changes**: Implement your improvements
4. **Test Thoroughly**: Ensure all components work correctly
5. **Commit Changes**: `git commit -m 'Add amazing feature'`
6. **Push to Branch**: `git push origin feature/amazing-feature`
7. **Open Pull Request**: Submit your changes for review

### Contribution Guidelines
- Follow Terraform best practices and formatting
- Update documentation for new features
- Test changes in isolated AWS account
- Include example configurations
- Add appropriate security considerations

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This infrastructure is designed for educational and testing purposes only. The deployed applications contain intentional vulnerabilities and should never be exposed to public networks or used in production environments. Always follow responsible disclosure practices and obtain proper authorization before conducting security testing.

## 🙏 Acknowledgments

- [OWASP JuiceShop](https://owasp-juice.shop/) - Vulnerable web application
- [pfSense](https://www.pfsense.org/) - Open source firewall
- [HashiCorp Terraform](https://www.terraform.io/) - Infrastructure as Code
- [AWS](https://aws.amazon.com/) - Cloud infrastructure platform
- Cybersecurity community for educational resources

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/cybrd0ne/cybersec-playground/issues)
- **Discussions**: [GitHub Discussions](https://github.com/cybrd0ne/cybersec-playground/discussions)
- **Documentation**: [Project Docs](https://github.com/cybrd0ne/cybersec-playground/docs)

---

**Happy Learning! 🎓🔐**
