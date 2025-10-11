#!/bin/bash

# Camera Bridge Complete Installation Script
# Includes all fixes and improvements from deployment testing
# Version: 2.0

set -e

echo "📷 Camera Bridge Complete Installation"
echo "======================================"
echo "Version 2.0 - Production Ready"
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Detect network interfaces
WIFI_INTERFACE=$(ip link | grep -E "^[0-9]+: w" | cut -d: -f2 | tr -d ' ' | head -1)
ETH_INTERFACE=$(ip link | grep -E "^[0-9]+: e" | cut -d: -f2 | tr -d ' ' | head -1)

if [ -z "$WIFI_INTERFACE" ]; then
    WIFI_INTERFACE="wlan0"  # fallback
fi
if [ -z "$ETH_INTERFACE" ]; then
    ETH_INTERFACE="eth0"    # fallback
fi

log "Detected interfaces - WiFi: $WIFI_INTERFACE, Ethernet: $ETH_INTERFACE"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log "Project directory: $PROJECT_DIR"

# ========================================
# STEP 1: Install Required Packages
# ========================================
log "Installing required packages..."
apt update
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
    iptables-persistent

# Install rclone
log "Installing rclone..."
if ! command -v rclone &> /dev/null; then
    curl https://rclone.org/install.sh | bash
else
    log "rclone already installed"
fi

# ========================================
# STEP 2: Create Users and Directories
# ========================================
log "Creating users and directories..."

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

# Set SMB password
log "Setting SMB password for camera user..."
echo -e "camera123\ncamera123" | smbpasswd -a -s camera
smbpasswd -e camera

# Create directory structure
mkdir -p /opt/camera-bridge/{scripts,web,config}
mkdir -p /srv/samba/camera-share
mkdir -p /var/log/camera-bridge
mkdir -p /etc/iptables

# Set permissions
chown -R camera:camera /srv/samba/camera-share
chmod 775 /srv/samba/camera-share
chown -R camerabridge:camerabridge /var/log/camera-bridge

# ========================================
# STEP 3: Copy Project Files
# ========================================
log "Copying project files..."

