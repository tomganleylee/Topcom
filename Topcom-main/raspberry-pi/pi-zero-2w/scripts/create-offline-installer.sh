#!/bin/bash

# Create Offline Installer for Pi Zero 2W Camera Bridge
# This script downloads all dependencies for offline installation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

echo -e "${BLUE}📦 Creating Offline Camera Bridge Installer${NC}"
echo "=============================================="

# Create offline package directory
OFFLINE_DIR="/tmp/camera-bridge-offline"
CACHE_DIR="$OFFLINE_DIR/packages"
RCLONE_DIR="$OFFLINE_DIR/rclone"

log "Creating offline package structure..."
mkdir -p "$CACHE_DIR"
mkdir -p "$RCLONE_DIR"

# Update package lists
log "Updating package lists..."
apt update

# Download all required packages with dependencies
log "Downloading packages and dependencies..."

PACKAGES=(
    "hostapd"
    "dnsmasq"
    "nginx"
    "php8.2-fpm"
    "php8.2-cli"
    "samba"
    "samba-common-bin"
    "dialog"
    "wireless-tools"
    "inotify-tools"
    "curl"
    "git"
    "net-tools"
    "htop"
    "vim"
    "rsync"
    "unzip"
    "python3"
    "python3-pip"
    "usbutils"
)

# Download packages with dependencies
cd "$CACHE_DIR"
for package in "${PACKAGES[@]}"; do
    log "Downloading $package and dependencies..."
    apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests \
        --no-conflicts --no-breaks --no-replaces --no-enhances \
        --no-pre-depends "$package" | grep "^\w" | sort -u)
done

# Download rclone binary
log "Downloading rclone..."
cd "$RCLONE_DIR"
RCLONE_VERSION="v1.64.2"
RCLONE_ARCH="linux-arm64"

wget "https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip"
unzip "rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip"
mv "rclone-${RCLONE_VERSION}-${RCLONE_ARCH}/rclone" ./
chmod +x rclone
rm -rf "rclone-${RCLONE_VERSION}-${RCLONE_ARCH}"*

# Create offline installation script
log "Creating offline installation script..."

cat > "$OFFLINE_DIR/install-offline.sh" << 'EOF'
#!/bin/bash

# Offline Camera Bridge Installation Script

set -e

GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$SCRIPT_DIR/packages"
RCLONE_DIR="$SCRIPT_DIR/rclone"

log "Installing packages from offline cache..."

# Install all cached packages
cd "$CACHE_DIR"
dpkg -i *.deb || apt-get install -f -y

log "Installing rclone..."
cp "$RCLONE_DIR/rclone" /usr/local/bin/
chmod +x /usr/local/bin/rclone

log "Offline package installation complete!"
log "Now run the main Camera Bridge installation script."
EOF

chmod +x "$OFFLINE_DIR/install-offline.sh"

# Create archive
log "Creating offline installer archive..."
cd /tmp
tar czf camera-bridge-offline-installer.tar.gz camera-bridge-offline/

# Copy to boot partition for easy access
if [ -d "/boot" ]; then
    cp camera-bridge-offline-installer.tar.gz /boot/
    log "Offline installer saved to /boot/camera-bridge-offline-installer.tar.gz"
fi

# Show instructions
echo ""
echo -e "${BLUE}🎉 Offline Installer Created!${NC}"
echo "=============================================="
echo ""
echo "USAGE:"
echo "1. Copy camera-bridge-offline-installer.tar.gz to your Pi's SD card"
echo "2. On Pi (no internet needed):"
echo "   tar xzf camera-bridge-offline-installer.tar.gz"
echo "   cd camera-bridge-offline"
echo "   sudo ./install-offline.sh"
echo "3. Then run the main Camera Bridge installation"
echo ""
echo "Archive size: $(du -h /tmp/camera-bridge-offline-installer.tar.gz | cut -f1)"
echo "Location: /boot/camera-bridge-offline-installer.tar.gz"