#!/bin/bash

# Camera Bridge Raspberry Pi Installation Script
# Optimized for Raspberry Pi 4/5 with Raspberry Pi OS

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

# Detect Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    warn "This script is optimized for Raspberry Pi. Continuing anyway..."
fi

echo -e "${BLUE}🍓 Camera Bridge Raspberry Pi Installation${NC}"
echo "=============================================="

# Check for minimum requirements
log "Checking system requirements..."

# Check available space
available_space=$(df / | awk 'NR==2{print $4}')
if [ "$available_space" -lt 2000000 ]; then  # Less than 2GB
    error "Insufficient disk space. Need at least 2GB free space."
    exit 1
fi

# Check RAM
total_ram=$(free -m | awk 'NR==2{print $2}')
if [ "$total_ram" -lt 500 ]; then  # Less than 512MB
    warn "Low RAM detected ($total_ram MB). Camera Bridge may have performance issues."
fi

# Update system
log "Updating package repositories..."
apt update

log "Upgrading existing packages (this may take a while)..."
apt upgrade -y

log "Installing Raspberry Pi specific packages..."
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
    python3-pip

# Install rclone
log "Installing rclone..."
if ! command -v rclone &> /dev/null; then
    curl -L https://rclone.org/install.sh | bash
else
    log "rclone already installed"
fi

# Raspberry Pi specific optimizations
log "Applying Raspberry Pi optimizations..."

# Enable SSH if not already enabled
if ! systemctl is-enabled ssh >/dev/null 2>&1; then
    systemctl enable ssh
    systemctl start ssh
    log "SSH enabled"
fi

# GPU memory split optimization
current_gpu_mem=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)
if [ "$current_gpu_mem" -gt 64 ]; then
    log "Optimizing GPU memory split for headless operation..."
    echo "gpu_mem=64" >> /boot/firmware/config.txt
fi

# Enable hardware I2C, SPI, and other interfaces if available
raspi-config nonint do_i2c 0 2>/dev/null || true
raspi-config nonint do_spi 0 2>/dev/null || true

# WiFi country setting
wifi_country=$(iwgetid --country 2>/dev/null || echo "US")
raspi-config nonint do_wifi_country "$wifi_country" 2>/dev/null || true

# Create users
log "Creating camera bridge user..."
if ! id "camerabridge" &>/dev/null; then
    useradd -m -s /bin/bash camerabridge
    usermod -aG sudo,gpio,i2c,spi camerabridge
    log "User 'camerabridge' created with Pi-specific groups"
else
    usermod -aG gpio,i2c,spi camerabridge
    log "User 'camerabridge' updated with Pi-specific groups"
fi

log "Creating SMB user for camera access..."
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

# Set ownership
chown -R camerabridge:camerabridge /srv/samba/camera-share
chown -R camerabridge:camerabridge /var/log/camera-bridge

# Setup USB auto-mount for additional storage
log "Configuring USB auto-mount..."
mkdir -p /media/usb-storage

cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Auto-mount USB storage devices
KERNEL=="sd[a-z][0-9]", SUBSYSTEMS=="usb", ACTION=="add", RUN+="/bin/mkdir -p /media/usb-storage/%k", RUN+="/bin/mount -o uid=camerabridge,gid=camerabridge,umask=0000 /dev/%k /media/usb-storage/%k"
KERNEL=="sd[a-z][0-9]", SUBSYSTEMS=="usb", ACTION=="remove", RUN+="/bin/umount /media/usb-storage/%k", RUN+="/bin/rmdir /media/usb-storage/%k"
EOF

# PHP configuration for Raspberry Pi
log "Configuring PHP for Raspberry Pi..."
php_version="8.2"

# Optimize PHP for limited resources
sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/$php_version/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/$php_version/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/$php_version/fpm/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/$php_version/fpm/php.ini

# Enable PHP-FPM
systemctl enable php$php_version-fpm
systemctl start php$php_version-fpm

