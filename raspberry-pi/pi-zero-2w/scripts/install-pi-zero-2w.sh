#!/bin/bash

# Pi Zero 2 W Camera Bridge Installation Script
# Specialized installation with USB gadget mode support

set -e

# Color output
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

# Verify Pi Zero 2 W hardware
if ! grep -q "Pi Zero 2" /proc/device-tree/model 2>/dev/null; then
    warn "This script is optimized for Pi Zero 2 W. Other hardware may not support all features."
    read -p "Continue anyway? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 0
    fi
fi

echo -e "${BLUE}🍓 Pi Zero 2 W Camera Bridge Installation${NC}"
echo "=========================================="

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

log "Project root: $PROJECT_ROOT"
log "Installing for Pi Zero 2 W with USB gadget support"

# Check if this is an auto-installation
AUTO_INSTALL=false
if [ -f /boot/auto-install-camera-bridge.txt ]; then
    log "Auto-installation mode detected"
    AUTO_INSTALL=true
fi

# Check system requirements
log "Checking system requirements..."

# Check available space (need at least 1.5GB)
available_space=$(df / | awk 'NR==2{print $4}')
if [ "$available_space" -lt 1500000 ]; then
    error "Insufficient disk space. Need at least 1.5GB free space."
    exit 1
fi

# Check RAM (Pi Zero 2 W has 512MB)
total_ram=$(free -m | awk 'NR==2{print $2}')
if [ "$total_ram" -lt 400 ]; then
    warn "Low RAM detected ($total_ram MB). Performance may be limited."
fi

# Update system
log "Updating system packages..."
apt update
apt upgrade -y

# Install Pi Zero 2 W specific packages
log "Installing packages optimized for Pi Zero 2 W..."
apt install -y \
    hostapd \
    dnsmasq \
    nginx \
    php8.2-fpm \
    php8.2-cli \
    samba \
    samba-common-bin \
    dialog \
    wireless-tools \
    inotify-tools \
    curl \
    git \
    net-tools \
    htop \
    vim \
    rsync \
    unzip \
    python3 \
    python3-pip \
    usbutils

# Install rclone
log "Installing rclone..."
if ! command -v rclone &> /dev/null; then
    curl -L https://rclone.org/install.sh | bash
else
    log "rclone already installed"
fi

# Pi Zero 2 W specific optimizations
log "Applying Pi Zero 2 W optimizations..."

# Enable necessary kernel modules for USB gadget
log "Configuring USB gadget support..."
if ! grep -q "dtoverlay=dwc2" /boot/firmware/config.txt; then
    echo "dtoverlay=dwc2" >> /boot/firmware/config.txt
fi

if ! grep -q "modules-load=dwc2" /boot/firmware/cmdline.txt; then
    # Insert modules-load parameter after rootwait
    sed -i 's/rootwait/rootwait modules-load=dwc2,libcomposite/' /boot/firmware/cmdline.txt
fi

# GPU memory optimization for headless operation
if ! grep -q "gpu_mem=" /boot/firmware/config.txt; then
    echo "gpu_mem=16" >> /boot/firmware/config.txt
else
    sed -i 's/gpu_mem=.*/gpu_mem=16/' /boot/firmware/config.txt
fi

# Disable unnecessary services to save resources
log "Disabling unnecessary services for Pi Zero 2 W..."
systemctl disable bluetooth 2>/dev/null || true
systemctl disable hciuart 2>/dev/null || true

# Create users
log "Creating users..."
if ! id "camerabridge" &>/dev/null; then
    useradd -m -s /bin/bash camerabridge
    usermod -aG sudo,gpio,i2c,spi camerabridge
    log "User 'camerabridge' created"
fi

if ! id "camera" &>/dev/null; then
    useradd -M -s /sbin/nologin camera
    log "User 'camera' created"
fi

# Set SMB password
echo -e "camera123\ncamera123" | smbpasswd -a -s camera

# Create directory structure
log "Creating directory structure..."
mkdir -p /opt/camera-bridge/{scripts,web,config}
mkdir -p /srv/samba/camera-share
mkdir -p /var/log/camera-bridge
mkdir -p /mnt/camera-bridge-usb

# Set ownership
chown -R camerabridge:camerabridge /srv/samba/camera-share
chown -R camerabridge:camerabridge /var/log/camera-bridge
chown -R camerabridge:camerabridge /mnt/camera-bridge-usb

