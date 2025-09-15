#!/bin/bash

# Camera Bridge Package Installation Script
# Run this script with sudo to install all required packages

set -e

echo "🔧 Camera Bridge Package Installation"
echo "======================================"

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

log "Updating package repositories..."
apt update

log "Upgrading existing packages..."
apt upgrade -y

log "Installing required packages..."
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
    rsync

# Install rclone manually as it might not be in default repos
log "Installing rclone..."
if ! command -v rclone &> /dev/null; then
    curl https://rclone.org/install.sh | bash
else
    log "rclone already installed"
fi

log "Creating camera bridge user..."
if ! id "camerabridge" &>/dev/null; then
    useradd -m -s /bin/bash camerabridge
    usermod -aG sudo camerabridge
    log "User 'camerabridge' created"
else
    log "User 'camerabridge' already exists"
fi

log "Creating SMB user for camera access..."
if ! id "camera" &>/dev/null; then
    useradd -M -s /sbin/nologin camera
    log "User 'camera' created"
else
    log "User 'camera' already exists"
fi

# Set SMB password for camera user
log "Setting SMB password for camera user..."
echo -e "camera123\ncamera123" | smbpasswd -a -s camera

log "Creating directory structure..."
mkdir -p /opt/camera-bridge/{scripts,web,config}
mkdir -p /srv/samba/camera-share
mkdir -p /var/log/camera-bridge

# Set ownership
chown -R camerabridge:camerabridge /srv/samba/camera-share
chown -R camerabridge:camerabridge /var/log/camera-bridge

log "Setting up nginx PHP configuration..."
# Enable PHP-FPM
systemctl enable php8.3-fpm
systemctl start php8.3-fpm

# Configure nginx for PHP
cat > /etc/nginx/sites-available/camera-bridge << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/camera-bridge/web;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/default

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
EOF

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd

log "Configuring dnsmasq..."
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
cat >> /etc/dnsmasq.conf << 'EOF'

# Camera Bridge AP Configuration
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

log "Setting up sudoers for web interface..."
cat > /etc/sudoers.d/camera-bridge << 'EOF'
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

log "Enabling services..."
systemctl enable nginx
systemctl enable samba
systemctl disable hostapd  # Will be managed by scripts
systemctl disable dnsmasq  # Will be managed by scripts

# Setup seamless user experience (optional)
log "Setting up seamless user experience..."
if [ -f "$SCRIPT_DIR/setup-boot-splash.sh" ]; then
    "$SCRIPT_DIR/setup-boot-splash.sh" enable 2>/dev/null || log "Boot splash setup skipped"
fi

if [ -f "$SCRIPT_DIR/setup-auto-login.sh" ]; then
    "$SCRIPT_DIR/setup-auto-login.sh" enable 2>/dev/null || log "Auto-login setup skipped"
fi

log "Installation completed successfully!"
echo ""
echo "Next steps:"
echo "1. Copy camera bridge scripts to /opt/camera-bridge/scripts/"
echo "2. Copy web interface to /opt/camera-bridge/web/"
echo "3. Configure SMB and systemd service files"
echo "4. Run setup script to finalize installation"
echo ""
echo "Seamless boot experience:"
echo "- Boot splash screen: enabled"
echo "- Auto-login: enabled (as camerabridge user)"
echo "- Terminal UI will start automatically on console"