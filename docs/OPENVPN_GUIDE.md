# Enhanced AWS Cybersecurity Lab with OpenVPN Integration

## 🔐 OpenVPN Features Added

The enhanced pfSense configuration now includes a fully automated OpenVPN setup with AWS Secrets Manager integration for secure credential management.

### New Capabilities
- **Automated OpenVPN Server**: Fully configured on pfSense deployment
- **AWS Secrets Manager Integration**: VPN credentials stored securely
- **Certificate Management**: Automated PKI with 2048-bit RSA certificates
- **Client Configuration**: Auto-generated `.ovpn` files
- **Enterprise Security**: AES-256-GCM encryption with SHA-256 authentication
- **Network Integration**: Full access to internal lab networks via VPN

## 📋 Prerequisites

### Enhanced Requirements
```bash
# Standard tools
- AWS CLI v2.x
- Terraform v1.0+
- jq (JSON processor)
- OpenVPN client software

# For certificate management
- openssl
- curl/wget
```

### AWS Permissions (Updated)
The bootstrap now requires additional Secrets Manager permissions:
```json
{
    "Effect": "Allow",
    "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
    ],
    "Resource": "*"
}
```

## 🚀 Enhanced Deployment Process

### 1. Bootstrap with VPN Support
```bash
# Download all enhanced files
# Replace the original files with enhanced versions:
# - enhanced-pfsense-config.sh → modules/pfsense/scripts/pfsense-config.sh
# - enhanced-pfsense-main.tf → modules/pfsense/main.tf
# - enhanced-pfsense-variables.tf → modules/pfsense/variables.tf
# - enhanced-pfsense-outputs.tf → modules/pfsense/outputs.tf
# - enhanced-security-main.tf → modules/security/main.tf
# - enhanced-security-outputs.tf → modules/security/outputs.tf
# - enhanced-bootstrap-*.tf → bootstrap/

# Run enhanced bootstrap
./bootstrap-enhanced.sh
```

### 2. Deploy with VPN Configuration
```bash
cd aws-cybersec-lab
./deploy.sh
```

### 3. Retrieve VPN Credentials
```bash
# Get VPN username and password
aws secretsmanager get-secret-value \
  --secret-id aws-cybersec-lab/vpn-credentials \
  --query SecretString --output text | jq -r '.username, .password'

# Output example:
# vpnuser
# CyberSecVPN8xK9mP2q!
```

## 🔧 OpenVPN Configuration Details

### Server Configuration
The pfSense OpenVPN server is configured with:

```yaml
Network Settings:
  - Server Port: 1194 (UDP/TCP)
  - VPN Subnet: 10.8.0.0/24
  - Pushed Routes: All lab networks (10.0.0.0/16)
  - DNS: Internal DNS resolution

Security Settings:
  - Encryption: AES-256-GCM
  - Authentication: SHA-256
  - TLS Version: 1.2 minimum
  - Key Size: 2048-bit RSA
  - Compression: LZ4-v2

Authentication:
  - Method: Username/Password + Certificates
  - User Database: pfSense local users
  - Certificate Validation: Required
```

### Certificate Hierarchy
```
Certificate Authority (CA)
├── Server Certificate (pfSense)
└── Client Certificate (vpnuser)
```

### Network Routes Pushed to Clients
```
10.0.1.0/24  → Public subnet (pfSense WAN)
10.0.2.0/24  → JuiceShop network
10.0.3.0/24  → Windows AD network
10.0.0.0/16  → All lab networks
```

## 📱 Client Setup

### 1. Download Client Configuration
```bash
# SSH to pfSense instance
ssh -i cybersec-lab-key.pem admin@<pfsense-public-ip>

# Download the client config
scp -i cybersec-lab-key.pem admin@<pfsense-public-ip>:/var/etc/openvpn/client-configs/vpnuser.ovpn ./

# Download credentials file
scp -i cybersec-lab-key.pem admin@<pfsense-public-ip>:/var/etc/openvpn/client-configs/vpnuser-credentials.txt ./
```

### 2. Install OpenVPN Client

#### Windows
```powershell
# Download and install OpenVPN GUI
# https://openvpn.net/community-downloads/

# Import .ovpn file
# Right-click OpenVPN GUI → Import file → Select vpnuser.ovpn
```

#### macOS
```bash
# Install Tunnelblick
brew install --cask tunnelblick

# Import configuration
# Double-click vpnuser.ovpn → Install for all users
```

#### Linux
```bash
# Install OpenVPN client
sudo apt-get install openvpn  # Ubuntu/Debian
sudo yum install openvpn      # RHEL/CentOS

# Connect using CLI
sudo openvpn --config vpnuser.ovpn --auth-user-pass vpnuser-credentials.txt
```

### 3. Connect to VPN
```bash
# When prompted, enter:
Username: vpnuser
Password: [from AWS Secrets Manager]

# Or use credentials file (Linux/macOS)
openvpn --config vpnuser.ovpn --auth-user-pass vpnuser-credentials.txt
```

## 🌐 Network Access via VPN

### Once Connected, You Can Access:

#### JuiceShop Application
```bash
# Direct access to vulnerable web app
http://10.0.2.10:3000

# No port forwarding needed through pfSense
curl http://10.0.2.10:3000
```

#### Windows Active Directory
```bash
# RDP to Domain Controller
rdesktop 10.0.3.10
mstsc /v:10.0.3.10  # Windows

# RDP to Windows Client
rdesktop 10.0.3.20
mstsc /v:10.0.3.20  # Windows

# DNS resolution works
nslookup cybersec.local 10.0.3.10
```

#### pfSense Management
```bash
# Internal management interface
https://10.0.2.1   # LAN1 interface
https://10.0.3.1   # LAN2 interface

# SSH to pfSense (internal)
ssh admin@10.0.2.1
```

