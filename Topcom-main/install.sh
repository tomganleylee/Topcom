#!/bin/bash

################################################################################
# Camera Bridge - Complete Installation & Update Script
# Version: 3.0
#
# This script handles both fresh installations and updates to existing systems.
# It is idempotent - safe to run multiple times.
#
# Features:
# - Automatic photo sync from cameras to Dropbox via SMB/Ethernet
# - DHCP server for camera connectivity
# - Brother scanner support (optional)
# - Web interface for setup and monitoring
# - Handles fresh installs AND updates safely
#
# Usage:
#   Fresh install:        sudo ./install.sh
#   Update existing:      sudo ./install.sh
#   Skip scanner:         sudo INSTALL_SCANNER=false ./install.sh
#
################################################################################

set -e

# Configuration flags
INSTALL_SCANNER=${INSTALL_SCANNER:-true}  # Scanner enabled by default
UPDATE_MODE=false

echo "📷 Camera Bridge - Installation & Update Script"
echo "================================================"
echo "Version 3.0 - Unified Installer"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
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

info() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Detect if this is an update (camera-bridge service already exists)
if systemctl list-unit-files | grep -q "camera-bridge.service"; then
    UPDATE_MODE=true
    warn "Existing Camera Bridge installation detected - running in UPDATE mode"
    warn "This will preserve your configurations (Dropbox, passwords, etc.)"
    echo ""
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

log "Project directory: $PROJECT_DIR"
echo ""

# Detect network interfaces
info "Detecting network interfaces..."
WIFI_INTERFACE=$(ip link | grep -E "^[0-9]+: w" | grep -v "wlp1s0" | cut -d: -f2 | tr -d ' ' | head -1)
ETH_INTERFACE=$(ip link | grep -E "^[0-9]+: e" | cut -d: -f2 | tr -d ' ' | head -1)

if [ -z "$WIFI_INTERFACE" ]; then
    WIFI_INTERFACE="wlan0"  # fallback
    warn "No external WiFi adapter detected, using fallback: $WIFI_INTERFACE"
fi
if [ -z "$ETH_INTERFACE" ]; then
    ETH_INTERFACE="eth0"    # fallback
    warn "No ethernet interface detected, using fallback: $ETH_INTERFACE"
fi

log "Network interfaces - WiFi: $WIFI_INTERFACE, Ethernet: $ETH_INTERFACE"
echo ""

################################################################################
# STEP 1: Install/Update Required Packages
################################################################################
info "STEP 1: Installing/updating required packages..."

apt update

# Only do full upgrade if this is a fresh install
if [ "$UPDATE_MODE" = false ]; then
    log "Fresh install - performing full system upgrade..."
    apt upgrade -y
else
    log "Update mode - skipping system upgrade"
fi

apt install -y \
    hostapd \
    dnsmasq \
    nginx \
    php-fpm \
    php-cli \
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
    iptables-persistent \
    bridge-utils \
    iw \
    wpasupplicant

# Install rclone
log "Installing/updating rclone..."
if ! command -v rclone &> /dev/null; then
    curl https://rclone.org/install.sh | bash
else
    log "rclone already installed"
fi

# Install scanner packages if requested
if [ "$INSTALL_SCANNER" = "true" ]; then
    log "Installing Brother scanner packages..."
    apt install -y \
        brscan-skey \
        libusb-1.0-0 \
        sane \
        sane-utils \
        xsane 2>/dev/null || warn "Some scanner packages not available"
fi

echo ""

################################################################################
# STEP 2: Create Users and Directories
################################################################################
info "STEP 2: Creating users and directories..."

# Create camerabridge user
if ! id "camerabridge" &>/dev/null; then
    useradd -m -s /bin/bash camerabridge
    usermod -aG sudo camerabridge
    log "User 'camerabridge' created"
else
    log "User 'camerabridge' already exists"
fi

# Create SMB user
if ! id "camera" &>/dev/null; then
    useradd -M -s /sbin/nologin camera
    log "User 'camera' created"
else
    log "User 'camera' already exists"
fi

# Set/update SMB password (idempotent)
log "Setting SMB password for camera user..."
echo -e "camera123\ncamera123" | smbpasswd -a -s camera 2>/dev/null || true
smbpasswd -e camera 2>/dev/null || true

