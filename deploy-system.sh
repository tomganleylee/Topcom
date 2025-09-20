#!/bin/bash

# Camera Bridge Master Deployment Script
# This script automates the complete deployment of Camera Bridge system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_TAILSCALE=${INSTALL_TAILSCALE:-true}
TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY:-}
DROPBOX_SETUP_REQUIRED=${DROPBOX_SETUP_REQUIRED:-true}
AUTO_START_ENABLED=${AUTO_START_ENABLED:-true}

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Camera Bridge Deployment System${NC}"
echo -e "${GREEN}================================${NC}"
echo

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
            log_warn "This script is designed for Ubuntu/Debian. Your OS: $ID"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi

    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connection detected"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Step 1: Install packages
install_packages() {
    log_info "Installing required packages..."

    if [ -f scripts/install-packages.sh ]; then
        ./scripts/install-packages.sh
    else
        # Fallback to manual installation
        apt update
        apt install -y \
            samba \
            nginx \
            php-fpm \
            rclone \
            inotify-tools \
            curl \
            wget \
            git \
            dialog \
            wireless-tools \
            wpasupplicant \
            hostapd \
            dnsmasq
    fi

    log_info "Package installation complete"
}

# Step 2: Create system structure
create_system_structure() {
    log_info "Creating system structure..."

    # Create user
    if ! id -u camerabridge &>/dev/null; then
        useradd -r -s /bin/false camerabridge
        log_info "Created camerabridge user"
    fi

    # Create directories
    mkdir -p /srv/samba/camera-share
    mkdir -p /opt/camera-bridge/{scripts,web,config}
    mkdir -p /var/log/camera-bridge

    # Set permissions
    chown -R camerabridge:camerabridge /srv/samba/camera-share
    chown -R camerabridge:camerabridge /var/log/camera-bridge
    chmod 755 /srv/samba/camera-share

    log_info "System structure created"
}