# Configure nginx
log "Configuring nginx..."
cat > /etc/nginx/sites-available/camera-bridge << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/camera-bridge/web;
    index index.php index.html index.htm;

    server_name _;

    # Optimize for Raspberry Pi
    client_max_body_size 100M;
    client_body_buffer_size 128k;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/default

# Configure hostapd for Raspberry Pi WiFi
log "Configuring hostapd for Raspberry Pi..."
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

# Raspberry Pi specific settings
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

# Camera Bridge AP Configuration
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

# Raspberry Pi specific performance optimizations
log "Applying performance optimizations..."

# Increase file system cache
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

# Optimize network settings
cat >> /etc/sysctl.conf << 'EOF'

# Camera Bridge network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 32768 134217728
net.ipv4.tcp_wmem = 4096 32768 134217728
net.core.netdev_max_backlog = 5000
EOF

# Configure log rotation for Raspberry Pi SD card longevity
log "Configuring log rotation..."
cat > /etc/logrotate.d/camera-bridge << 'EOF'
/var/log/camera-bridge/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 640 camerabridge camerabridge
}
EOF

# Set up automatic SD card backup script (optional)
log "Creating SD card maintenance script..."
cat > /opt/camera-bridge/scripts/sd-card-maintenance.sh << 'EOF'
#!/bin/bash

# SD Card maintenance script for Raspberry Pi
# Reduces writes and maintains SD card health

# Move tmp to RAM
if ! grep -q "/tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0" >> /etc/fstab
fi

# Move log files to RAM (optional - reduces logging but improves SD card life)
if [ "$1" == "--minimal-logging" ]; then
    if ! grep -q "/var/log" /etc/fstab; then
        echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,mode=0755,size=100m 0 0" >> /etc/fstab
    fi
fi

# Disable swap if not needed
dphys-swapfile swapoff 2>/dev/null || true
dphys-swapfile uninstall 2>/dev/null || true
systemctl disable dphys-swapfile 2>/dev/null || true

echo "SD card maintenance configured. Reboot to apply changes."
EOF

chmod +x /opt/camera-bridge/scripts/sd-card-maintenance.sh

# Enable services
log "Enabling services..."
systemctl enable nginx
systemctl enable samba
systemctl disable hostapd  # Managed by scripts
systemctl disable dnsmasq  # Managed by scripts

# Set timezone
log "Setting timezone..."
timedatectl set-timezone UTC 2>/dev/null || true

# Create boot configuration for headless operation
log "Creating boot configuration..."
cat >> /boot/firmware/config.txt << 'EOF'

# Camera Bridge optimizations
# Disable camera (saves power and memory)
start_x=0

# GPU memory split (minimal for headless)
gpu_mem=64

# Disable unused features
dtoverlay=disable-bt
dtoverlay=disable-wifi

# Enable GPIO for potential expansion
dtparam=i2c_arm=on
dtparam=spi=on

# Performance governor
# Uncomment for better performance (higher power consumption)
# force_turbo=1
EOF

# Final system optimization
log "Final optimizations..."

# Create swap file if not enough RAM
if [ "$total_ram" -lt 1024 ]; then
    log "Creating swap file for systems with limited RAM..."
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

log "Raspberry Pi installation completed successfully!"
echo ""
echo "Next steps:"
echo "1. Reboot the Raspberry Pi: sudo reboot"
echo "2. Copy camera bridge scripts to /opt/camera-bridge/scripts/"
echo "3. Copy web interface to /opt/camera-bridge/web/"
echo "4. Copy configuration files"
echo "5. Run final setup script"
echo ""
echo "For headless operation:"
echo "- SSH is enabled"
echo "- Connect via ethernet first to get IP address"
echo "- Use camera-bridge-ui for terminal management"
echo ""
echo "Optional optimizations:"
echo "- Run: /opt/camera-bridge/scripts/sd-card-maintenance.sh"
echo "- For minimal logging: /opt/camera-bridge/scripts/sd-card-maintenance.sh --minimal-logging"