# Create scanner group if needed
if [ "$INSTALL_SCANNER" = "true" ]; then
    if ! getent group scanner &>/dev/null; then
        groupadd scanner
        log "Group 'scanner' created"
    fi
    usermod -aG scanner camerabridge 2>/dev/null || true
fi

# Create directory structure
mkdir -p /opt/camera-bridge/{scripts,web,config}
mkdir -p /srv/samba/camera-share
mkdir -p /srv/scanner/scans 2>/dev/null || true
mkdir -p /var/log/camera-bridge
mkdir -p /etc/iptables

# Set permissions
chown -R camera:camera /srv/samba/camera-share
chmod 775 /srv/samba/camera-share

if [ "$INSTALL_SCANNER" = "true" ] && [ -d /srv/scanner/scans ]; then
    chown -R camerabridge:scanner /srv/scanner/scans 2>/dev/null || true
    chmod 775 /srv/scanner/scans 2>/dev/null || true
fi

chown -R camerabridge:camerabridge /var/log/camera-bridge

echo ""

################################################################################
# STEP 3: Copy/Update Project Files
################################################################################
info "STEP 3: Copying/updating project files..."

# Copy scripts
if [ -d "$PROJECT_DIR/scripts" ]; then
    cp "$PROJECT_DIR"/scripts/*.sh /opt/camera-bridge/scripts/ 2>/dev/null || true
    chmod +x /opt/camera-bridge/scripts/*.sh 2>/dev/null || true
    log "Scripts updated"
fi

# Copy web interface
if [ -d "$PROJECT_DIR/web" ]; then
    cp "$PROJECT_DIR"/web/*.php /opt/camera-bridge/web/ 2>/dev/null || true
    cp "$PROJECT_DIR"/web/*.html /opt/camera-bridge/web/ 2>/dev/null || true
    chown -R www-data:www-data /opt/camera-bridge/web
    log "Web interface updated"
fi

# Copy configuration templates (only if they don't exist - preserve user configs)
if [ -d "$PROJECT_DIR/config" ]; then
    for config_file in "$PROJECT_DIR"/config/*; do
        filename=$(basename "$config_file")
        if [ ! -f "/opt/camera-bridge/config/$filename" ] || [ "$UPDATE_MODE" = false ]; then
            cp "$config_file" /opt/camera-bridge/config/ 2>/dev/null || true
        else
            log "Preserving existing config: $filename"
        fi
    done
fi

echo ""

################################################################################
# STEP 4: Configure SMB/Samba
################################################################################
info "STEP 4: Configuring SMB/Samba..."

# Backup existing config if in update mode
if [ "$UPDATE_MODE" = true ] && [ -f /etc/samba/smb.conf ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup-$(date +%Y%m%d-%H%M%S)
    log "Backed up existing Samba configuration"
fi

cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = WORKGROUP
   server string = Camera Bridge Server
   netbios name = camera-bridge
   security = user
   map to guest = never
   dns proxy = no

   # Performance optimizations
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
   read raw = yes
   write raw = yes
   max xmit = 65535
   dead time = 15
   getwd cache = yes

   # Logging
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   log level = 2

   # Disable printing
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

   # Character set
   unix charset = UTF-8
   dos charset = CP850

   # Security enhancements
   server min protocol = SMB2_10
   client min protocol = SMB2
   restrict anonymous = 2

[photos]
   comment = Camera Photos Share
   path = /srv/samba/camera-share
   browseable = yes
   guest ok = no
   read only = no
   create mask = 0664
   directory mask = 0775
   valid users = camera
   write list = camera
   force user = camera
   force group = camera

   # Performance for large files
   strict allocate = yes
   allocation roundup size = 1048576

   # Prevent file locks
   locking = no
   strict locking = no
   oplocks = no
   level2 oplocks = no

   # Hide system files
   hide dot files = yes
   hide special files = yes
   hide unreadable = yes

   # File naming
   preserve case = yes
   short preserve case = yes
   case sensitive = no
EOF

# Add scanner share if scanner is being installed
if [ "$INSTALL_SCANNER" = "true" ]; then
    cat >> /etc/samba/smb.conf << EOF

[scanner]
   comment = Scanner Documents
   path = /srv/scanner/scans
   browseable = yes
   guest ok = no
   read only = no
   create mask = 0664
   directory mask = 0775
   valid users = camera
   write list = camera
   force user = camerabridge
   force group = scanner
EOF
    log "Added scanner SMB share"
fi

# Test and restart SMB
testparm -s /etc/samba/smb.conf > /dev/null 2>&1
systemctl restart smbd
systemctl enable smbd
systemctl stop nmbd 2>/dev/null || true
systemctl disable nmbd 2>/dev/null || true
log "SMB configured and restarted"

echo ""

################################################################################
# STEP 5: Configure Nginx Web Interface
################################################################################
info "STEP 5: Configuring web interface..."

# Detect installed PHP-FPM version
PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)
if [ -z "$PHP_VERSION" ]; then
    PHP_VERSION=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -1 | grep -oP 'php\K[0-9.]+' || echo "8.3")
fi

log "Detected PHP version: $PHP_VERSION"

# Fix web interface to use correct WiFi interface
if [ -f /opt/camera-bridge/web/index.php ]; then
    sed -i "s/wlan0/$WIFI_INTERFACE/g" /opt/camera-bridge/web/index.php 2>/dev/null || true
fi

# Backup existing nginx config if in update mode
if [ "$UPDATE_MODE" = true ] && [ -f /etc/nginx/sites-available/camera-bridge ]; then
    cp /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-available/camera-bridge.backup-$(date +%Y%m%d-%H%M%S)
    log "Backed up existing nginx configuration"
fi

cat > /etc/nginx/sites-available/camera-bridge << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/camera-bridge/web;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/default
systemctl restart nginx
systemctl enable nginx
log "Web interface configured"

echo ""

################################################################################
# STEP 6: Configure DHCP for Ethernet
################################################################################
info "STEP 6: Configuring DHCP server for ethernet..."

# Set static IP on ethernet (idempotent)
ip addr flush dev $ETH_INTERFACE 2>/dev/null || true
ip addr add 192.168.10.1/24 dev $ETH_INTERFACE 2>/dev/null || warn "IP already assigned"
ip link set $ETH_INTERFACE up 2>/dev/null || true

# Make ethernet IP permanent via systemd-networkd
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-${ETH_INTERFACE}.network << EOF
[Match]
Name=$ETH_INTERFACE

[Network]
Address=192.168.10.1/24
EOF

log "Static IP configured for $ETH_INTERFACE"

# Backup existing dnsmasq config if in update mode
if [ "$UPDATE_MODE" = true ] && [ -f /etc/dnsmasq.d/camera-bridge.conf ]; then
    cp /etc/dnsmasq.d/camera-bridge.conf /etc/dnsmasq.d/camera-bridge.conf.backup-$(date +%Y%m%d-%H%M%S)
    log "Backed up existing dnsmasq configuration"
fi

# Configure dnsmasq for ethernet DHCP
cat > /etc/dnsmasq.d/camera-bridge.conf << EOF
# Camera Bridge DHCP Configuration

# Ethernet interface for cameras/scanners
interface=$ETH_INTERFACE
dhcp-range=interface:$ETH_INTERFACE,192.168.10.10,192.168.10.50,255.255.255.0,24h

# General options
bind-dynamic
except-interface=lo
except-interface=wlp1s0
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4

# Logging
log-dhcp
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq
log "DHCP server configured and started"

echo ""

################################################################################
# STEP 7: Enable IP Forwarding and NAT
################################################################################
info "STEP 7: Configuring IP forwarding and NAT..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# Detect the primary internet interface (usually wlp1s0 or wlan0 for internal WiFi)
INTERNET_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$INTERNET_IF" ]; then
    INTERNET_IF="wlp1s0"  # fallback to internal WiFi
fi

log "Using $INTERNET_IF for internet NAT"

# Setup NAT (flush first to be idempotent)
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true

iptables -t nat -A POSTROUTING -o $INTERNET_IF -j MASQUERADE
iptables -A FORWARD -i $ETH_INTERFACE -o $INTERNET_IF -j ACCEPT
iptables -A FORWARD -i $INTERNET_IF -o $ETH_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
log "NAT configured"

echo ""

################################################################################
# STEP 8: Install/Update Camera Bridge Service
################################################################################
info "STEP 8: Installing/updating Camera Bridge monitoring service..."

# Create the monitoring script (updated version)
cat > /opt/camera-bridge/scripts/monitor-service.sh << 'MONITOR_EOF'
#!/bin/bash

# Camera Bridge Monitor Service
SMB_SHARE="/srv/samba/camera-share"
DROPBOX_DEST="dropbox:Camera-Photos"
LOG_FILE="/var/log/camera-bridge/monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "Camera Bridge Monitor starting..."

# Check Dropbox config
if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
    log_message "ERROR: Dropbox not configured yet - waiting for configuration"
    log_message "Please configure Dropbox using the web interface or terminal UI"
    sleep 60
    exit 1
fi

# Test Dropbox connection
if rclone lsd dropbox: > /dev/null 2>&1; then
    log_message "Dropbox connection: OK"
else
    log_message "ERROR: Cannot connect to Dropbox - will retry"
    sleep 60
    exit 1
fi

# Create Dropbox folder
rclone mkdir "$DROPBOX_DEST" 2>/dev/null

# Initial sync
log_message "Performing initial sync..."
rclone copy "$SMB_SHARE" "$DROPBOX_DEST" \
    --include "*.{jpg,jpeg,png,gif,bmp,JPG,JPEG,PNG,GIF,BMP,pdf,PDF}" \
    --verbose 2>&1 | while read line; do
        if [[ "$line" == *"Copied"* ]] || [[ "$line" == *"Transferred"* ]]; then
            log_message "$line"
        fi
    done

log_message "Monitoring for new files..."

# Monitor for changes
inotifywait -m -r -e create,modify,close_write,moved_to "$SMB_SHARE" --format '%w%f|%e' |
while IFS='|' read filepath event; do
    # Skip recycle bin and hidden files
    if [[ "$filepath" == *".recycle"* ]] || [[ "$filepath" == */\.* ]]; then
        continue
    fi

    # Check if it's a supported file type
    if [[ "$filepath" =~ \.(jpg|jpeg|png|gif|bmp|JPG|JPEG|PNG|GIF|BMP|pdf|PDF)$ ]]; then
        filename=$(basename "$filepath")
        log_message "Detected: $filename (event: $event)"

        # Wait for file to stabilize
        sleep 3

        # Upload to Dropbox
        if rclone copy "$filepath" "$DROPBOX_DEST/" --verbose 2>&1; then
            log_message "✓ Uploaded: $filename"
        else
            log_message "✗ Failed: $filename"
        fi
    fi
