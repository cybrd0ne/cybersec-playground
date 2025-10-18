#!/bin/bash
# JuiceShop Setup Script for Amazon Linux 2023

# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Configure network route through pfSense (if needed)
# Note: AWS handles routing through ENI attachments, but this can be used for troubleshooting
echo "Configuring network settings..."
sudo route add default gw ${pfsense_ip} metric 100 2>/dev/null || true

# Wait for Docker to be ready
sleep 10

# Pull and run JuiceShop container
echo "Downloading OWASP JuiceShop Docker image..."
sudo docker pull bkimminich/juice-shop:latest

# Run JuiceShop container with restart policy
echo "Starting JuiceShop application..."
sudo docker run -d \
  --name juice-shop \
  --restart unless-stopped \
  -p 3000:3000 \
  bkimminich/juice-shop:latest

# Create systemd service for JuiceShop to ensure it starts on boot
sudo tee /etc/systemd/system/juiceshop.service > /dev/null <<EOF
[Unit]
Description=OWASP Juice Shop Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start juice-shop
ExecStop=/usr/bin/docker stop juice-shop
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable juiceshop.service

# Install useful tools for penetration testing
echo "Installing security tools..."
sudo yum install -y nmap wget curl tcpdump net-tools

# Configure logging
sudo mkdir -p /var/log/juiceshop
echo "JuiceShop deployment completed at $(date)" | sudo tee /var/log/juiceshop/deploy.log

# Check if JuiceShop is running
sleep 5
if sudo docker ps | grep -q juice-shop; then
    echo "JuiceShop is running successfully!"
    echo "Access it at http://10.0.2.20:3000"
else
    echo "Warning: JuiceShop may not be running properly"
    sudo docker logs juice-shop
fi

echo "JuiceShop setup completed successfully!"
echo "Access the application through pfSense port forwarding"
