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

# Detect if this is an update or fresh installation
EXISTING_INSTALLATION=false
if [ -d "/opt/camera-bridge" ] && [ -f "/opt/camera-bridge/scripts/camera-bridge-service.sh" ]; then
    EXISTING_INSTALLATION=true
    log "Existing Camera Bridge installation detected - updating files..."
else
    log "Fresh installation - copying Camera Bridge files..."
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Smart file copying with update detection
update_scripts() {
    log "Updating scripts..."

    # Check for newer files and copy them
    for script_file in "$PROJECT_DIR"/scripts/*.sh; do
        script_name=$(basename "$script_file")
        target_file="/opt/camera-bridge/scripts/$script_name"

        if [ ! -f "$target_file" ] || [ "$script_file" -nt "$target_file" ]; then
            log "  → Updating $script_name"
            cp "$script_file" "$target_file"
        fi
    done

    chmod +x /opt/camera-bridge/scripts/*.sh
}

update_web_files() {
    log "Updating web interface..."

    # Check for newer web files and copy them
    for web_file in "$PROJECT_DIR"/web/*.php; do
        web_name=$(basename "$web_file")
        target_file="/opt/camera-bridge/web/$web_name"

        if [ ! -f "$target_file" ] || [ "$web_file" -nt "$target_file" ]; then
            log "  → Updating $web_name"
            cp "$web_file" "$target_file"
        fi
    done
}

update_config_files() {
    log "Updating configuration templates..."

    if [ -d "$PROJECT_DIR/config" ]; then
        for config_file in "$PROJECT_DIR"/config/*; do
            if [ -f "$config_file" ]; then
                config_name=$(basename "$config_file")
                target_file="/opt/camera-bridge/config/$config_name"

                # Only update config templates if they don't exist (preserve user configs)
                if [ ! -f "$target_file" ]; then
                    log "  → Adding new config template: $config_name"
                    cp "$config_file" "$target_file"
                fi
            fi
        done
    fi
}

# Execute file updates
if [ "$EXISTING_INSTALLATION" = true ]; then
    log "Performing smart update of existing installation..."
    update_scripts
    update_web_files
    update_config_files
    log "✓ Files updated successfully"
else
    log "Performing fresh installation file copy..."
    # Copy scripts
    cp "$PROJECT_DIR"/scripts/*.sh /opt/camera-bridge/scripts/
    chmod +x /opt/camera-bridge/scripts/*.sh

    # Copy web interface
    cp "$PROJECT_DIR"/web/*.php /opt/camera-bridge/web/

    # Copy configuration templates
    if [ -d "$PROJECT_DIR/config" ]; then
        cp "$PROJECT_DIR"/config/* /opt/camera-bridge/config/ 2>/dev/null || true
    fi
    log "✓ Files copied successfully"
fi

# Set ownership
chown -R camerabridge:camerabridge /srv/samba/camera-share
chown -R camerabridge:camerabridge /var/log/camera-bridge
chown -R www-data:www-data /opt/camera-bridge/web

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

# Enable Samba/SMB service (different names on different systems)
if systemctl list-unit-files | grep -q "^smbd.service"; then
    systemctl enable smbd
    log "Enabled smbd.service"
elif systemctl list-unit-files | grep -q "^samba.service.*enabled"; then
    systemctl enable samba
    log "Enabled samba.service"
else
    log "WARNING: Could not find Samba service to enable"
fi

systemctl disable hostapd  # Will be managed by scripts
systemctl disable dnsmasq  # Will be managed by scripts

# Setup seamless user experience
log "Setting up seamless user experience..."

BOOT_SETUP_SUCCESS=false
LOGIN_SETUP_SUCCESS=false
AUTOSTART_SETUP_SUCCESS=false

# Setup boot splash
if [ -f "$SCRIPT_DIR/setup-boot-splash.sh" ]; then
    log "Configuring boot splash screen..."
    if "$SCRIPT_DIR/setup-boot-splash.sh" enable; then
        log "✓ Boot splash screen configured successfully"
        BOOT_SETUP_SUCCESS=true
    else
        log "✗ Boot splash setup failed"
    fi
else
    log "✗ Boot splash script not found: $SCRIPT_DIR/setup-boot-splash.sh"
fi

# Setup auto-login
if [ -f "$SCRIPT_DIR/setup-auto-login.sh" ]; then
    log "Configuring auto-login..."
    if "$SCRIPT_DIR/setup-auto-login.sh" enable; then
        log "✓ Auto-login configured successfully"
        LOGIN_SETUP_SUCCESS=true
    else
        log "✗ Auto-login setup failed"
    fi
else
    log "✗ Auto-login script not found: $SCRIPT_DIR/setup-auto-login.sh"
fi

# Setup autostart script
if [ -f "$SCRIPT_DIR/camera-bridge-autostart.sh" ]; then
    log "Installing autostart script..."
    if cp "$SCRIPT_DIR/camera-bridge-autostart.sh" /usr/local/bin/camera-bridge-autostart && \
       chmod +x /usr/local/bin/camera-bridge-autostart; then
        log "✓ Autostart script installed successfully"
        AUTOSTART_SETUP_SUCCESS=true
    else
        log "✗ Autostart script installation failed"
    fi
else
    log "✗ Autostart script not found: $SCRIPT_DIR/camera-bridge-autostart.sh"
fi

# Install terminal UI scripts
log "Installing terminal UI scripts..."
if [ -f "$SCRIPT_DIR/terminal-ui.sh" ]; then
    cp "$SCRIPT_DIR/terminal-ui.sh" /usr/local/bin/camera-bridge-ui
    chmod +x /usr/local/bin/camera-bridge-ui
    log "✓ Terminal UI script installed"
fi

if [ -f "$SCRIPT_DIR/terminal-ui-enhanced.sh" ]; then
    cp "$SCRIPT_DIR/terminal-ui-enhanced.sh" /usr/local/bin/terminal-ui-enhanced
    chmod +x /usr/local/bin/terminal-ui-enhanced
    log "✓ Enhanced terminal UI script installed"
fi

# Install remote access setup script
if [ -f "$SCRIPT_DIR/setup-remote-access.sh" ]; then
    cp "$SCRIPT_DIR/setup-remote-access.sh" /usr/local/bin/setup-remote-access
    chmod +x /usr/local/bin/setup-remote-access
    log "✓ Remote access setup script installed"
fi

if [ "$EXISTING_INSTALLATION" = true ]; then
    log "Camera Bridge update completed successfully!"
    echo ""
    echo "=========================================="
    echo "📦 UPDATE SUMMARY"
    echo "=========================================="
    echo "✓ Scripts and web files updated"
    echo "✓ Enhanced QR code token entry available"
    echo "✓ Improved WiFi management"
    echo "✓ User configurations preserved"
else
    log "Installation completed successfully!"
    echo ""
    echo "=========================================="
fi
echo "📷 CAMERA BRIDGE INSTALLATION COMPLETE"
echo "=========================================="
echo ""
echo "Core Services Status:"
echo "  ✓ SMB file sharing (smbd, nmbd)"
echo "  ✓ Web server (nginx)"
echo "  ✓ User accounts (camerabridge, camera)"
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
        echo "  sudo $SCRIPT_DIR/setup-boot-splash.sh enable"
        echo ""
    fi

    if [ "$LOGIN_SETUP_SUCCESS" = false ]; then
        echo "Enable auto-login:"
        echo "  sudo $SCRIPT_DIR/setup-auto-login.sh enable"
        echo ""
    fi

    if [ "$AUTOSTART_SETUP_SUCCESS" = false ]; then
        echo "Install autostart script:"
        echo "  sudo cp $SCRIPT_DIR/camera-bridge-autostart.sh /usr/local/bin/camera-bridge-autostart"
        echo "  sudo chmod +x /usr/local/bin/camera-bridge-autostart"
        echo ""
    fi

    echo "Verify setup:"
    echo "  sudo $SCRIPT_DIR/setup-auto-login.sh status"
    echo "  sudo $SCRIPT_DIR/setup-boot-splash.sh status"
    echo "  ls -la /usr/local/bin/camera-bridge-autostart"
    echo ""
fi

echo "Next Steps:"
echo "1. Complete any manual setup commands above (if needed)"
echo "2. Setup remote access for deployment: setup-remote-access"
echo "3. Reboot to experience seamless boot: sudo reboot"
echo "4. Access web interface: http://$(hostname -I | awk '{print $1}')"
echo "5. Configure Dropbox via terminal UI or web interface"
echo ""
echo "On reboot, you should see:"
echo "  → Custom Camera Bridge boot splash"
echo "  → Automatic login as camerabridge user"
echo "  → Welcome banner with system status"
echo "  → Terminal UI auto-start"