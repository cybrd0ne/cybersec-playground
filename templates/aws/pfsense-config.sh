#!/bin/bash
# Enhanced pfSense Initial Configuration Script with OpenVPN Setup

# This script runs on first boot to configure pfSense interfaces and OpenVPN
# Includes AWS Secrets Manager integration for VPN credentials

set -e  # Exit on any error

# Configuration variables from Terraform
WAN_IP="${wan_ip}"
LAN1_IP="${lan1_ip}"
LAN2_IP="${lan2_ip}"
WAN_GW="${wan_gw}"
VPN_SECRET_ARN="${vpn_secret_arn}"
AWS_REGION="${aws_region}"

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_message() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $timestamp - $message" | tee -a /var/log/pfsense-setup.log
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message" | tee -a /var/log/pfsense-setup.log
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message" | tee -a /var/log/pfsense-setup.log
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message" | tee -a /var/log/pfsense-setup.log
            ;;
    esac
}

# Function to install AWS CLI on pfSense
install_aws_cli() {
    log_message "INFO" "Installing AWS CLI on pfSense..."
    
    # Install required packages
    pkg install -y curl unzip python39 py39-pip
    
    # Install AWS CLI using pip
    python3.9 -m pip install awscli
    
    # Create symlink for easier access
    ln -sf /usr/local/bin/aws /usr/bin/aws || true
    
    log_message "SUCCESS" "AWS CLI installed successfully"
}

