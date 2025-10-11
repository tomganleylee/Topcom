#!/bin/bash

# Remote Access Setup Script for Camera Bridge
# Supports Tailscale and Cloudflare Tunnel for long-term remote access

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

show_menu() {
    clear
    echo "🌐 Camera Bridge Remote Access Setup"
    echo "===================================="
    echo ""
    echo "Choose remote access method for long-term deployment:"
    echo ""
    echo "1) Tailscale (Recommended)"
    echo "   - Zero-config VPN mesh network"
    echo "   - Works behind any firewall/NAT"
    echo "   - Mobile apps available"
    echo "   - Free for personal use"
    echo ""
    echo "2) Cloudflare Tunnel"
    echo "   - Secure tunnel without port forwarding"
    echo "   - Web-based access"
    echo "   - Free tier available"
    echo ""
    echo "3) Both (Maximum redundancy)"
    echo "4) Skip remote access setup"
    echo ""
    read -p "Enter choice (1-4): " choice
}

install_tailscale() {
    log "Installing Tailscale..."

    # Download and install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh

    # Configure Tailscale default settings
    log "Configuring Tailscale settings..."
    cat > /etc/default/tailscaled << 'EOF'
# Tailscale daemon configuration
# These settings ensure Tailscale doesn't interfere with existing network

# Set port to 41641 (default Tailscale port) or 0 for auto-select
PORT="41641"

# Optional: You can add flags here if needed
FLAGS=""
EOF

    # Reload systemd if Tailscale service exists
    if systemctl list-unit-files | grep -q tailscaled.service; then
        systemctl daemon-reload
        log "Tailscale service configuration updated"
    fi

    log "Tailscale installed successfully!"
    echo ""
    echo "🔐 TAILSCALE SETUP INSTRUCTIONS:"
    echo "================================="
    echo ""
    echo "1. Run this command to authenticate:"
    echo "   sudo tailscale up"
    echo ""
    echo "2. Open the link in your browser and sign in"
    echo "3. Approve this device in Tailscale admin panel"
    echo "4. Install Tailscale on your other devices"
    echo "5. SSH to this device using Tailscale IP:"
    echo "   ssh tom@[tailscale-ip]"
    echo ""
    echo "📱 Mobile apps: Available on iOS/Android"
    echo "💻 Desktop apps: Available for Windows/Mac/Linux"
    echo ""
    read -p "Press Enter to continue..."
}

install_cloudflare_tunnel() {
    log "Installing Cloudflare Tunnel..."

    # Install cloudflared
    if ! command -v cloudflared >/dev/null 2>&1; then
        log "Downloading cloudflared..."

        # Detect architecture
        ARCH=$(uname -m)
        case $ARCH in
            x86_64)
                ARCH="amd64"
                ;;
            aarch64|arm64)
                ARCH="arm64"
                ;;
            armv7l|armhf)
                ARCH="arm"
                ;;
            *)
                error "Unsupported architecture: $ARCH"
                return 1
                ;;
        esac

        # Download and install
        wget -O /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
        sudo dpkg -i /tmp/cloudflared.deb
        rm /tmp/cloudflared.deb
    fi

    log "Cloudflare Tunnel installed successfully!"
    echo ""
    echo "🌩️  CLOUDFLARE TUNNEL SETUP INSTRUCTIONS:"
    echo "========================================"
    echo ""
    echo "1. Login to Cloudflare (create free account if needed):"
    echo "   cloudflared tunnel login"
    echo ""
    echo "2. Create a tunnel:"
    echo "   cloudflared tunnel create camera-bridge"
    echo ""
    echo "3. Create tunnel configuration:"
    echo "   sudo mkdir -p /etc/cloudflared"
    echo "   sudo nano /etc/cloudflared/config.yml"
    echo ""
    echo "   Add this content:"
    echo "   tunnel: [tunnel-id-from-step-2]"
    echo "   credentials-file: /home/$(whoami)/.cloudflared/[tunnel-id].json"
    echo "   ingress:"
    echo "     - hostname: camera-bridge.yourdomain.com"
    echo "       service: http://localhost:80"
    echo "     - hostname: ssh.camera-bridge.yourdomain.com"
    echo "       service: ssh://localhost:22"
    echo "     - service: http_status:404"
    echo ""
    echo "4. Start tunnel:"
    echo "   cloudflared tunnel run camera-bridge"
    echo ""
    echo "5. Install as service:"
    echo "   sudo cloudflared service install"
    echo ""
    read -p "Press Enter to continue..."
}