done
MONITOR_EOF

chmod +x /opt/camera-bridge/scripts/monitor-service.sh

# Create/update systemd service
if [ "$UPDATE_MODE" = true ] && [ -f /etc/systemd/system/camera-bridge.service ]; then
    log "Updating existing service file..."
    systemctl stop camera-bridge 2>/dev/null || true
fi

cat > /etc/systemd/system/camera-bridge.service << 'SERVICE_EOF'
[Unit]
Description=Camera Bridge Photo Sync Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=camerabridge
Group=camerabridge
ExecStart=/usr/bin/bash /opt/camera-bridge/scripts/monitor-service.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable camera-bridge
log "Camera Bridge service installed/updated and enabled"

echo ""

################################################################################
# STEP 9: Configure Sudo Permissions
################################################################################
info "STEP 9: Configuring sudo permissions..."

cat > /etc/sudoers.d/camera-bridge << 'SUDO_EOF'
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf
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
SUDO_EOF

chmod 440 /etc/sudoers.d/camera-bridge
log "Sudo permissions configured"

echo ""

################################################################################
# STEP 10: Check for Dropbox Configuration
################################################################################
info "STEP 10: Checking Dropbox configuration..."

DROPBOX_CONFIGURED=false

# Check if rclone config exists
if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ] && [ -s "/home/camerabridge/.config/rclone/rclone.conf" ]; then
    DROPBOX_CONFIGURED=true
    log "Dropbox already configured"
