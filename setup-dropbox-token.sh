#!/bin/bash

# Quick Dropbox setup using access token

echo "📦 Setting up Dropbox with Access Token"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Check for camerabridge user
if ! id "camerabridge" &>/dev/null; then
    echo "Creating camerabridge user..."
    useradd -m -s /bin/bash camerabridge
fi

echo "Enter your Dropbox Access Token:"
echo "(You mentioned you already have one from the enhanced UI)"
read -p "Access Token: " access_token

if [ -z "$access_token" ]; then
    echo "Error: Access token cannot be empty"
    exit 1
fi

# Create rclone configuration directory
mkdir -p /home/camerabridge/.config/rclone

# Create rclone configuration with the access token
cat > /home/camerabridge/.config/rclone/rclone.conf << EOF
[dropbox]
type = dropbox
token = {"access_token":"${access_token}","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
EOF

# Set correct permissions
chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
chmod 600 /home/camerabridge/.config/rclone/rclone.conf

echo ""
echo "Testing Dropbox connection..."

# Test the connection
if sudo -u camerabridge rclone lsd dropbox: 2>/dev/null; then
    echo "✅ Dropbox configuration successful!"
    echo ""

    # Create Camera-Photos folder if it doesn't exist
    sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null

    echo "Ready to sync photos to Dropbox:Camera-Photos/"
    echo ""
    echo "Next steps:"
    echo "1. Install camera-bridge service:"
    echo "   sudo ./scripts/install-packages.sh"
    echo ""
    echo "2. Start the service:"
    echo "   sudo systemctl start camera-bridge"
    echo ""
    echo "3. Test file sync:"
    echo "   touch /srv/samba/camera-share/test.jpg"
    echo "   sudo journalctl -u camera-bridge -f"
else
    echo "❌ Failed to connect to Dropbox"
    echo "Please check your access token and try again"
    exit 1
fi