configure_ssh_security() {
    log "Configuring SSH security for remote access..."

    # Backup original SSH config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Create secure SSH config
    cat > /tmp/ssh_security.conf << 'EOF'
# Security settings for remote access
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
EOF

    # Apply SSH security settings
    sudo cp /tmp/ssh_security.conf /etc/ssh/sshd_config.d/remote_access_security.conf
    sudo systemctl restart ssh

    log "SSH security configured"
}

setup_firewall() {
    log "Configuring firewall for remote access..."

    # Install ufw if not present
    if ! command -v ufw >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y ufw
    fi

    # Configure UFW
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH
    sudo ufw allow ssh

    # Allow Camera Bridge web interface
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp

    # Allow SMB for local network only
    sudo ufw allow from 192.168.0.0/16 to any port 445
    sudo ufw allow from 10.0.0.0/8 to any port 445
    sudo ufw allow from 172.16.0.0/12 to any port 445

    # Enable firewall
    sudo ufw --force enable

    log "Firewall configured"
}

create_remote_access_info() {
    log "Creating remote access information file..."

    # Get device information
    HOSTNAME=$(hostname)
    LOCAL_IP=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)

    # Create info file
    cat > /opt/camera-bridge/remote-access-info.txt << EOF
Camera Bridge Remote Access Information
======================================
Generated: $(date)
Hostname: $HOSTNAME
Local IP: $LOCAL_IP

SSH Access:
- Username: $(whoami)
- Port: 22

Remote Access Methods Configured:
EOF

    if command -v tailscale >/dev/null 2>&1; then
        echo "- Tailscale: Installed" >> /opt/camera-bridge/remote-access-info.txt
        if tailscale status >/dev/null 2>&1; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not connected")
            echo "  Tailscale IP: $TAILSCALE_IP" >> /opt/camera-bridge/remote-access-info.txt
        fi
    fi

    if command -v cloudflared >/dev/null 2>&1; then
        echo "- Cloudflare Tunnel: Installed" >> /opt/camera-bridge/remote-access-info.txt
    fi

    cat >> /opt/camera-bridge/remote-access-info.txt << EOF

Camera Bridge Services:
- Web Interface: http://[device-ip]/
- Status Page: http://[device-ip]/status.php
- Terminal UI: Run 'sudo /opt/camera-bridge/scripts/terminal-ui.sh'

Emergency Access:
- If WiFi fails, device creates hotspot: CameraBridge-Setup (password: setup123)
- Emergency IP: 192.168.4.1

Important Notes:
- Keep this file for future reference
- Test remote access before deploying internationally
- Both Tailscale and Cloudflare work behind firewalls/NAT
- Consider setting up monitoring/alerts for the remote device
EOF

    sudo chown $(whoami):$(whoami) /opt/camera-bridge/remote-access-info.txt

    log "Remote access info saved to: /opt/camera-bridge/remote-access-info.txt"
}

main() {
    # Check if running as regular user (not root)
    if [ "$EUID" -eq 0 ]; then
        error "Please run this script as a regular user (not root)"
        error "Use: ./setup-remote-access.sh"
        exit 1
    fi

    show_menu

    case $choice in
        1)
            log "Setting up Tailscale..."
            configure_ssh_security
            setup_firewall
            install_tailscale
            create_remote_access_info
            ;;
        2)
            log "Setting up Cloudflare Tunnel..."
            configure_ssh_security
            setup_firewall
            install_cloudflare_tunnel
            create_remote_access_info
            ;;
        3)
            log "Setting up both Tailscale and Cloudflare Tunnel..."
            configure_ssh_security
            setup_firewall
            install_tailscale
            install_cloudflare_tunnel
            create_remote_access_info
            ;;
        4)
            log "Skipping remote access setup"
            exit 0
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac

    echo ""
    echo "🎉 Remote Access Setup Complete!"
    echo "================================"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Complete authentication for chosen service(s)"
    echo "2. Test remote access from another device"
    echo "3. Save connection details securely"
    echo "4. Consider setting up monitoring/alerts"
    echo ""
    echo "📄 Connection details saved to:"
    echo "   /opt/camera-bridge/remote-access-info.txt"
    echo ""
    warn "IMPORTANT: Test remote access thoroughly before international deployment!"
}

main "$@"