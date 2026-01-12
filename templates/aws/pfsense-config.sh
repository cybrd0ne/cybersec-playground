#!/bin/sh
echo "8" 

set -e

PUBLIC_IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")"
WAN_IP="${wan_ip}"
LAN1_IP="${lan1_ip}"
LAN2_IP="${lan2_ip}"
WAN_GW="${wan_gw}"
VPN_SECRET_ARN="${vpn_secret_arn}"
VPN_USERNAME="${vpn_username}"
VPN_PASSWORD="THIS IS NOT THE PASSW0RD!JUST GLOBAL VAR;)"
VPN_PORT="${vpn_port}"
VPN_PROTOCOL="${vpn_protocol}"
AWS_REGION="${aws_region}"
FQDN="${lab_fqdn}"
PYTHON_BIN="python3.11"

log_message() {
  level="$1"
  shift
  message="$*"
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  case "$level" in
    INFO)    echo -e "[INFO] $timestamp - $message" | tee -a /var/log/pfsense-setup.log ;;
    SUCCESS) echo -e "[SUCCESS] $timestamp - $message" | tee -a /var/log/pfsense-setup.log ;;
    WARNING) echo -e "[WARNING] $timestamp - $message" | tee -a /var/log/pfsense-setup.log ;;
    ERROR)   echo -e "[ERROR] $timestamp - $message" | tee -a /var/log/pfsense-setup.log ;;
  esac
}

wait_for_system() {
  log_message INFO "Waiting for pfSense system to fully initialize..."
  sleep 10
  attempts=0
  max_attempts=30
  while [ $attempts -lt $max_attempts ]; do
    if curl -k -s --connect-timeout 5 https://localhost >/dev/null 2>&1; then
      log_message SUCCESS "pfSense web interface is ready"
      break
    fi
    log_message INFO "Waiting for pfSense web interface... (attempt $((attempts + 1))/$max_attempts)"
    sleep 10
    attempts=$((attempts + 1))
  done
  if [ $attempts -eq $max_attempts ]; then
    log_message WARNING "pfSense web interface not ready, continuing anyway"
  fi
}

configure_interfaces() {
  log_message INFO "Configuring pfSense interfaces..."

cat >/tmp/interface_assign.txt << EOF
n
ena0
ena1
ena2
y
EOF
  /etc/rc.initial.setports < /tmp/interface_assign.txt >/dev/null 2>&1 || true

cat >/tmp/interface_lan.txt << EOF
2
n
10.0.2.10/24

n

n
n
EOF
  /etc/rc.initial.setlanip < /tmp/interface_lan.txt >/dev/null 2>&1 || true
  
cat >/tmp/interface_opt1.txt << EOF
3
n
10.0.3.10/24

n

n
n
EOF
  /etc/rc.initial.setlanip < /tmp/interface_opt1.txt >/dev/null 2>&1 || true
  
  log_message INFO "Interface assignments completed"
  log_message INFO "WAN Interface: $WAN_IP"
  log_message INFO "LAN1 Interface: $LAN1_IP (JuiceShop Network)"
  log_message INFO "LAN2 Interface: $LAN2_IP (Windows AD Network)"
  log_message INFO "WAN Gateway: $WAN_GW"
}

check_python_and_install() {
  if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_BIN=python3.12
  elif command -v python3.11 >/dev/null 2>&1; then
    PYTHON_BIN=python3.11

    # Check if pip is installed for this Python
    if ! $PYTHON_BIN -m pip --version >/dev/null 2>&1; then
      log_message INFO "pip not found for $PYTHON_BIN, installing pip..."
      curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
      $PYTHON_BIN /tmp/get-pip.py
      rm /tmp/get-pip.py
      log_message SUCCESS "pip installed for $PYTHON_BIN"
    fi

  elif command -v python3.8 >/dev/null 2>&1; then
    PYTHON_BIN=python3.8

    if ! $PYTHON_BIN -m pip --version >/dev/null 2>&1; then
      log_message INFO "pip not found for $PYTHON_BIN, installing pip..."
      curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
      $PYTHON_BIN /tmp/get-pip.py
      rm /tmp/get-pip.py
      log_message SUCCESS "pip installed for $PYTHON_BIN}"
    fi

  else
    log_message INFO "Python 3.8, 3.11, or 3.12 not found. Installing python3 package."
    pkg install -y python3
    PYTHON_BIN=python3

    if ! $PYTHON_BIN -m pip --version >/dev/null 2>&1; then
      log_message INFO "pip not found for $PYTHON_BIN, installing pip..."
      curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
      $PYTHON_BIN /tmp/get-pip.py
      rm /tmp/get-pip.py
      log_message SUCCESS "pip installed for $PYTHON_BIN"
    fi
  fi

  log_message INFO "Using Python interpreter: $PYTHON_BIN}"
}

