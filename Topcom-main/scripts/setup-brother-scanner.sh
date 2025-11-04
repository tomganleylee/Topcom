#!/bin/bash

# Brother DS-640 Scanner Setup Script
# Sets up USB scanner to auto-sync scanned documents to Dropbox

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log "Setting up Brother DS-640 Scanner..."

# ========================================
# STEP 1: Install Scanner Software
# ========================================
log "Installing SANE and Brother scanner drivers..."

apt update
apt install -y \
    sane \
    sane-utils \
    libsane-common \
    libsane1 \
    libusb-1.0-0 \
    simple-scan \
    imagemagick

# Create scanner directory inside camera-share so it auto-syncs
SCANNER_DIR="/srv/samba/camera-share/scans"
mkdir -p "$SCANNER_DIR"

# Set permissions - scanner group and camerabridge user
chown -R camerabridge:scanner "$SCANNER_DIR"
chmod 775 "$SCANNER_DIR"

# Add camerabridge to scanner group
usermod -aG scanner camerabridge

# Add camera user to scanner group (for SMB access)
if id "camera" &>/dev/null; then
    usermod -aG scanner camera
fi

log "Scanner directory created: $SCANNER_DIR"

# ========================================
# STEP 2: Download Brother Driver
# ========================================
log "Checking for Brother DS-640 driver..."

DRIVER_URL="https://download.brother.com/welcome/dlf006893/brscan-skey-0.3.2-0.amd64.deb"
DRIVER_DEB="brscan-skey-0.3.2-0.amd64.deb"
DRIVER_LIB_URL="https://download.brother.com/welcome/dlf105200/brscan4-0.4.11-1.amd64.deb"
DRIVER_LIB="brscan4-0.4.11-1.amd64.deb"

cd /tmp

# Download and install brscan4 library
if [ ! -f "/usr/lib/sane/libsane-brother4.so.1" ]; then
    log "Downloading Brother scanner library..."
    wget -q "$DRIVER_LIB_URL" -O "$DRIVER_LIB" || true
    if [ -f "$DRIVER_LIB" ]; then
        log "Installing Brother scanner library..."
        dpkg -i "$DRIVER_LIB" 2>/dev/null || apt-get install -f -y
        rm -f "$DRIVER_LIB"
    fi
fi

# Download and install scan-key-tool
if ! command -v brsaneconfig4 &> /dev/null; then
    log "Downloading Brother scan-key-tool..."
    wget -q "$DRIVER_URL" -O "$DRIVER_DEB" || true
    if [ -f "$DRIVER_DEB" ]; then
        log "Installing Brother scan-key-tool..."
        dpkg -i "$DRIVER_DEB" 2>/dev/null || apt-get install -f -y
        rm -f "$DRIVER_DEB"
    fi
fi

# ========================================
# STEP 3: Configure Scanner
# ========================================
log "Configuring Brother DS-640..."

# Create udev rule for scanner permissions
cat > /etc/udev/rules.d/79-brother-scanner.rules << 'EOF'
# Brother DS-640 Scanner
SUBSYSTEMS=="usb", ATTRS{idVendor}=="04f9", ATTRS{idProduct}=="60e0", MODE="0666", GROUP="scanner"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="04f9", ATTRS{idProduct}=="60e1", MODE="0666", GROUP="scanner"
EOF

udevadm control --reload-rules
udevadm trigger

# Configure default scan directory
if [ -f /opt/brother/scanner/brscan-skey/brscan-skey.config ]; then
    sed -i "s|SCAN_TO_DIR=.*|SCAN_TO_DIR=\"$SCANNER_DIR\"|" /opt/brother/scanner/brscan-skey/brscan-skey.config
fi

# ========================================
# STEP 4: Create Scan Script
# ========================================
log "Creating automated scan processing script..."

cat > /usr/local/bin/brother-scan-to-dropbox << 'SCANEOF'
#!/bin/bash

# Brother Scanner to Dropbox Script
# Called when scan button is pressed
# Saves to camera-share/scans so it auto-syncs via camera-bridge

SCAN_DIR="/srv/samba/camera-share/scans"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
FILENAME="scan_${TIMESTAMP}"

# Ensure directory exists
mkdir -p "$SCAN_DIR"

# Scan to file (detect device automatically)
scanimage --device-name="brother4:bus2;dev1" \
    --format=jpeg \
    --resolution=300 \
    --mode=Color \
    > "$SCAN_DIR/${FILENAME}.jpg" 2>&1

if [ $? -eq 0 ]; then
    chmod 664 "$SCAN_DIR/${FILENAME}.jpg"
    chown camerabridge:scanner "$SCAN_DIR/${FILENAME}.jpg"
    echo "Scan saved: ${FILENAME}.jpg"
    logger -t brother-scanner "Scan completed: ${FILENAME}.jpg - will auto-sync to Dropbox"
else
    echo "Scan failed"
    logger -t brother-scanner "Scan failed"
fi
SCANEOF

chmod +x /usr/local/bin/brother-scan-to-dropbox

# ========================================
# STEP 5: Scanner shares via existing camera-share
# ========================================
log "Scanner will save to camera-share/scans/ subdirectory"
log "Scans will automatically sync to Dropbox via camera-bridge service"

# ========================================
# FINAL STATUS
# ========================================
echo ""
echo "======================================"
echo "Brother DS-640 Scanner Setup Complete"
echo "======================================"
echo ""
echo "Scanner Directory: $SCANNER_DIR"
echo "SMB Share: \\\\[server-ip]\\camera-share\\scans"
echo ""
echo "Setup Instructions:"
echo "1. Connect Brother DS-640 via USB"
echo "2. Verify detection: lsusb | grep Brother"
echo "3. Configure scanner: sudo brsaneconfig4 -a name=DS640 model=DS-640"
echo "4. Test scan: scanimage --test"
echo "5. Test actual scan: scanimage --format=jpeg > /tmp/test-scan.jpg"
echo ""
echo "How it works:"
echo "- Scans are saved to: $SCANNER_DIR"
echo "- This is inside camera-share, so camera-bridge monitors it automatically"
echo "- New scans will auto-sync to Dropbox within seconds"
echo "- Access scans via SMB: \\\\[server-ip]\\camera-share\\scans"
echo ""
echo "======================================"