# Copy project files
log "Installing Camera Bridge files..."
cp -r "$PROJECT_ROOT"/scripts/* /opt/camera-bridge/scripts/
cp -r "$PROJECT_ROOT"/web/* /opt/camera-bridge/web/
cp -r "$PROJECT_ROOT"/config/* /opt/camera-bridge/config/

# Copy Pi Zero 2 W specific files
if [ -d "$PROJECT_ROOT/raspberry-pi/pi-zero-2w" ]; then
    cp -r "$PROJECT_ROOT"/raspberry-pi/pi-zero-2w/scripts/* /opt/camera-bridge/scripts/
fi

# Make scripts executable
chmod +x /opt/camera-bridge/scripts/*.sh

# Create symlinks for enhanced scripts
ln -sf /opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh /opt/camera-bridge/scripts/camera-bridge-service.sh
ln -sf /opt/camera-bridge/scripts/terminal-ui-enhanced.sh /opt/camera-bridge/scripts/terminal-ui.sh

# Set up systemd service with enhanced version
cat > /etc/systemd/system/camera-bridge.service << 'EOF'
[Unit]
Description=Camera Bridge Service - Enhanced with USB Gadget Support
Documentation=https://github.com/tomganleylee/Topcom
After=network.target network-online.target
Wants=network-online.target
Requires=network.target

[Service]
Type=forking
User=root
Group=root
ExecStart=/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh start
ExecStop=/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh stop
ExecReload=/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh restart
PIDFile=/var/run/camera-bridge.pid

# Restart policy
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

# Resource limits (conservative for Pi Zero 2 W)
LimitNOFILE=1024
LimitNPROC=512

# Environment
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=SMB_SHARE=/srv/samba/camera-share
Environment=USB_MOUNT=/mnt/camera-bridge-usb
Environment=LOG_FILE=/var/log/camera-bridge/service.log

# Working directory
WorkingDirectory=/opt/camera-bridge

# Timeout settings
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Configure SMB for Pi Zero 2 W
log "Configuring SMB server..."
cp /opt/camera-bridge/config/smb.conf /etc/samba/smb.conf

# Configure nginx with PHP
log "Configuring nginx..."
php_version="8.2"
sed -i 's/memory_limit = .*/memory_limit = 128M/' /etc/php/$php_version/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' /etc/php/$php_version/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = 50M/' /etc/php/$php_version/fpm/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 180/' /etc/php/$php_version/fpm/php.ini

systemctl enable php$php_version-fpm
systemctl start php$php_version-fpm

# Configure nginx site
cp /opt/camera-bridge/config/nginx-camera-bridge.conf /etc/nginx/sites-available/camera-bridge
ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/default

# Set web permissions
chown -R www-data:www-data /opt/camera-bridge/web

# Configure hostapd for Pi Zero 2 W WiFi
log "Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=CameraBridge-Setup
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=setup123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Pi Zero 2 W optimizations
country_code=US
ieee80211n=1
require_ht=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
EOF

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd

# Configure dnsmasq
log "Configuring dnsmasq..."
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
cat >> /etc/dnsmasq.conf << 'EOF'

# Camera Bridge AP Configuration for Pi Zero 2 W
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
dhcp-option=3,192.168.4.1
dhcp-option=6,8.8.8.8,1.1.1.1
EOF