# Copy scripts
cp "$PROJECT_DIR"/scripts/*.sh /opt/camera-bridge/scripts/ 2>/dev/null || true
chmod +x /opt/camera-bridge/scripts/*.sh

# Copy web interface
cp "$PROJECT_DIR"/web/*.php /opt/camera-bridge/web/ 2>/dev/null || true
chown -R www-data:www-data /opt/camera-bridge/web

# Copy configuration templates
if [ -d "$PROJECT_DIR/config" ]; then
    cp "$PROJECT_DIR"/config/* /opt/camera-bridge/config/ 2>/dev/null || true
fi

# ========================================
# STEP 4: Configure SMB with Fixed Interface Binding
# ========================================
log "Configuring SMB/Samba..."

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

   # Don't restrict interfaces - listen on all
   # interfaces = lo $ETH_INTERFACE $WIFI_INTERFACE
   # bind interfaces only = yes

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

# Test and restart SMB
testparm -s /etc/samba/smb.conf > /dev/null 2>&1
systemctl restart smbd
systemctl stop nmbd 2>/dev/null || true
systemctl disable nmbd 2>/dev/null || true
log "SMB configured (nmbd disabled - not needed for IP access)"

# ========================================
# STEP 5: Configure Nginx
# ========================================
log "Configuring nginx..."

# Detect installed PHP-FPM version
PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)
if [ -z "$PHP_VERSION" ]; then
    # Fallback: find installed php-fpm version
    PHP_VERSION=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -1 | grep -oP 'php\K[0-9.]+' || echo "8.3")
fi

log "Detected PHP version: $PHP_VERSION"

# Fix web interface to use correct WiFi interface
if [ -f /opt/camera-bridge/web/index.php ]; then
    sed -i "s/wlan0/$WIFI_INTERFACE/g" /opt/camera-bridge/web/index.php
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

# ========================================
# STEP 6: Configure DHCP for Ethernet
# ========================================
log "Configuring DHCP for ethernet..."

# Set static IP on ethernet
ip addr flush dev $ETH_INTERFACE 2>/dev/null || true
ip addr add 192.168.10.1/24 dev $ETH_INTERFACE 2>/dev/null || true
ip link set $ETH_INTERFACE up 2>/dev/null || true

# Configure dnsmasq
cat > /etc/dnsmasq.d/camera-bridge.conf << EOF
# Camera Bridge DHCP Configuration

# Ethernet interface
interface=$ETH_INTERFACE
dhcp-range=interface:$ETH_INTERFACE,192.168.10.10,192.168.10.50,255.255.255.0,24h

# General options
bind-dynamic
except-interface=lo
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF

systemctl restart dnsmasq 2>/dev/null || true

# ========================================
# STEP 7: Enable IP Forwarding and NAT
# ========================================
log "Configuring IP forwarding and NAT..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Setup NAT
iptables -t nat -F
iptables -t nat -A POSTROUTING -o $WIFI_INTERFACE -j MASQUERADE
iptables -A FORWARD -i $ETH_INTERFACE -o $WIFI_INTERFACE -j ACCEPT
iptables -A FORWARD -i $WIFI_INTERFACE -o $ETH_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

# ========================================
# STEP 8: Install Camera Bridge Service
# ========================================
log "Installing Camera Bridge monitoring service..."

# Create the monitoring script
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
    log_message "ERROR: Dropbox not configured"
    exit 1
fi

# Test Dropbox connection
if rclone lsd dropbox: > /dev/null 2>&1; then
    log_message "Dropbox connection: OK"
else
    log_message "ERROR: Cannot connect to Dropbox"
    exit 1
fi

# Create Dropbox folder
rclone mkdir "$DROPBOX_DEST" 2>/dev/null

# Initial sync
log_message "Performing initial sync..."
rclone copy "$SMB_SHARE" "$DROPBOX_DEST" \
    --include "*.{jpg,jpeg,png,gif,bmp,JPG,JPEG,PNG,GIF,BMP}" \
    --verbose 2>&1 | while read line; do
        if [[ "$line" == *"Copied"* ]] || [[ "$line" == *"Transferred"* ]]; then
            log_message "$line"
        fi
    done

log_message "Monitoring for new files..."

# Monitor for changes
inotifywait -m -r -e create,modify,close_write,moved_to "$SMB_SHARE" --format '%w%f|%e' |
while IFS='|' read filepath event; do
    # Skip recycle bin
    if [[ "$filepath" == *".recycle"* ]]; then
        continue
    fi

    # Check if it's an image
    if [[ "$filepath" =~ \.(jpg|jpeg|png|gif|bmp|JPG|JPEG|PNG|GIF|BMP)$ ]]; then
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

# Create systemd service
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

log "Camera Bridge service installed and enabled"

# ========================================
# STEP 9: Setup Sudoers (Fixed)
# ========================================
log "Configuring sudo permissions..."

cat > /etc/sudoers.d/camera-bridge << 'SUDO_EOF'
# Allow camera-bridge service (running as root) to execute rclone as camerabridge user without password
root ALL=(camerabridge) NOPASSWD: /usr/bin/rclone

# Allow camerabridge user to run system commands without password for terminal UI and service management
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/rclone, /usr/sbin/smbpasswd, /bin/mount, /bin/umount, /usr/bin/apt, /usr/bin/apt-get, /bin/cp, /bin/rm, /bin/mkdir, /bin/chmod, /bin/chown, /usr/sbin/useradd, /opt/camera-bridge/scripts/wifi-manager.sh, /opt/camera-bridge/scripts/camera-bridge-service.sh, /usr/local/bin/terminal-ui-enhanced

# Allow www-data (web interface) to manage configuration files and services
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
SUDO_EOF

chmod 440 /etc/sudoers.d/camera-bridge

# Verify sudoers syntax
if ! visudo -c -f /etc/sudoers.d/camera-bridge >/dev/null 2>&1; then
    error "Sudoers configuration has syntax errors, removing..."
    rm -f /etc/sudoers.d/camera-bridge
else
    log "Sudoers configuration verified and installed"
fi

# ========================================
# STEP 10: Check for Dropbox Configuration
# ========================================
log "Checking for Dropbox configuration..."

DROPBOX_CONFIGURED=false

# Check if rclone config exists in various locations
if [ -f "/home/$SUDO_USER/.config/rclone/rclone.conf" ] && [ -s "/home/$SUDO_USER/.config/rclone/rclone.conf" ]; then
    log "Found rclone config for $SUDO_USER, copying..."
    mkdir -p /home/camerabridge/.config/rclone
    cp "/home/$SUDO_USER/.config/rclone/rclone.conf" /home/camerabridge/.config/rclone/
    chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
    chmod 600 /home/camerabridge/.config/rclone/rclone.conf
    DROPBOX_CONFIGURED=true
elif [ -f "/tmp/rclone.conf" ] && grep -q "dropbox" /tmp/rclone.conf; then
    log "Found temporary rclone config, copying..."
    mkdir -p /home/camerabridge/.config/rclone
    cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf
    chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
    chmod 600 /home/camerabridge/.config/rclone/rclone.conf
    DROPBOX_CONFIGURED=true
fi

# ========================================
# FINAL STATUS
# ========================================
echo ""
echo "======================================"
echo "📷 CAMERA BRIDGE INSTALLATION COMPLETE"
echo "======================================"
echo ""
echo "Network Configuration:"
echo "  WiFi Interface: $WIFI_INTERFACE"
echo "  Ethernet Interface: $ETH_INTERFACE"
echo "  Ethernet IP: 192.168.10.1"
echo "  DHCP Range: 192.168.10.10-50"
echo ""
echo "SMB Share:"
echo "  Path: /srv/samba/camera-share"
echo "  Network: \\\\192.168.10.1\\photos"
echo "  User: camera"
echo "  Password: camera123"
echo ""
echo "Services Status:"
systemctl is-active smbd > /dev/null && echo "  ✓ SMB: Running" || echo "  ✗ SMB: Not running"
systemctl is-active nginx > /dev/null && echo "  ✓ Web Server: Running" || echo "  ✗ Web: Not running"
systemctl is-active dnsmasq > /dev/null && echo "  ✓ DHCP: Running" || echo "  ✗ DHCP: Not running"

if [ "$DROPBOX_CONFIGURED" = true ]; then
    echo "  ✓ Dropbox: Configured"
    echo ""
    echo "Starting Camera Bridge service..."
    systemctl start camera-bridge
    echo "  ✓ Sync Service: Started"
else
    echo "  ⚠ Dropbox: Not configured"
    echo ""
    echo "To configure Dropbox:"
    echo "  1. Get your Dropbox access token"
    echo "  2. Run: sudo $PROJECT_DIR/scripts/setup-dropbox-token.sh"
    echo "  3. Start service: sudo systemctl start camera-bridge"
fi

echo ""
echo "======================================"
echo "Next Steps:"
echo "1. Connect laptop to ethernet port"
echo "2. Laptop gets IP via DHCP"
echo "3. Access SMB: \\\\192.168.10.1\\photos"
echo "4. Drop photos → auto sync to Dropbox"
echo ""
echo "Monitor logs: sudo journalctl -u camera-bridge -f"
echo "======================================"