## 🔒 Security Features

### Credential Management
```bash
# Credentials are never stored in plain text
# Domain admin password: AWS Secrets Manager
# VPN credentials: AWS Secrets Manager
# Certificates: Generated on pfSense with proper PKI

# Rotate VPN password
aws secretsmanager update-secret \
  --secret-id aws-cybersec-lab/vpn-credentials \
  --secret-string '{"username":"vpnuser","password":"NEW_PASSWORD","server":"openvpn-server","port":1194,"protocol":"udp"}'
```

### Network Security
```yaml
Firewall Rules:
  - OpenVPN: Allow from 0.0.0.0/0 to pfSense:1194
  - Management: Allow from your_ip/32 to pfSense:80,443,22
  - VPN Clients: Allow from 10.8.0.0/24 to all internal networks
  - Internal: All traffic routed through pfSense for inspection

Encryption:
  - VPN Traffic: AES-256-GCM
  - Secrets: AWS KMS encryption
  - Storage: EBS encryption enabled
  - State: S3 bucket encryption (AES-256)
```

### Certificate Security
```bash
# Certificate files on pfSense:
/var/etc/openvpn/keys/ca.crt      # Certificate Authority
/var/etc/openvpn/keys/server.crt  # Server certificate
/var/etc/openvpn/keys/server.key  # Server private key (600 permissions)
/var/etc/openvpn/keys/client.crt  # Client certificate
/var/etc/openvpn/keys/client.key  # Client private key (600 permissions)
/var/etc/openvpn/keys/dh2048.pem  # Diffie-Hellman parameters
/var/etc/openvpn/keys/ta.key      # TLS authentication key
```

## 🛠️ Troubleshooting

### VPN Connection Issues
```bash
# Check pfSense OpenVPN status
ssh admin@<pfsense-public-ip>
sudo service openvpn status
sudo tail -f /var/log/openvpn.log

# Test connectivity to VPN port
telnet <pfsense-public-ip> 1194
nc -u <pfsense-public-ip> 1194  # UDP test

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*pfsense*" \
  --query 'SecurityGroups[].IpPermissions[?FromPort==`1194`]'
```

### Credential Issues
```bash
# Verify secrets exist
aws secretsmanager list-secrets \
  --filters Key=name,Values=aws-cybersec-lab

# Test credential retrieval
aws secretsmanager get-secret-value \
  --secret-id aws-cybersec-lab/vpn-credentials

# Check IAM permissions for pfSense instance
aws sts get-caller-identity
aws iam get-role --role-name aws-cybersec-lab-pfsense-secrets-role
```

### Certificate Issues
```bash
# SSH to pfSense and check certificates
ssh admin@<pfsense-public-ip>
ls -la /var/etc/openvpn/keys/
openssl x509 -in /var/etc/openvpn/keys/ca.crt -text -noout
openssl x509 -in /var/etc/openvpn/keys/server.crt -text -noout

# Regenerate certificates if needed
cd /var/etc/openvpn/keys/
# Follow certificate generation steps from setup script
```

### Network Routing Issues
```bash
# Check VPN client routing table
ip route show    # Linux
route print      # Windows
netstat -rn      # macOS

# Test internal connectivity
ping 10.0.2.10   # JuiceShop
ping 10.0.3.10   # Domain Controller
nslookup cybersec.local 10.0.3.10

# Check pfSense routing
ssh admin@<pfsense-public-ip>
netstat -rn
pfctl -sr  # Show firewall rules
```

## 📊 Monitoring and Logging

### VPN Connection Monitoring
```bash
# Monitor active VPN connections
ssh admin@<pfsense-public-ip>
cat /var/log/openvpn-status.log

# Real-time connection log
tail -f /var/log/openvpn.log

# Connection statistics
netstat -an | grep 1194
```

### Security Auditing
```bash
# Check authentication attempts
grep "authentication" /var/log/openvpn.log

# Monitor certificate validation
grep "certificate" /var/log/openvpn.log

# Track client connections
grep "client" /var/log/openvpn.log
```

## 💡 Best Practices

### Operational Security
1. **Regular Password Rotation**: Update VPN credentials monthly
2. **Certificate Renewal**: Renew certificates before expiration
3. **Access Monitoring**: Review VPN connection logs regularly
4. **Network Segmentation**: Maintain separation between lab networks
5. **Cleanup**: Destroy resources when not in use to prevent costs

### Development Workflow
```bash
# Development cycle
1. Deploy lab environment
2. Connect via VPN for secure access
3. Perform security testing on internal networks
4. Document findings
5. Clean up environment

# Team collaboration
- Share .ovpn files securely (encrypted)
- Use separate VPN users for each team member
- Coordinate lab usage to avoid conflicts
```

## 🎯 Use Cases

### Penetration Testing
- **Remote Testing**: Access internal networks securely from anywhere
- **Network Enumeration**: Scan internal subnets through VPN
- **Lateral Movement**: Practice moving between network segments
- **Web Application Testing**: Direct access to JuiceShop without NAT/port forwarding

### Training and Education
- **Instructor Access**: Demonstrate attacks on internal networks
- **Student Labs**: Provide secure access to dedicated lab environments
- **Scenario-Based Learning**: Create complex multi-network attack scenarios

### Development and Testing
- **Application Development**: Test applications against internal services
- **Security Tool Testing**: Evaluate security tools against realistic networks
- **Configuration Testing**: Test firewall rules and network configurations

---

**🎉 Enhanced Lab Environment Ready!**

Your cybersecurity lab now provides enterprise-grade remote access capabilities with secure credential management and comprehensive network access. The OpenVPN integration enables secure remote learning and testing scenarios while maintaining proper network segmentation and security controls.

**Happy Hacking! 🎓🔐**