# Set up sudoers
log "Configuring sudoers..."
cat > /etc/sudoers.d/camera-bridge << 'EOF'
# Camera Bridge sudoers configuration
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf
www-data ALL=(ALL) NOPASSWD: /bin/chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf
www-data ALL=(ALL) NOPASSWD: /usr/sbin/iwlist
www-data ALL=(ALL) NOPASSWD: /opt/camera-bridge/scripts/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart wpa_supplicant
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart dhcpcd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart hostapd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart dnsmasq
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start hostapd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop hostapd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start dnsmasq
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop dnsmasq
camerabridge ALL=(ALL) NOPASSWD: /opt/camera-bridge/scripts/*
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl * camera-bridge
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl * smbd
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl * nmbd
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl * wpa_supplicant
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl * hostapd
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl * dnsmasq
EOF

# Pi Zero 2 W performance optimizations
log "Applying performance optimizations..."

# Optimize memory usage
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
echo "vm.min_free_kbytes=8192" >> /etc/sysctl.conf

# Optimize for low-power operation
echo "vm.laptop_mode=1" >> /etc/sysctl.conf
echo "vm.dirty_ratio=15" >> /etc/sysctl.conf
echo "vm.dirty_background_ratio=10" >> /etc/sysctl.conf

# Configure log rotation for SD card longevity
log "Setting up log rotation..."
cat > /etc/logrotate.d/camera-bridge << 'EOF'
/var/log/camera-bridge/*.log {
    daily
    missingok
    rotate 3
    compress
    notifempty
    create 640 camerabridge camerabridge
    postrotate
        systemctl reload camera-bridge || true
    endscript
}
EOF

# Create USB gadget configuration
log "Setting up USB gadget configuration..."
mkdir -p /opt/camera-bridge/config
cat > /opt/camera-bridge/config/usb-gadget.conf << 'EOF'
# USB Gadget Configuration for Pi Zero 2 W Camera Bridge
STORAGE_SIZE_MB=2048
VENDOR_ID="0x1d6b"
PRODUCT_ID="0x0104"
MANUFACTURER="Camera Bridge"
PRODUCT="Photo Storage Device"
AUTO_DELETE_SYNCED=false
SYNC_INTERVAL=180
EOF

# Create command shortcuts
log "Creating command shortcuts..."
cat > /etc/profile.d/camera-bridge.sh << 'EOF'
# Camera Bridge aliases for Pi Zero 2 W
alias cb-ui='camera-bridge-ui'
alias cb-status='camera-bridge-status'
alias cb-logs='camera-bridge-logs'
alias cb-wifi='camera-bridge-wifi'
alias cb-usb='usb-gadget-manager.sh'
alias cb-temp='vcgencmd measure_temp'
alias cb-mode='camera-bridge-service-enhanced.sh'

# USB gadget specific shortcuts
alias usb-setup='usb-gadget-manager.sh setup'
alias usb-enable='usb-gadget-manager.sh enable'
alias usb-disable='usb-gadget-manager.sh disable'
alias usb-status='usb-gadget-manager.sh status'
EOF

# Create global command links
ln -sf /opt/camera-bridge/scripts/terminal-ui-enhanced.sh /usr/local/bin/camera-bridge-ui
ln -sf /opt/camera-bridge/scripts/usb-gadget-manager.sh /usr/local/bin/usb-gadget-manager.sh

# Enable services
log "Enabling services..."
systemctl enable nginx
systemctl enable samba
systemctl disable hostapd  # Managed by scripts
systemctl disable dnsmasq  # Managed by scripts

# Create desktop shortcuts if GUI available
if [ -d "/usr/share/applications" ]; then
    log "Creating desktop shortcuts..."

    cat > /usr/share/applications/camera-bridge-modes.desktop << 'EOF'
[Desktop Entry]
Name=Camera Bridge Modes
Comment=Switch between SMB and USB Gadget modes
Exec=x-terminal-emulator -e "camera-bridge-service-enhanced.sh"
Icon=preferences-system
Type=Application
Categories=System;Photography;
Terminal=false
StartupNotify=true
EOF

    chmod 644 /usr/share/applications/camera-bridge-*.desktop
fi

# Create boot optimization script
log "Creating boot optimization..."
cat > /opt/camera-bridge/scripts/boot-optimize.sh << 'EOF'
#!/bin/bash
# Pi Zero 2 W boot optimization

# Disable unnecessary services on boot
systemctl disable bluetooth 2>/dev/null || true
systemctl disable triggerhappy 2>/dev/null || true

# Optimize boot parameters
if ! grep -q "quiet" /boot/firmware/cmdline.txt; then
    sed -i 's/$/ quiet/' /boot/firmware/cmdline.txt
fi

# Load USB gadget modules early if configured for USB mode
if [ -f "/opt/camera-bridge/config/camera-bridge.conf" ]; then
    if grep -q 'OPERATION_MODE="usb-gadget"' /opt/camera-bridge/config/camera-bridge.conf; then
        modprobe dwc2 2>/dev/null || true
        modprobe libcomposite 2>/dev/null || true
    fi
fi
EOF

chmod +x /opt/camera-bridge/scripts/boot-optimize.sh

# Add to rc.local for early boot optimization
if [ -f "/etc/rc.local" ]; then
    if ! grep -q "boot-optimize.sh" /etc/rc.local; then
        sed -i '/^exit 0/i /opt/camera-bridge/scripts/boot-optimize.sh &' /etc/rc.local
    fi
fi

# Final permissions
chown -R camerabridge:camerabridge /opt/camera-bridge
chown -R www-data:www-data /opt/camera-bridge/web

# Setup seamless user experience
log "Configuring seamless user experience..."

BOOT_SETUP_SUCCESS=false
LOGIN_SETUP_SUCCESS=false
AUTOSTART_SETUP_SUCCESS=false

# Setup boot splash
if [ -f "$SCRIPT_DIR/../../../scripts/setup-boot-splash.sh" ]; then
    log "Configuring boot splash screen..."
    if "$SCRIPT_DIR/../../../scripts/setup-boot-splash.sh" enable; then
        log "✓ Boot splash screen configured successfully"
        BOOT_SETUP_SUCCESS=true
    else
        log "✗ Boot splash setup failed"
    fi
else
    log "✗ Boot splash script not found"
fi

# Setup auto-login
if [ -f "$SCRIPT_DIR/../../../scripts/setup-auto-login.sh" ]; then
    log "Configuring auto-login..."
    if "$SCRIPT_DIR/../../../scripts/setup-auto-login.sh" enable; then
        log "✓ Auto-login configured successfully"
        LOGIN_SETUP_SUCCESS=true
    else
        log "✗ Auto-login setup failed"
    fi
else
    log "✗ Auto-login script not found"
fi

# Setup autostart script
if [ -f "$SCRIPT_DIR/../../../scripts/camera-bridge-autostart.sh" ]; then
    log "Installing autostart script..."
    if cp "$SCRIPT_DIR/../../../scripts/camera-bridge-autostart.sh" /usr/local/bin/camera-bridge-autostart && \
       chmod +x /usr/local/bin/camera-bridge-autostart; then
        log "✓ Autostart script installed successfully"
        AUTOSTART_SETUP_SUCCESS=true
    else
        log "✗ Autostart script installation failed"
    fi
else
    log "✗ Autostart script not found"
fi

log "Pi Zero 2 W installation completed successfully!"
echo ""
echo "==========================================="
echo "🍓 PI ZERO 2W CAMERA BRIDGE READY"
echo "==========================================="
echo ""
echo "Hardware: Pi Zero 2 W with USB Gadget Support"
echo ""
echo "Core Features Status:"
echo "  ✓ SMB Network Sharing Mode"
echo "  ✓ USB Gadget Storage Mode"
echo "  ✓ Automatic mode detection"
echo "  ✓ Pi Zero 2W optimizations"
echo ""
echo "Seamless Boot Experience:"
if [ "$BOOT_SETUP_SUCCESS" = true ]; then
    echo "  ✓ Boot splash screen: ENABLED"
else
    echo "  ✗ Boot splash screen: FAILED"
fi

if [ "$LOGIN_SETUP_SUCCESS" = true ]; then
    echo "  ✓ Auto-login: ENABLED (as camerabridge user)"
else
    echo "  ✗ Auto-login: FAILED"
fi

if [ "$AUTOSTART_SETUP_SUCCESS" = true ]; then
    echo "  ✓ Terminal UI auto-start: ENABLED"
else
    echo "  ✗ Terminal UI auto-start: FAILED"
fi

echo ""

# If any seamless boot setup failed, provide manual instructions
if [ "$BOOT_SETUP_SUCCESS" = false ] || [ "$LOGIN_SETUP_SUCCESS" = false ] || [ "$AUTOSTART_SETUP_SUCCESS" = false ]; then
    echo "⚠️  MANUAL SETUP REQUIRED FOR SEAMLESS BOOT:"
    echo ""

    if [ "$BOOT_SETUP_SUCCESS" = false ]; then
        echo "Enable boot splash:"
        echo "  sudo $SCRIPT_DIR/../../../scripts/setup-boot-splash.sh enable"
        echo ""
    fi

    if [ "$LOGIN_SETUP_SUCCESS" = false ]; then
        echo "Enable auto-login:"
        echo "  sudo $SCRIPT_DIR/../../../scripts/setup-auto-login.sh enable"
        echo ""
    fi

    if [ "$AUTOSTART_SETUP_SUCCESS" = false ]; then
        echo "Install autostart script:"
        echo "  sudo cp $SCRIPT_DIR/../../../scripts/camera-bridge-autostart.sh /usr/local/bin/camera-bridge-autostart"
        echo "  sudo chmod +x /usr/local/bin/camera-bridge-autostart"
        echo ""
    fi

    echo "Verify setup:"
    echo "  sudo $SCRIPT_DIR/../../../scripts/verify-installation.sh"
    echo ""
fi

echo "Available Commands:"
echo "  cb-ui          - Terminal interface"
echo "  cb-status      - System status"
echo "  cb-usb         - USB gadget manager"
echo "  cb-mode        - Mode switching"
echo ""
echo "Operation Modes:"
echo "  SMB Mode       - Network file sharing for cameras with WiFi"
echo "  USB Gadget     - Direct camera connection via USB-C"
echo ""
echo "Next Steps:"
echo "1. Complete any manual setup commands above (if needed)"
echo "2. Reboot to apply kernel changes: sudo reboot"
echo "3. After reboot, enjoy seamless boot experience!"
echo "4. Access web interface: http://[pi-ip]"
echo "5. Configure Dropbox via terminal UI"
echo ""
echo "On reboot, you should see:"
echo "  → Custom Camera Bridge boot splash"
echo "  → Automatic login as camerabridge user"
echo "  → Welcome banner with Pi Zero 2W USB gadget options"
echo "  → Terminal UI with mode switching capabilities"
echo ""
echo "USB Gadget Usage:"
echo "1. Switch to USB mode: cb-mode switch-mode usb-gadget"
echo "2. Connect Pi to camera via USB cable"
echo "3. Camera will see Pi as USB storage device"
echo ""
echo "Reboot required for USB gadget support!"