install_awscli() {
  log_message INFO "Checking if AWS CLI is installed..."
  if ! command -v aws >/dev/null 2>&1; then
    log_message INFO "AWS CLI not found. Installing..."
    check_python_and_install
    $PYTHON_BIN -m pip install awscli
    ln -sf /usr/local/bin/aws /usr/bin/aws || true
    log_message SUCCESS "AWS CLI installed successfully"
  else
    log_message INFO "AWS CLI already installed."
  fi
}

get_vpn_credentials() {
  if [ -z "$VPN_SECRET_ARN" ]; then
    log_message ERROR "VPN_SECRET_ARN is empty. Cannot retrieve VPN credentials."
    exit 1
  fi

  install_awscli

  log_message INFO "Retrieving VPN credentials from AWS Secrets Manager..."

  token=$(curl -s -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" http://169.254.169.254/latest/api/token 2>/dev/null || echo "")
  if [ -n "$token" ]; then
    role_name=$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
    if [ -n "$role_name" ]; then
      creds=$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/iam/security-credentials/$role_name 2>/dev/null)
      export AWS_ACCESS_KEY_ID=$(echo "$creds" | $PYTHON_BIN -c 'import sys,json; print(json.load(sys.stdin)["AccessKeyId"])')
      export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | $PYTHON_BIN -c 'import sys,json; print(json.load(sys.stdin)["SecretAccessKey"])')
      export AWS_SESSION_TOKEN=$(echo "$creds" | $PYTHON_BIN -c 'import sys,json; print(json.load(sys.stdin)["Token"])')
    fi
  fi

  secret_json=$(aws secretsmanager get-secret-value --secret-id "$VPN_SECRET_ARN" --region "$AWS_REGION" --output text --query 'SecretString' 2>/dev/null || echo "{}")
  VPN_USERNAME=$(echo "$secret_json" | $PYTHON_BIN -c 'import sys,json; print(json.load(sys.stdin).get("username", "vpnuser"))')
  VPN_PASSWORD=$(echo "$secret_json" | $PYTHON_BIN -c 'import sys,json; print(json.load(sys.stdin).get("password", "CyberSecVPN$(openssl rand -base64 8 | tr -d '=+/' | cut -c1-6)!"))')

  if [ -n "$VPN_PASSWORD" ]; then
    log_message SUCCESS "VPN credentials retrieved successfully"
  else
    log_message WARNING "Failed to retrieve VPN credentials, using default"
    VPN_USERNAME="vpnuser"
    VPN_PASSWORD="CyberSecVPN$(openssl rand -base64 8 | tr -d '=+/' | cut -c1-6)!"
  fi
}

generate_openvpn_certificates() {
  log_message INFO "Generating OpenVPN certificates..."

  mkdir -p /usr/local/etc/openvpn/keys
  cd /usr/local/etc/openvpn/keys || exit
  cat >/usr/local/etc/openvpn/keys/openssl.cnf << EOF
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
countryName = RO
stateOrProvinceName = Sibiu
localityName = Sibiu
organizationName = CybersecurityLabs
commonName = $FQDN

[ v3_req ]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
IP.1 = $PUBLIC_IP
DNS.1 = $FQDN
EOF

  openssl genrsa -out ca.key 2048
  openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/C=US/ST=Lab/L=CyberSec/O=CyberSecLab/OU=IT/CN=CyberSec-CA"

  openssl genrsa -out server.key 2048
  openssl req -new -key server.key -out server.csr -config ./openssl.cnf
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extfile ./openssl.cnf -extensions v3_req

  openssl genrsa -out client.key 2048
  openssl req -new -key client.key -out client.csr -subj "/C=US/ST=Lab/L=CyberSec/O=CyberSecLab/OU=IT/CN=$VPN_USERNAME"
  openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt

  openssl dhparam -out dh2048.pem 2048
  openvpn --genkey secret ta.key

  chmod 600 *.key
  chmod 644 *.crt *.pem

  log_message SUCCESS "OpenVPN certificates generated"

cat << 'EOFCERT' | pfSsh.php
require_once("config.inc");
parse_config(true);
global $config;

// Import CA
$ca = array();
$ca['refid'] = uniqid();
$ca['descr'] = 'CyberSec-CA';
$ca['crt'] = base64_encode(file_get_contents('/usr/local/etc/openvpn/keys/ca.crt'));
$config['ca'][] = $ca;

// Import Server Certificate
$cert = array();
$cert['refid'] = uniqid();
$cert['descr'] = 'OpenVPN Server Certificate';
$cert['caref'] = $ca['refid'];
$cert['crt'] = base64_encode(file_get_contents('/usr/local/etc/openvpn/keys/server.crt'));
$cert['prv'] = base64_encode(file_get_contents('/usr/local/etc/openvpn/keys/server.key'));
$config['cert'][] = $cert;

write_config("Imported OpenVPN certificates");
exit(0);
exec
EOFCERT

}

