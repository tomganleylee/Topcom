#!/bin/bash

# Dropbox Token Configuration Script

echo "📦 Dropbox Configuration for Camera Bridge"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Check for camerabridge user
if ! id "camerabridge" &>/dev/null; then
    echo "Error: camerabridge user doesn't exist. Run install-complete.sh first"
    exit 1
fi

echo "Enter your Dropbox Access Token:"
echo "(Get this from Dropbox App Console or use OAuth flow)"
echo ""
read -p "Access Token: " access_token

if [ -z "$access_token" ]; then
    echo "Error: Access token cannot be empty"
    exit 1
fi

# Create rclone configuration
mkdir -p /home/camerabridge/.config/rclone

cat > /home/camerabridge/.config/rclone/rclone.conf << EOF
[dropbox]
type = dropbox
token = {"access_token":"${access_token}","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
EOF

# Set permissions
chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
chmod 600 /home/camerabridge/.config/rclone/rclone.conf

echo ""
echo "Testing Dropbox connection..."

if sudo -u camerabridge rclone lsd dropbox: 2>/dev/null; then
    echo "✅ Dropbox configuration successful!"

    # Create Camera-Photos folder
    sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null

    # Start the service
    systemctl start camera-bridge
    systemctl enable camera-bridge

    echo ""
    echo "✅ Camera Bridge service started!"
    echo ""
    echo "Your system is now ready:"
    echo "1. Connect devices to ethernet (DHCP: 192.168.10.x)"
    echo "2. Access SMB: \\\\192.168.10.1\\photos"
    echo "3. Photos sync automatically to Dropbox"
    echo ""
    echo "Monitor: sudo journalctl -u camera-bridge -f"
else
    echo "❌ Failed to connect to Dropbox"
    echo "Please check your access token and try again"
    exit 1
fi