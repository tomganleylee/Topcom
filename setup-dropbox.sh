#!/bin/bash

# Quick Dropbox setup script for camera-bridge

echo "📦 Camera Bridge - Dropbox Configuration"
echo "========================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    error "rclone is not installed. Please run install-packages.sh first"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Check for camerabridge user
if ! id "camerabridge" &>/dev/null; then
    error "camerabridge user doesn't exist. Run install-packages.sh first"
    exit 1
fi

echo "This script will help you configure Dropbox access for Camera Bridge."
echo ""
echo "You have two options:"
echo "1. Use existing Dropbox token (if you have one)"
echo "2. Generate a new Dropbox token through browser authentication"
echo ""

read -p "Do you have an existing Dropbox refresh token? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please enter your Dropbox configuration details:"
    read -p "Dropbox App Client ID: " client_id
    read -p "Dropbox App Client Secret: " client_secret
    read -p "Dropbox Refresh Token: " refresh_token

    # Create rclone configuration
    log "Creating rclone configuration..."
    mkdir -p /home/camerabridge/.config/rclone

    cat > /home/camerabridge/.config/rclone/rclone.conf << EOF
[dropbox]
type = dropbox
client_id = ${client_id}
client_secret = ${client_secret}
token = {"access_token":"","token_type":"bearer","refresh_token":"${refresh_token}","expiry":"2024-01-01T00:00:00.000000000Z"}
EOF

    chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
    chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    log "Testing Dropbox connection..."
    if sudo -u camerabridge rclone lsd dropbox: &>/dev/null; then
        log "✓ Dropbox configuration successful!"
    else
        error "Failed to connect to Dropbox. Please check your credentials."
        exit 1
    fi
else
    echo ""
    echo "Starting interactive Dropbox setup..."
    echo ""
    warn "Note: This will open a browser for authentication"
    echo ""

    # Run rclone config as camerabridge user
    sudo -u camerabridge rclone config create dropbox dropbox

    # Test the configuration
    log "Testing Dropbox connection..."
    if sudo -u camerabridge rclone lsd dropbox: &>/dev/null; then
        log "✓ Dropbox configuration successful!"
    else
        error "Failed to connect to Dropbox. Please try again."
        exit 1
    fi
fi

echo ""
echo "========================================"
echo "✅ DROPBOX SETUP COMPLETE!"
echo "========================================"
echo ""
echo "Dropbox is now configured for Camera Bridge."
echo ""
echo "Next steps:"
echo "1. Start the camera-bridge service:"
echo "   sudo systemctl start camera-bridge"
echo ""
echo "2. Test file sync:"
echo "   echo 'test' > /srv/samba/camera-share/test.txt"
echo "   sudo -u camerabridge rclone ls dropbox:Camera-Photos/"
echo ""
echo "3. Monitor the service:"
echo "   sudo journalctl -u camera-bridge -f"
echo ""