create_openvpn_server_config() {
  log_message INFO "Creating OpenVPN server configuration..."

TLS_KEY_PATH="/usr/local/etc/openvpn/keys/ta.key"
TLS_KEY_B64=""
if [ -f "$TLS_KEY_PATH" ]; then
  TLS_KEY_B64=$(base64 < "$TLS_KEY_PATH" | tr -d '\n')
  HAS_TLS_KEY="yes"
else
  TLS_KEY_B64=""
  HAS_TLS_KEY="no"
fi

# Create the PHP configuration script
cat << EOFPHP | pfSsh.php
require_once("config.inc");
require_once("auth.inc");
require_once("openvpn.inc");

// Parse existing configuration
parse_config(true);
global \$config;

// Initialize OpenVPN config arrays if not exists
if (!is_array(\$config['openvpn'])) {
    \$config['openvpn'] = array();
}
if (!is_array(\$config['openvpn']['openvpn-server'])) {
    \$config['openvpn']['openvpn-server'] = array();
}

// Check if CA and certificates exist, create references
\$ca_refid = null;
\$cert_refid = null;

// Find or create CA reference
if (is_array(\$config['ca'])) {
    foreach (\$config['ca'] as \$ca) {
        if (\$ca['descr'] == 'CyberSec-CA') {
            \$ca_refid = \$ca['refid'];
            break;
        }
    }
}

// Find or create Server certificate reference
if (is_array(\$config['cert'])) {
    foreach (\$config['cert'] as \$cert) {
        if (\$cert['descr'] == 'OpenVPN Server Certificate') {
            \$cert_refid = \$cert['refid'];
            break;
        }
    }
}

// If CA or cert not found, use existing ones or create placeholders
if (!\$ca_refid && is_array(\$config['ca']) && count(\$config['ca']) > 0) {
    \$ca_refid = \$config['ca'][0]['refid'];
}
if (!\$cert_refid && is_array(\$config['cert']) && count(\$config['cert']) > 0) {
    \$cert_refid = \$config['cert'][0]['refid'];
}

// Generate next VPN ID
\$vpnid = openvpn_vpnid_next();

// Build OpenVPN server configuration
\$server_config = array();
\$server_config['vpnid'] = \$vpnid;
\$server_config['mode'] = 'server_user';  // Remote Access (User Auth)
\$server_config['authmode'] = 'Local Database';
\$server_config['protocol'] = 'UDP4';
\$server_config['dev_mode'] = 'tun';
\$server_config['interface'] = 'wan';
\$server_config['local_port'] = '$VPN_PORT';
\$server_config['description'] = 'OpenVPN Remote Access Server';

// Crypto settings matching your config
\$server_config['data_ciphers'] = 'AES-256-GCM';
\$server_config['data_ciphers_fallback'] = 'AES-256-CBC';  // For older clients
\$server_config['digest'] = 'SHA256';        // auth SHA256
\$server_config['ncp_enable'] = 'yes';  // Enable NCP (negotiable crypto parameters)

if ("$HAS_TLS_KEY" === "yes" && !empty("$TLS_KEY_B64")) {
    \$server_config['tls'] = "$TLS_KEY_B64";
    \$server_config['tls_type'] = 'auth'; // use 'crypt' for tls-crypt if that's what you want
    \$server_config['tls_authmode'] = 'tls';
} else {
    \$server_config['tls'] = '';
    \$server_config['tls_type'] = '';
}
\$server_config['remote-cert-tls'] = 'client';

// DH parameters
\$server_config['dh_length'] = '2048';       // dh2048.pem

// TLS version
\$server_config['tls_version_min'] = '1.2';  // tls-version-min 1.2

// Tunnel network
\$server_config['tunnel_network'] = '10.8.0.0/24';  // server 10.8.0.0 255.255.255.0

// Push routes to clients
\$server_config['local_network'] = '10.0.1.0/24,10.0.2.0/24,10.0.3.0/24';

// Note: compression is deprecated in OpenVPN 2.5+
\$server_config['compression'] = '';  // Empty = no compression
\$server_config['compression_push'] = 'no';

// Client settings
\$server_config['maxclients'] = '2';        // max-clients 2
//\$server_config['duplicate_cn'] = 'yes';     // duplicate-cn

// Keepalive
\$server_config['keepalive_interval'] = '10';   // keepalive 10 120
\$server_config['keepalive_timeout'] = '120';

// Persistence
\$server_config['persist_key'] = 'yes';      // persist-key
\$server_config['persist_tun'] = 'yes';      // persist-tun

// Logging
\$server_config['verbosity_level'] = '3';    // verb 3

// Certificate references
if (\$ca_refid) {
    \$server_config['caref'] = \$ca_refid;
}
if (\$cert_refid) {
    \$server_config['certref'] = \$cert_refid;
}

// Custom options for features not directly supported
\$custom_options = array();
\$custom_options[] = 'push "dhcp-option DOMAIN cybersec.local"';
\$server_config['custom_options'] = implode("\\\n", \$custom_options);

// Add server to configuration
\$config['openvpn']['openvpn-server'][] = \$server_config;

// Write configuration
write_config("OpenVPN server configured via CLI script");

// Restart OpenVPN to apply changes
openvpn_resync_all();

echo "OpenVPN server configuration completed successfully$nl";
exit(0);
exec
EOFPHP

if [ $? -eq 0 ]; then
    log_message "OpenVPN configuration applied successfully"
else
    log_message "ERROR: Failed to apply OpenVPN configuration"
    exit 1
fi

# Assign OpenVPN interface so it can be used with easyrule
log_message "Assigning OpenVPN interface..."

cat << 'EOFPHP2' | pfSsh.php
require_once("config.inc");
require_once("interfaces.inc");

parse_config(true);
global $config;

// Find the next available OPT interface slot
$optid = 1;
while (isset($config['interfaces']['opt' . $optid])) {
    $optid++;
}

$opt_name = 'opt' . $optid;
$if_name = 'ovpns1';  // OpenVPN server 1 interface

// Assign interface
$config['interfaces'][$opt_name] = array();
$config['interfaces'][$opt_name]['descr'] = 'OpenVPN';
$config['interfaces'][$opt_name]['if'] = $if_name;
$config['interfaces'][$opt_name]['enable'] = true;

write_config("Assigned OpenVPN interface as " . strtoupper($opt_name));

// Reload interfaces
interfaces_configure();

echo "OpenVPN interface assigned as " . strtoupper($opt_name) . "\n";
exit(0);
exec
EOFPHP2

if [ $? -eq 0 ]; then
    log_message "OpenVPN interface assigned successfully"
else
    log_message "WARNING: Failed to assign OpenVPN interface"
fi

# Add firewall rules using easyrule
log_message "Adding firewall rules for OpenVPN..."

# Allow OpenVPN on WAN
easyrule pass wan udp any any 1194
log_message "Added WAN rule to allow OpenVPN UDP 1194"

log_message "OpenVPN configuration completed successfully"
log_message "Configuration log available at: $LOG_FILE"

echo ""
echo "============================================"
echo "OpenVPN Configuration Summary"
echo "============================================"
echo "Server IP Range: 10.8.0.0/24"
echo "Port: 1194 UDP"
echo "Cipher: AES-256-GCM"
echo "Auth: SHA256"
echo "Max Clients: 10"
echo "Pushed Routes: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24"
echo ""
echo "To verify OpenVPN status:"
echo "  - Check logs: tail -f /var/log/openvpn.log"
echo "  - Check status: cat /var/log/openvpn-status.log"
echo "  - Service status: service openvpn status"
echo "============================================"


}