elif [ -f "/home/$SUDO_USER/.config/rclone/rclone.conf" ] && [ -s "/home/$SUDO_USER/.config/rclone/rclone.conf" ]; then
    log "Found rclone config for $SUDO_USER, copying..."
    mkdir -p /home/camerabridge/.config/rclone
    cp "/home/$SUDO_USER/.config/rclone/rclone.conf" /home/camerabridge/.config/rclone/
    chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
    chmod 600 /home/camerabridge/.config/rclone/rclone.conf
    DROPBOX_CONFIGURED=true
fi

echo ""

################################################################################
# STEP 11: Setup Brother Scanner (Optional)
################################################################################
if [ "$INSTALL_SCANNER" = "true" ]; then
    info "STEP 11: Setting up Brother scanner support..."

    if [ -f "$PROJECT_DIR/scripts/setup-brother-scanner.sh" ]; then
        log "Running Brother scanner setup..."
        bash "$PROJECT_DIR/scripts/setup-brother-scanner.sh" || warn "Scanner setup had some issues (may be OK if scanner not connected)"
    else
        warn "Brother scanner setup script not found - skipping"
    fi
    echo ""
fi

################################################################################
# INSTALLATION COMPLETE - Display Status
################################################################################
echo ""
echo "======================================================================"
if [ "$UPDATE_MODE" = true ]; then
    echo "🔄 CAMERA BRIDGE UPDATE COMPLETE"
