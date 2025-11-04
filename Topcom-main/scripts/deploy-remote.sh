#!/bin/bash

# Remote Camera Bridge Deployment Script
# This script deploys Camera Bridge to a remote machine via SSH

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

heading() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <remote-host> [remote-user]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100"
    echo "  $0 camera-bridge-2.local ubuntu"
    echo "  $0 user@hostname"
    exit 1
fi

REMOTE_HOST="$1"
REMOTE_USER="${2:-$USER}"

# Parse user@host format
if [[ "$REMOTE_HOST" == *"@"* ]]; then
    REMOTE_USER="${REMOTE_HOST%%@*}"
    REMOTE_HOST="${REMOTE_HOST#*@}"
fi

SSH_TARGET="${REMOTE_USER}@${REMOTE_HOST}"

heading "Camera Bridge Remote Deployment"
log "Target: $SSH_TARGET"
log "Source: $(hostname)"

# Test SSH connection
heading "Testing SSH Connection"
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_TARGET" "echo 'SSH connection successful'" 2>/dev/null; then
    error "Cannot connect to $SSH_TARGET"
    error "Make sure:"
    error "  1. SSH keys are set up (ssh-copy-id $SSH_TARGET)"
    error "  2. Remote host is reachable"
    error "  3. User has sudo privileges"
    exit 1
fi
log "SSH connection verified ✓"

# Check sudo access
heading "Checking Remote Sudo Access"
if ! ssh "$SSH_TARGET" "sudo -n true" 2>/dev/null; then
    warn "Sudo requires password on remote machine"
    warn "You may be prompted for sudo password during installation"
fi

# Ask for confirmation
heading "Deployment Plan"
echo "This will:"
echo "  1. Clone Camera Bridge repository to remote machine"
echo "  2. Install all required packages"
echo "  3. Configure services (Samba, nginx, dnsmasq)"
echo "  4. Set up network configuration"
echo "  5. Configure auto-start services"
echo ""
warn "NOTE: rclone Dropbox credentials need to be configured manually after installation"
echo ""
read -p "Continue with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Deployment cancelled"
    exit 0
fi

# Step 1: Clone repository
heading "Step 1: Cloning Repository"
log "Cloning Camera Bridge to remote machine..."
ssh "$SSH_TARGET" bash <<'ENDSSH'
set -e
if [ -d /opt/camera-bridge ]; then
    echo "Camera Bridge directory exists, backing up..."
    sudo mv /opt/camera-bridge /opt/camera-bridge.backup.$(date +%Y%m%d_%H%M%S)
fi
cd /tmp
if [ -d Topcom ]; then
    rm -rf Topcom
fi
git clone https://github.com/tomganleylee/Topcom.git
cd Topcom
git checkout master
sudo mv /tmp/Topcom /opt/camera-bridge
ENDSSH
log "Repository cloned ✓"

# Step 2: Run installation script
heading "Step 2: Running Installation Script"
log "Installing packages and configuring system..."
ssh "$SSH_TARGET" bash <<'ENDSSH'
set -e
cd /opt/camera-bridge
sudo bash scripts/install-packages.sh
ENDSSH
log "Installation completed ✓"

# Step 3: Transfer rclone config (optional)
heading "Step 3: Dropbox Configuration"
read -p "Copy rclone Dropbox credentials from this machine? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Copying rclone configuration..."

    # Create remote directory
    ssh "$SSH_TARGET" "sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone"

    # Copy rclone config
    scp /home/camerabridge/.config/rclone/rclone.conf "$SSH_TARGET:/tmp/rclone.conf.tmp"
    ssh "$SSH_TARGET" "sudo mv /tmp/rclone.conf.tmp /home/camerabridge/.config/rclone/rclone.conf && sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf && sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf"

    log "Dropbox credentials copied ✓"

    # Test Dropbox connection
    log "Testing Dropbox connection..."
    if ssh "$SSH_TARGET" "sudo -u camerabridge rclone lsd dropbox:" >/dev/null 2>&1; then
        log "Dropbox connection successful ✓"
    else
        warn "Dropbox connection test failed - may need manual configuration"
    fi
else
    warn "Skipping rclone config transfer"
    warn "You will need to configure Dropbox manually:"
    warn "  ssh $SSH_TARGET"
    warn "  sudo -u camerabridge rclone config"
fi

# Step 4: Network configuration
heading "Step 4: Network Configuration"
log "Detecting remote network interfaces..."
REMOTE_INTERFACES=$(ssh "$SSH_TARGET" "ip -br link show | grep -E 'UP|DOWN' | awk '{print \$1}' | grep -v lo")
log "Remote interfaces found:"
echo "$REMOTE_INTERFACES"
echo ""
warn "Network configuration may need manual adjustment for:"
warn "  - Ethernet interface name (current: eno1)"
warn "  - WiFi interface name (current: wlp1s0)"
warn "  - IP addressing"
echo ""

# Step 5: Start services
heading "Step 5: Starting Services"
log "Enabling and starting camera-bridge services..."
ssh "$SSH_TARGET" bash <<'ENDSSH'
sudo systemctl daemon-reload
sudo systemctl enable camera-bridge
sudo systemctl start camera-bridge
sudo systemctl enable smbd nmbd
sudo systemctl restart smbd nmbd
sudo systemctl enable nginx
sudo systemctl restart nginx
ENDSSH
log "Services started ✓"

# Step 6: Verification
heading "Step 6: Verification"
log "Checking service status..."

SERVICE_STATUS=$(ssh "$SSH_TARGET" "systemctl is-active camera-bridge smbd nmbd nginx dnsmasq" || true)
echo "$SERVICE_STATUS"

log "Checking SMB share..."
ssh "$SSH_TARGET" "ls -la /srv/samba/camera-share" || warn "SMB share directory issue"

# Final summary
heading "Deployment Complete!"
echo "Remote machine: $SSH_TARGET"
echo ""
echo "Services installed:"
echo "  ✓ Camera Bridge sync service"
echo "  ✓ Samba file sharing"
echo "  ✓ DHCP server (dnsmasq)"
echo "  ✓ Web interface (nginx)"
echo "  ✓ WiFi AP support (drivers & configuration)"
echo ""
echo "Next steps:"
echo "  1. SSH to remote: ssh $SSH_TARGET"
echo "  2. Check status: sudo /usr/local/bin/terminal-ui"
echo "  3. Configure WiFi if needed: sudo /opt/camera-bridge/scripts/wifi-manager.sh"
echo "  4. Verify Dropbox: sudo -u camerabridge rclone lsd dropbox:"
echo ""
echo "WiFi Access Point (if USB WiFi adapter available):"
echo "  1. Plug in USB WiFi adapter"
echo "  2. Unplug and replug to load driver"
echo "  3. Start AP: sudo /opt/camera-bridge/scripts/setup-wifi-ap.sh start"
echo "  Details:"
echo "    SSID: CameraBridge-Photos"
echo "    Password: YourSecurePassword123!"
echo "    Guide: /opt/camera-bridge/docs/WIFI-AP-SETUP-GUIDE.md"
echo ""
echo "Web interface: http://$REMOTE_HOST (if on same network)"
echo "SMB share: \\\\$REMOTE_HOST\\photos (username: camera, password: camera123)"
echo ""
log "Deployment completed successfully! 🎉"
ENDSSH