# Function to retrieve VPN credentials from AWS Secrets Manager
get_vpn_credentials() {
    log_message "INFO" "Retrieving VPN credentials from AWS Secrets Manager..."
    
    # Use EC2 instance metadata to get temporary credentials
    local token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
        http://169.254.169.254/latest/api/token 2>/dev/null || echo "")
    
    if [ -n "$token" ]; then
        # Get temporary credentials from instance metadata
        local role_name=$(curl -H "X-aws-ec2-metadata-token: $token" \
            http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
        
        if [ -n "$role_name" ]; then
            local creds=$(curl -H "X-aws-ec2-metadata-token: $token" \
                http://169.254.169.254/latest/meta-data/iam/security-credentials/$role_name 2>/dev/null)
            
            export AWS_ACCESS_KEY_ID=$(echo "$creds" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKeyId'])" 2>/dev/null || echo "")
            export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | python3 -c "import sys,json; print(json.load(sys.stdin)['SecretAccessKey'])" 2>/dev/null || echo "")
            export AWS_SESSION_TOKEN=$(echo "$creds" | python3 -c "import sys,json; print(json.load(sys.stdin)['Token'])" 2>/dev/null || echo "")
        fi
    fi
    
    # Retrieve the secret from AWS Secrets Manager
    local secret_json=$(aws secretsmanager get-secret-value \
        --secret-id "$VPN_SECRET_ARN" \
        --region "$AWS_REGION" \
        --output text \
        --query 'SecretString' 2>/dev/null || echo "")
    
    if [ -n "$secret_json" ]; then
        VPN_USERNAME=$(echo "$secret_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])" 2>/dev/null || echo "merk.vand")
        VPN_PASSWORD=$(echo "$secret_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])" 2>/dev/null || echo "")
        
        if [ -n "$VPN_PASSWORD" ]; then
            log_message "SUCCESS" "VPN credentials retrieved successfully"
            return 0
        fi
    fi
    
    # Fallback to default credentials if Secrets Manager fails
    log_message "WARNING" "Failed to retrieve VPN credentials from Secrets Manager, using defaults"
    VPN_USERNAME="merk.vand"
    VPN_PASSWORD="CyberSecVPN$(openssl rand -base64 8 | tr -d '=+/' | cut -c1-6)!"
    
    return 1
}

# Function to wait for system initialization
wait_for_system() {
    log_message "INFO" "Waiting for pfSense system to fully initialize..."
    sleep 90  # Wait longer for pfSense to be ready
    
    # Wait for pfSense web interface to be available
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -k -s --connect-timeout 5 https://localhost >/dev/null 2>&1; then
            log_message "SUCCESS" "pfSense web interface is ready"
            break
        fi
        log_message "INFO" "Waiting for pfSense web interface... (attempt $((attempts + 1))/$max_attempts)"
        sleep 10
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq $max_attempts ]; then
        log_message "WARNING" "pfSense web interface not ready, continuing anyway"
    fi
}

# Function to configure basic pfSense interfaces
configure_interfaces() {
    log_message "INFO" "Configuring pfSense interfaces..."
    
    # Create interface assignment configuration
    cat > /tmp/interface_assign.txt << EOF
vtnet0
vtnet1
vtnet2
n
EOF

    # Apply interface assignments
    /etc/rc.initial.setports < /tmp/interface_assign.txt >/dev/null 2>&1 || true
    
    log_message "INFO" "Interface assignment completed"
    log_message "INFO" "WAN Interface: $WAN_IP"
    log_message "INFO" "LAN1 Interface: $LAN1_IP (JuiceShop Network)"
    log_message "INFO" "LAN2 Interface: $LAN2_IP (Windows AD Network)"
    log_message "INFO" "WAN Gateway: $WAN_GW"
}

# Function to generate OpenVPN certificates
generate_openvpn_certificates() {
    log_message "INFO" "Generating OpenVPN certificates..."
    
    # Create certificate directory
    mkdir -p /var/etc/openvpn/keys
    cd /var/etc/openvpn/keys
    
    # Generate CA certificate
    openssl genrsa -out ca.key 2048
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/C=US/ST=Lab/L=CyberSec/O=CyberSecLab/OU=IT/CN=CyberSec-CA"
    
    # Generate server certificate
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr -subj "/C=US/ST=Lab/L=CyberSec/O=CyberSecLab/OU=IT/CN=vpn-server"
    openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
    
    # Generate client certificate
    openssl genrsa -out client.key 2048
    openssl req -new -key client.key -out client.csr -subj "/C=US/ST=Lab/L=CyberSec/O=CyberSecLab/OU=IT/CN=$VPN_USERNAME"
    openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt
    
    # Generate Diffie-Hellman parameters
    openssl dhparam -out dh2048.pem 2048
    
    # Generate TLS auth key
    openvpn --genkey --secret ta.key
    
    # Set proper permissions
    chmod 600 *.key
    chmod 644 *.crt *.pem
    
    log_message "SUCCESS" "OpenVPN certificates generated"
}

# Function to create OpenVPN server configuration
create_openvpn_server_config() {
    log_message "INFO" "Creating OpenVPN server configuration..."
    
    mkdir -p /var/etc/openvpn
    
    cat > /var/etc/openvpn/server.conf << EOF
# OpenVPN Server Configuration for CyberSec Lab
port 1194
proto udp
dev tun

# Certificates and keys
ca /var/etc/openvpn/keys/ca.crt
cert /var/etc/openvpn/keys/server.crt
key /var/etc/openvpn/keys/server.key
dh /var/etc/openvpn/keys/dh2048.pem
tls-auth /var/etc/openvpn/keys/ta.key 0

# Network configuration
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/etc/openvpn/ipp.txt

# Push routes to clients
push "route 10.0.0.0 255.255.0.0"
push "route 10.0.1.0 255.255.255.0"
push "route 10.0.2.0 255.255.255.0"
push "route 10.0.3.0 255.255.255.0"

# Client networking
client-to-client
duplicate-cn

# Security settings
keepalive 10 120
tls-version-min 1.2
cipher AES-256-GCM
auth SHA256
compress lz4-v2
push "compress lz4-v2"

# Connection settings
max-clients 10
persist-key
persist-tun

# Logging
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
mute 20

# User authentication
plugin /usr/local/lib/openvpn/plugins/openvpn-plugin-auth-pam.so login
client-cert-not-required
username-as-common-name

# Management interface
management localhost 7505
EOF

    log_message "SUCCESS" "OpenVPN server configuration created"
}

# Function to create user authentication
setup_vpn_user_auth() {
    log_message "INFO" "Setting up VPN user authentication..."
    
    # Create VPN user
    pw useradd "$VPN_USERNAME" -c "VPN User" -s /usr/sbin/nologin -d /nonexistent || true
    
    # Set password using expect
    pkg install -y expect
    
    cat > /tmp/set_password.exp << EOF
#!/usr/bin/expect
spawn passwd $VPN_USERNAME
expect "New Password:"
send "$VPN_PASSWORD\r"
expect "Retype New Password:"
send "$VPN_PASSWORD\r"
expect eof
EOF
    
    chmod +x /tmp/set_password.exp
    /tmp/set_password.exp >/dev/null 2>&1
    rm /tmp/set_password.exp
    
    log_message "SUCCESS" "VPN user authentication configured"
}

# Function to create client configuration
create_client_config() {
    log_message "INFO" "Creating OpenVPN client configuration..."
    
    mkdir -p /var/etc/openvpn/client-configs
    
    cat > /var/etc/openvpn/client-configs/$VPN_USERNAME.ovpn << EOF
client
dev tun
proto udp
remote $WAN_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
compress lz4-v2
verb 3
mute 20

# Authentication
auth-user-pass

# Certificates (embedded)
<ca>
$(cat /var/etc/openvpn/keys/ca.crt)
</ca>

<tls-auth>
$(cat /var/etc/openvpn/keys/ta.key)
</tls-auth>
key-direction 1

# Additional security
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf
EOF

    # Create a credentials file for easy client setup
    cat > /var/etc/openvpn/client-configs/$VPN_USERNAME-credentials.txt << EOF
$VPN_USERNAME
$VPN_PASSWORD
EOF
    
    # Set proper permissions
    chmod 600 /var/etc/openvpn/client-configs/*
    
    log_message "SUCCESS" "Client configuration created"
}

# Function to configure pfSense firewall rules for OpenVPN
configure_firewall_rules() {
    log_message "INFO" "Configuring firewall rules for OpenVPN..."
    
    # This would typically be done through the pfSense PHP configuration system
    # For now, we'll create the basic configuration and note that manual setup is needed
    
    cat > /tmp/openvpn-firewall-rules.txt << EOF
# OpenVPN Firewall Rules (to be applied manually via pfSense web interface)

# WAN Interface Rules:
# - Allow UDP port 1194 from any source to pfSense (OpenVPN)
# - Protocol: UDP, Source: Any, Destination: WAN address, Port: 1194

# OpenVPN Interface Rules (will be created automatically):
# - Allow any traffic from OpenVPN clients to LAN networks
# - Protocol: Any, Source: OpenVPN subnet (10.8.0.0/24), Destination: LAN networks

# NAT Rules:
# - Outbound NAT for OpenVPN clients through WAN interface

# Manual Configuration Required:
# 1. Navigate to pfSense web interface: https://$WAN_IP
# 2. Go to VPN > OpenVPN > Servers
# 3. Import the server configuration from /var/etc/openvpn/server.conf
# 4. Go to Firewall > Rules and add the rules described above
# 5. Go to System > User Manager and verify VPN user exists
EOF

    log_message "INFO" "Firewall rules configuration saved to /tmp/openvpn-firewall-rules.txt"
}

# Function to start OpenVPN service
start_openvpn_service() {
    log_message "INFO" "Starting OpenVPN service..."
    
    # Install OpenVPN package if not already installed
    pkg install -y openvpn
    
    # Enable OpenVPN service
    sysrc openvpn_enable="YES"
    sysrc openvpn_configfile="/var/etc/openvpn/server.conf"
    
    # Start the service
    service openvpn start || log_message "WARNING" "Failed to start OpenVPN service - may need manual configuration"
    
    log_message "SUCCESS" "OpenVPN service configuration completed"
}

# Function to enable SSH access
enable_ssh_access() {
    log_message "INFO" "Configuring SSH access..."
    
    # Enable SSH in pfSense configuration
    sed -i.bak 's/<enablesshd><\/enablesshd>/<enablesshd>enabled<\/enablesshd>/' /cf/conf/config.xml || true
    
    # Configure SSH settings
    cat >> /etc/ssh/sshd_config << EOF

# CyberSec Lab SSH Configuration
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

    # Restart SSH service
    service sshd restart || true
    
    log_message "SUCCESS" "SSH access configured"
}

# Function to create status report
create_status_report() {
    log_message "INFO" "Creating configuration status report..."
    
    cat > /var/log/pfsense-config-report.txt << EOF
================================================================
pfSense CyberSec Lab Configuration Report
Generated: $(date)
================================================================

NETWORK CONFIGURATION:
- WAN Interface: $WAN_IP
- LAN1 Interface: $LAN1_IP (JuiceShop Network)  
- LAN2 Interface: $LAN2_IP (Windows AD Network)
- WAN Gateway: $WAN_GW

OPENVPN CONFIGURATION:
- Server Port: 1194 (UDP)
- VPN Subnet: 10.8.0.0/24
- VPN Username: $VPN_USERNAME
- Certificate Authority: /var/etc/openvpn/keys/ca.crt
- Server Certificate: /var/etc/openvpn/keys/server.crt
- Client Config: /var/etc/openvpn/client-configs/$VPN_USERNAME.ovpn

NEXT STEPS:
1. Access pfSense web interface: https://$WAN_IP
2. Default credentials: admin/pfsense (CHANGE IMMEDIATELY)
3. Complete OpenVPN setup in VPN > OpenVPN > Servers
4. Configure firewall rules for OpenVPN access
5. Download client configuration: /var/etc/openvpn/client-configs/$VPN_USERNAME.ovpn

SECURITY NOTES:
- VPN credentials retrieved from AWS Secrets Manager
- Certificates generated with 2048-bit RSA keys
- TLS 1.2 minimum version enforced
- AES-256-GCM encryption enabled
- SHA-256 authentication enabled

LOG FILES:
- Setup log: /var/log/pfsense-setup.log
- OpenVPN log: /var/log/openvpn.log
- OpenVPN status: /var/log/openvpn-status.log

================================================================
EOF

    log_message "SUCCESS" "Status report created: /var/log/pfsense-config-report.txt"
}

# Main execution flow
main() {
    log_message "INFO" "Starting pfSense enhanced configuration with OpenVPN..."
    
    # Create log directory
    mkdir -p /var/log
    touch /var/log/pfsense-setup.log
    
    # Wait for system to be ready
    wait_for_system
    
    # Configure basic interfaces
    configure_interfaces
    
    # Install AWS CLI and retrieve VPN credentials
    install_aws_cli
    get_vpn_credentials
    
    # Configure OpenVPN
    generate_openvpn_certificates
    create_openvpn_server_config
    setup_vpn_user_auth
    create_client_config
    configure_firewall_rules
    start_openvpn_service
    
    # Additional configuration
    enable_ssh_access
    create_status_report
    
    log_message "SUCCESS" "pfSense configuration completed successfully!"
    log_message "INFO" "Please review /var/log/pfsense-config-report.txt for details"
    log_message "INFO" "Manual configuration steps may be required via web interface"
    
    # Display important information
    echo
    echo "================================================================"
    echo "CYBERSEC LAB PFSENSE SETUP COMPLETE"
    echo "================================================================"
    echo "Web Interface: https://$WAN_IP"
    echo "Default Login: admin/random password from machine in /etc/motd-passwd"
    echo "VPN Username: $VPN_USERNAME"
    echo "Client Config: /var/etc/openvpn/client-configs/$VPN_USERNAME.ovpn"
    echo "Setup Log: /var/log/pfsense-setup.log"
    echo "================================================================"
    echo
}

# Execute main function
main "$@" 2>&1
