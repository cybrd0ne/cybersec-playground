MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="===============BOUNDARY=="

--===============BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.yaml"

#cloud-config

package_update: true
package_upgrade: true

packages:
  - docker

runcmd:
  - [ systemctl, daemon-reload ]
  - [ systemctl, enable, docker.service ]
  - [ systemctl, start, --no-block, docker.service ]

--===============BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="juiceshop-setup.sh"

#!/bin/bash
sleep 10
# JuiceShop Setup Script for Amazon Linux 2023
sudo ip ro del default via 10.0.2.1
sudo ip ro add default via ${pfsense_ip}
sudo usermod -a -G docker ec2-user
sudo systemctl start docker.service
sudo mkdir -p /var/log/juiceshop
# Pull and run JuiceShop container
echo "Downloading OWASP JuiceShop Docker image..."
sudo docker pull bkimminich/juice-shop:latest 2>&1 | sudo tee -a /var/log/juiceshop/deploy.log

# Run JuiceShop container with restart policy
echo "Starting JuiceShop application..."
sudo docker run -d --name juice-shop --restart unless-stopped -p 3000:3000 bkimminich/juice-shop:latest 2>&1 | sudo tee -a /var/log/juiceshop/deploy.log

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

# Configure logging
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

--===============BOUNDARY==--
