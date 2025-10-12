#!/bin/bash
# pfSense Initial Configuration Script

# This script runs on first boot to configure pfSense interfaces
# Note: This is a basic configuration - full pfSense setup requires manual web interface configuration

sleep 60  # Wait for system to fully boot

# Set interface assignments (this varies based on pfSense version)
# WAN = vtnet0, LAN1 = vtnet1, LAN2 = vtnet2

# Create basic interface configuration
cat > /tmp/interface_assign.txt << EOF
vtnet0
vtnet1
vtnet2
n
EOF

# Apply interface assignments (this is a simplified approach)
/etc/rc.initial.setports < /tmp/interface_assign.txt

# Basic network configuration will be completed through web interface
echo "Basic pfSense interface assignment completed"
echo "Complete configuration through web interface at https://${wan_ip}"
echo "Default credentials: admin/pfsense"
echo "WAN Interface: ${wan_ip}"
echo "LAN1 Interface: ${lan1_ip}"
echo "LAN2 Interface: ${lan2_ip}"
echo "WAN Gateway: ${wan_gw}"

# Enable SSH for remote management (optional)
echo "Enabling SSH access..."
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

# Log completion
echo "pfSense initial configuration completed at $(date)" >> /var/log/pfsense-setup.log