setup_vpn_user_auth() {
  log_message INFO "Setting up VPN user authentication..."

cat << EOFPHP | pfSsh.php
require_once("config.inc");
require_once("auth.inc");

parse_config(true);
global \$config;

// Create a SHA512 password hash (pfSense expects encrypted password)
\$user_entry = array();
\$user_entry['name'] = '$VPN_USERNAME';
\$user_entry['password'] = password_hash('$VPN_PASSWORD', PASSWORD_BCRYPT);
\$user_entry['descr'] = 'OpenVPN local user via pfSsh.php during bootstrap';
\$user_entry['priv'] = array(); // Add privileges as needed
\$user_entry['expires'] = '';
\$user_entry['disabled'] = false;
\$user_entry['scope'] = 'system';
\$user_entry['realname'] = 'OpenVPN';

if (!isset(\$config['system']['user'])) {
    \$config['system']['user'] = array();
}
\$config['system']['user'][] = \$user_entry;

// Write changes to config
write_config("Added OpenVPN user $VPN_USERNAME via pfSsh.php");

echo "User '$VPN_USERNAME' created successfully for OpenVPN\n";
exit(0);
exec
EOFPHP

  log_message SUCCESS "VPN user authentication configured"
}

create_client_config() {
  log_message INFO "Creating OpenVPN client configuration..."

  mkdir -p /usr/local/etc/openvpn/client-configs

  cat >/usr/local/etc/openvpn/client-configs/$VPN_USERNAME.ovpn << EOF
client
dev tun
proto $VPN_PROTOCOL
remote $PUBLIC_IP $VPN_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
mute 20

auth-user-pass

<ca>
$(cat /usr/local/etc/openvpn/keys/ca.crt)
</ca>

<tls-auth>
$(cat /usr/local/etc/openvpn/keys/ta.key)
</tls-auth>
key-direction 1

script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf
EOF

  cat >/usr/local/etc/openvpn/client-configs/$VPN_USERNAME-credentials.txt << EOF
$VPN_USERNAME
$VPN_PASSWORD
EOF

  chmod 600 /usr/local/etc/openvpn/client-configs/*

  log_message SUCCESS "Client configuration created"
}


configure_firewall_rules() {
  # Easyrule syntax: easyrule pass <interface> <protocol> <source> <destination> [port]

  INTERFACE="wan"
  PROTOCOL="$VPN_PROTOCOL"  # e.g., udp
  SRC="any"
  DST="$WAN_IP"
  PORT="$VPN_PORT"          # e.g., 1194

  log_message INFO "Adding firewall rule to allow OpenVPN on WAN interface via easyrule..."

  # Check if rule already exists to avoid duplicates
  if easyrule showblock $INTERFACE | grep -q "$PORT"; then
    log_message INFO "OpenVPN firewall rule on $INTERFACE port $PORT already exists"
  else
    # Add pass rule for OpenVPN (precise matching)
    easyrule pass $INTERFACE $PROTOCOL $SRC $DST $PORT
    log_message SUCCESS "OpenVPN firewall rule added on $INTERFACE port $PORT"
  fi
  easyrule pass lan tcp 10.0.2.0/24 any any
  easyrule pass lan udp 10.0.2.0/24 any any
  easyrule pass opt1 tcp 10.0.3.0/24 any any
  easyrule pass opt1 udp 10.0.3.0/24 any any
  easyrule pass ovpns1 tcp 10.8.0.0/24 10.0.2.20 any
 }

create_status_report() {
  log_message INFO "Creating configuration status report..."

  cat >/var/log/pfsense-config-report.txt << EOF
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

  log_message SUCCESS "Status report created: /var/log/pfsense-config-report.txt"
}

main() {
  log_message INFO "Starting pfSense enhanced configuration with OpenVPN and AWS Secrets Manager VPN credentials..."

  mkdir -p /var/log
  touch /var/log/pfsense-setup.log

  wait_for_system
  configure_interfaces
  get_vpn_credentials
  generate_openvpn_certificates
  create_openvpn_server_config
  setup_vpn_user_auth
  create_client_config
  configure_firewall_rules
  create_status_report

  log_message SUCCESS "pfSense configuration completed successfully!"
  log_message INFO "Please review /var/log/pfsense-config-report.txt for details"
  log_message INFO "Manual configuration steps may be required via web interface"

  echo
  echo "================================================================"
  echo "CYBERSEC LAB PFSENSE SETUP COMPLETE"
  echo "================================================================"
  echo "Web Interface: https://$WAN_IP"
  echo "Default Login: admin/pfsense password via shell in /etc/motd-passwd"
  echo "VPN Username: $VPN_USERNAME"
  echo "Client Config: /usr/local/etc/openvpn/client-configs/$VPN_USERNAME.ovpn"
  echo "Setup Log: /var/log/pfsense-setup.log"
  echo "================================================================"
  echo
}

main "$@" 2>&1

