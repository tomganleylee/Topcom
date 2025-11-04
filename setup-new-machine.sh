#!/bin/bash

# Camera Bridge - Complete Setup Script for New Machines
# Interactively installs camera bridge with optional WiFi hotspot and scanner support

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

title() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

clear
title "Camera Bridge - New Machine Setup"
echo ""
echo "This script will set up the Camera Bridge system on this machine."
echo "You can choose which features to install:"
echo ""
echo "  ✓ Camera Bridge Service (required)"
echo "  ○ WiFi Hotspot (optional - requires USB WiFi adapter)"
echo "  ○ Brother Scanner Support (optional - requires scanner)"
echo ""
read -p "Press Enter to continue..."
echo ""

# ========================================
# STEP 1: Camera Bridge Base System
# ========================================
title "Step 1: Installing Camera Bridge Base System"
echo ""
log "Installing camera bridge service..."

if [ -f "Topcom-main/scripts/install-complete.sh" ]; then
    bash Topcom-main/scripts/install-complete.sh
else
    error "install-complete.sh not found. Are you in /opt/camera-bridge?"
    exit 1
fi

log "Camera bridge base system installed"
echo ""

# ========================================
# STEP 2: WiFi Hotspot (Optional)
# ========================================
title "Step 2: WiFi Hotspot Setup (Optional)"
echo ""
echo "Do you want to install WiFi hotspot functionality?"
echo "This creates a WiFi access point that devices can connect to."
echo ""
echo "Requirements:"
echo "  - USB WiFi adapter (TP-Link AC600 or compatible)"
echo "  - Adapter must support AP mode"
echo ""
read -p "Install WiFi hotspot? (y/N): " install_wifi

if [[ "$install_wifi" =~ ^[Yy]$ ]]; then
    log "Installing WiFi hotspot..."

    if [ -f "Topcom-main/scripts/setup-wifi-hotspot.sh" ]; then
        bash Topcom-main/scripts/setup-wifi-hotspot.sh
        log "WiFi hotspot installed"
    else
        warn "WiFi hotspot script not found, skipping"
    fi
else
    log "Skipping WiFi hotspot installation"
fi
echo ""

# ========================================
# STEP 3: Scanner Support (Optional)
# ========================================
title "Step 3: Brother Scanner Support (Optional)"
echo ""
echo "Do you want to install Brother scanner support?"
echo "This allows scanning documents that auto-sync to Dropbox."
echo ""
echo "Requirements:"
echo "  - Brother scanner (USB or network)"
echo "  - Scanner model: DS-640 or similar"
echo ""
read -p "Install scanner support? (y/N): " install_scanner

if [[ "$install_scanner" =~ ^[Yy]$ ]]; then
    log "Installing scanner support..."

    if [ -f "Topcom-main/scripts/setup-brother-scanner.sh" ]; then
        bash Topcom-main/scripts/setup-brother-scanner.sh

        # Create quick scan command
        log "Creating 'scan' command..."
        cat > /usr/local/bin/scan << 'SCANEOF'
#!/bin/bash

SCAN_DIR="/srv/samba/camera-share/scans"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
FILENAME="scan_${TIMESTAMP}.jpg"

echo "Scanning..."
scanimage --format=jpeg --resolution=300 --mode=Color > "$SCAN_DIR/$FILENAME" 2>/dev/null

if [ $? -eq 0 ]; then
    chmod 664 "$SCAN_DIR/$FILENAME"
    chown camerabridge:scanner "$SCAN_DIR/$FILENAME" 2>/dev/null || true
    echo "✓ Scan saved: $FILENAME"
    echo "  Location: $SCAN_DIR/$FILENAME"
    echo "  Will auto-sync to Dropbox in a few seconds..."
else
    echo "✗ Scan failed - is scanner connected?"
    exit 1
fi
SCANEOF

        chmod +x /usr/local/bin/scan
        log "Scanner support installed"
        log "Use 'scan' command to scan documents"
    else
        warn "Scanner setup script not found, skipping"
    fi
else
    log "Skipping scanner installation"
fi
echo ""

# ========================================
# STEP 4: Enable Services on Boot
# ========================================
title "Step 4: Enabling Services on Boot"
echo ""
log "Enabling camera-bridge service..."
systemctl enable camera-bridge

if [[ "$install_wifi" =~ ^[Yy]$ ]]; then
    log "Enabling WiFi services..."
    systemctl enable hostapd 2>/dev/null || true
    systemctl enable dnsmasq 2>/dev/null || true
fi

log "Services enabled"
echo ""

# ========================================
# FINAL STATUS
# ========================================
title "Setup Complete!"
echo ""
echo "Camera Bridge has been installed on this machine."
echo ""
echo "Installed Features:"
echo "  ✓ Camera Bridge Service"

if [[ "$install_wifi" =~ ^[Yy]$ ]]; then
    echo "  ✓ WiFi Hotspot"
fi

if [[ "$install_scanner" =~ ^[Yy]$ ]]; then
    echo "  ✓ Brother Scanner Support"
fi

echo ""
echo "Next Steps:"
echo ""
echo "1. Configure Dropbox Token:"
echo "   - Via web: http://localhost/ (or http://192.168.4.1/ if using hotspot)"
echo "   - Via terminal: sudo bash scripts/terminal-ui.sh"
echo ""

if [[ "$install_wifi" =~ ^[Yy]$ ]]; then
    echo "2. WiFi Hotspot Configuration:"
    echo "   - SSID: CameraBridge (change in /etc/hostapd/hostapd.conf)"
    echo "   - IP: 192.168.4.1"
    echo "   - Connect devices to this network"
    echo ""
fi

if [[ "$install_scanner" =~ ^[Yy]$ ]]; then
    echo "3. Scanner Usage:"
    echo "   - Plug in Brother scanner via USB"
    echo "   - Test: scanimage -L"
    echo "   - Scan document: scan"
    echo "   - Scans auto-sync to Dropbox/Camera-Photos/"
    echo ""
fi

echo "4. Verify Services:"
echo "   sudo systemctl status camera-bridge"

if [[ "$install_wifi" =~ ^[Yy]$ ]]; then
    echo "   sudo systemctl status hostapd"
    echo "   sudo systemctl status dnsmasq"
fi

echo ""
echo "5. View Logs:"
echo "   sudo journalctl -u camera-bridge -f"
echo ""

title "All Done!"
echo ""
echo "Camera Bridge is ready to use."
echo ""