else
    echo "✅ CAMERA BRIDGE INSTALLATION COMPLETE"
fi
echo "======================================================================"
echo ""
echo "Network Configuration:"
echo "  WiFi Interface:     $WIFI_INTERFACE"
echo "  Ethernet Interface: $ETH_INTERFACE"
echo "  Ethernet IP:        192.168.10.1"
echo "  DHCP Range:         192.168.10.10-50"
echo ""
echo "SMB Share (Photos):"
echo "  Path:     /srv/samba/camera-share"
echo "  Network:  \\\\192.168.10.1\\photos"
echo "  User:     camera"
echo "  Password: camera123"
echo ""

if [ "$INSTALL_SCANNER" = "true" ]; then
    echo "SMB Share (Scanner):"
    echo "  Path:     /srv/scanner/scans"
    echo "  Network:  \\\\192.168.10.1\\scanner"
    echo "  User:     camera"
    echo "  Password: camera123"
    echo ""
fi

echo "Services Status:"
systemctl is-active smbd > /dev/null && echo "  ✓ SMB:  Running" || echo "  ✗ SMB:  Not running"
systemctl is-active nginx > /dev/null && echo "  ✓ Web:  Running" || echo "  ✗ Web:  Not running"
systemctl is-active dnsmasq > /dev/null && echo "  ✓ DHCP: Running" || echo "  ✗ DHCP: Not running"

if [ "$DROPBOX_CONFIGURED" = true ]; then
    echo "  ✓ Dropbox: Configured"
    echo ""

    if [ "$UPDATE_MODE" = true ]; then
        log "Restarting Camera Bridge service with new configuration..."
        systemctl restart camera-bridge
    else
        log "Starting Camera Bridge service..."
        systemctl start camera-bridge
    fi

    systemctl is-active camera-bridge > /dev/null && echo "  ✓ Sync Service: Running" || echo "  ⚠ Sync Service: Check logs"
else
    echo "  ⚠ Dropbox: Not configured"
    echo ""
    echo "To configure Dropbox:"
    echo "  1. Open web interface: http://192.168.10.1"
    echo "  2. Follow setup wizard to connect Dropbox"
    echo "  3. Service will start automatically after configuration"
fi

echo ""
echo "======================================================================"
echo "Next Steps:"
echo ""
echo "1. Connect device to ethernet port ($ETH_INTERFACE)"
echo "2. Device gets IP automatically via DHCP (192.168.10.x)"
echo "3. Access web interface: http://192.168.10.1"
echo "4. Access SMB share: \\\\192.168.10.1\\photos"
echo "5. Copy photos → automatic sync to Dropbox!"
echo ""
echo "Monitoring:"
echo "  View logs:       sudo journalctl -u camera-bridge -f"
echo "  Service status:  sudo systemctl status camera-bridge"
echo "  Check DHCP:      sudo systemctl status dnsmasq"
echo ""
echo "🔒 Security Reminder:"
echo "  Change default passwords! See README for instructions."
echo "======================================================================"
echo ""

if [ "$UPDATE_MODE" = true ]; then
    echo "✅ Update completed successfully!"
    echo "   All your configurations have been preserved."
else
    echo "✅ Installation completed successfully!"
    echo "   Your Camera Bridge is ready to use!"
fi

echo ""