# Step 3: Copy files
copy_system_files() {
    log_info "Copying system files..."

    # Copy scripts
    cp scripts/*.sh /opt/camera-bridge/scripts/
    chmod +x /opt/camera-bridge/scripts/*.sh
    chown -R camerabridge:camerabridge /opt/camera-bridge/scripts/

    # Copy web interface
    if [ -d web ]; then
        cp -r web/* /opt/camera-bridge/web/
        chown -R www-data:www-data /opt/camera-bridge/web/
    fi

    # Copy configurations
    if [ -d config ]; then
        cp config/* /opt/camera-bridge/config/
    fi

    log_info "System files copied"
}

# Step 4: Configure Samba
configure_samba() {
    log_info "Configuring Samba file sharing..."

    # Backup original config
    if [ -f /etc/samba/smb.conf ] && [ ! -f /etc/samba/smb.conf.backup ]; then
        cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
    fi

    # Apply our configuration
    if [ -f config/smb.conf ]; then
        cp config/smb.conf /etc/samba/smb.conf
    else
        cat > /etc/samba/smb.conf << 'EOF'
[global]
   workgroup = WORKGROUP
   server string = Camera Bridge Server
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   interfaces = 127.0.0.0/8 192.168.0.0/16 10.0.0.0/8
   bind interfaces only = yes

[camera-share]
   comment = Camera Photo Share
   path = /srv/samba/camera-share
   browseable = yes
   read only = no
   create mask = 0755
   directory mask = 0755
   valid users = camera
   force user = camerabridge
   force group = camerabridge
EOF
    fi

    # Create Samba user
    log_info "Setting up Samba user (password: camera)..."
    echo -e "camera\ncamera" | smbpasswd -a -s camera 2>/dev/null || true

    # Restart Samba
    systemctl restart smbd
    systemctl enable smbd

    log_info "Samba configuration complete"
}

# Step 5: Configure Nginx
configure_nginx() {
    log_info "Configuring Nginx web server..."

    # Copy configuration
    if [ -f config/nginx-camera-bridge.conf ]; then
        cp config/nginx-camera-bridge.conf /etc/nginx/sites-available/camera-bridge
    else
        cat > /etc/nginx/sites-available/camera-bridge << 'EOF'
server {
    listen 80;
    server_name _;

    root /opt/camera-bridge/web;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    fi

    # Enable site
    ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Test and reload
    nginx -t
    systemctl reload nginx
    systemctl enable nginx

    log_info "Nginx configuration complete"
}

# Step 6: Install systemd services
install_services() {
    log_info "Installing systemd services..."

    # Copy service files
    if [ -f config/camera-bridge.service ]; then
        cp config/camera-bridge.service /etc/systemd/system/
    fi

    if [ -f config/dropbox-token-refresh.service ]; then
        cp config/dropbox-token-refresh.service /etc/systemd/system/
        cp config/dropbox-token-refresh.timer /etc/systemd/system/
    fi

    # Reload systemd
    systemctl daemon-reload

    # Enable services (but don't start yet)
    systemctl enable camera-bridge.service
    systemctl enable dropbox-token-refresh.timer

    log_info "Services installed"
}

# Step 7: Configure Dropbox
configure_dropbox() {
    if [ "$DROPBOX_SETUP_REQUIRED" = "true" ]; then
        log_warn "Dropbox configuration required"
        echo
        echo "Please run the following command to configure Dropbox:"
        echo "  sudo -u camerabridge rclone config"
        echo
        echo "Configuration steps:"
        echo "1. Type 'n' for new remote"
        echo "2. Name it: dropbox"
        echo "3. Choose Dropbox from the list"
        echo "4. Leave client_id and secret blank"
        echo "5. Follow the OAuth2 authorization"
        echo
        read -p "Press Enter when Dropbox configuration is complete..."

        # Test connection
        if sudo -u camerabridge rclone lsd dropbox: &>/dev/null; then
            log_info "Dropbox connection successful"
        else
            log_error "Dropbox connection failed. Please configure manually later."
        fi
    fi
}

# Step 8: Setup auto-start
setup_autostart() {
    if [ "$AUTO_START_ENABLED" = "true" ]; then
        log_info "Setting up auto-start..."

        if [ -f deployment/autostart/setup-camera-bridge-autostart.sh ]; then
            ./deployment/autostart/setup-camera-bridge-autostart.sh
        fi

        log_info "Auto-start configured"
    fi
}

# Step 9: Install Tailscale
install_tailscale() {
    if [ "$INSTALL_TAILSCALE" = "true" ]; then
        log_info "Installing Tailscale for remote access..."

        if [ -f deployment/tailscale/install-tailscale-safe.sh ]; then
            ./deployment/tailscale/install-tailscale-safe.sh
        fi

        if [ -n "$TAILSCALE_AUTH_KEY" ]; then
            log_info "Configuring Tailscale with auth key..."
            tailscale up \
                --authkey="$TAILSCALE_AUTH_KEY" \
                --accept-routes=false \
                --accept-dns=false \
                --advertise-routes= \
                --ssh \
                --hostname="$(hostname)"
        else
            log_warn "No Tailscale auth key provided. Manual configuration required."
            echo "Run: sudo tailscale up --accept-routes=false --accept-dns=false --ssh"
        fi

        # Setup permanent connection
        if [ -f deployment/tailscale/tailscale-permanent-setup.sh ]; then
            ./deployment/tailscale/tailscale-permanent-setup.sh
        fi

        log_info "Tailscale installation complete"
    fi
}

# Step 10: Start services
start_services() {
    log_info "Starting services..."

    systemctl start camera-bridge
    systemctl start dropbox-token-refresh.timer

    # Check status
    if systemctl is-active --quiet camera-bridge; then
        log_info "Camera Bridge service is running"
    else
        log_warn "Camera Bridge service failed to start"
    fi

    if systemctl is-active --quiet smbd; then
        log_info "Samba service is running"
    else
        log_warn "Samba service failed to start"
    fi

    if systemctl is-active --quiet nginx; then
        log_info "Nginx service is running"
    else
        log_warn "Nginx service failed to start"
    fi
}

# Step 11: Show summary
show_summary() {
    echo
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo

    # Get IP addresses
    LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)

    echo "Access Information:"
    echo "==================="
    echo
    echo "Web Interface:"
    echo "  Local: http://$LOCAL_IP"

    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
        TS_IP=$(tailscale ip -4 2>/dev/null)
        if [ -n "$TS_IP" ]; then
            echo "  Tailscale: http://$TS_IP"
            echo
            echo "SSH Access:"
            echo "  ssh $(whoami)@$TS_IP"
        fi
    fi

    echo
    echo "SMB Share:"
    echo "  Windows: \\\\$LOCAL_IP\\camera-share"
    echo "  Linux: smb://$LOCAL_IP/camera-share"
    echo "  Credentials: username 'camera', password 'camera'"
    echo
    echo "Service Management:"
    echo "  Status: systemctl status camera-bridge"
    echo "  Logs: tail -f /var/log/camera-bridge/service.log"
    echo "  Sync now: /opt/camera-bridge/scripts/sync-now.sh"
    echo

    if [ "$DROPBOX_SETUP_REQUIRED" = "true" ]; then
        echo -e "${YELLOW}Remember to:${NC}"
        echo "1. Configure Dropbox if not already done:"
        echo "   sudo -u camerabridge rclone config"
        echo
    fi

    if [ "$INSTALL_TAILSCALE" = "true" ] && [ -z "$TAILSCALE_AUTH_KEY" ]; then
        echo "2. Complete Tailscale setup:"
        echo "   sudo tailscale up --accept-routes=false --accept-dns=false --ssh"
        echo "   Then disable key expiry at: https://login.tailscale.com/admin/machines"
        echo
    fi
}

# Main execution
main() {
    check_prerequisites
    install_packages
    create_system_structure
    copy_system_files
    configure_samba
    configure_nginx
    install_services
    configure_dropbox
    setup_autostart
    install_tailscale
    start_services
    show_summary
}

# Handle command line arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --no-tailscale     Skip Tailscale installation"
        echo "  --no-autostart     Skip auto-start configuration"
        echo "  --skip-dropbox     Skip Dropbox configuration"
        echo "  --help             Show this help message"
        echo
        echo "Environment variables:"
        echo "  TAILSCALE_AUTH_KEY Set to auto-configure Tailscale"
        echo
        echo "Example:"
        echo "  TAILSCALE_AUTH_KEY='tskey-auth-XXX' sudo ./deploy-system.sh"
        exit 0
        ;;
    --no-tailscale)
        INSTALL_TAILSCALE=false
        ;;
    --no-autostart)
        AUTO_START_ENABLED=false
        ;;
    --skip-dropbox)
        DROPBOX_SETUP_REQUIRED=false
        ;;
esac

# Run main deployment
main

log_info "Deployment script completed!"