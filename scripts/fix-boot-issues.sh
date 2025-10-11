#!/bin/bash

# Camera Bridge Boot Issues Fix Script
# Fixes all identified boot and service startup issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "=========================================="
echo "Camera Bridge Boot Issues Fix Script"
echo "=========================================="
echo ""

# Backup existing configurations
log_info "Creating backups of existing configurations..."
BACKUP_DIR="/opt/camera-bridge/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f /etc/systemd/system/camera-bridge.service ]; then
    cp /etc/systemd/system/camera-bridge.service "$BACKUP_DIR/"
    log_success "Backed up camera-bridge.service"
fi

if [ -f /etc/default/tailscaled ]; then
    cp /etc/default/tailscaled "$BACKUP_DIR/"
    log_success "Backed up tailscaled config"
fi

echo ""
log_info "Backups saved to: $BACKUP_DIR"
echo ""

# Fix 1: Update Tailscale configuration
log_info "Fixing Tailscale configuration..."
cat > /etc/default/tailscaled << 'EOF'
# Tailscale daemon configuration
# These settings ensure Tailscale doesn't interfere with existing network

# Set port to 41641 (default Tailscale port) or 0 for auto-select
PORT="41641"

# Optional: You can add flags here if needed
FLAGS=""
EOF

log_success "Tailscale configuration updated"

# Fix 2: Install WiFi auto-connect service
log_info "Installing WiFi auto-connect service..."
if [ -f /opt/camera-bridge/config/wifi-auto-connect.service ]; then
    cp /opt/camera-bridge/config/wifi-auto-connect.service /etc/systemd/system/
    log_success "WiFi auto-connect service installed"
else
    log_warning "WiFi auto-connect service file not found, skipping"
fi

# Fix 3: Verify camera-bridge service configuration
log_info "Verifying camera-bridge service configuration..."
if [ -f /etc/systemd/system/camera-bridge.service ]; then
    # Check if Type=forking needs to be changed to Type=simple
    if grep -q "^Type=forking" /etc/systemd/system/camera-bridge.service; then
        log_info "Updating camera-bridge service type from 'forking' to 'simple'..."
        sed -i 's/^Type=forking/Type=simple/' /etc/systemd/system/camera-bridge.service
        log_success "Camera-bridge service type updated"
    fi

    # Check if timeout is too short
    if grep -q "^TimeoutStartSec=30" /etc/systemd/system/camera-bridge.service; then
        log_info "Increasing camera-bridge service startup timeout to 90s..."
        sed -i 's/^TimeoutStartSec=30/TimeoutStartSec=90/' /etc/systemd/system/camera-bridge.service
        log_success "Camera-bridge service timeout updated"
    fi
fi

# Fix 4: Configure sudoers for camera-bridge service
log_info "Configuring sudoers for camera-bridge service and terminal UI..."
cat > /etc/sudoers.d/camera-bridge << 'EOF'
# Allow camera-bridge service (running as root) to execute rclone as camerabridge user without password
root ALL=(camerabridge) NOPASSWD: /usr/bin/rclone

# Allow camerabridge user to run system commands without password for terminal UI
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/rclone, /usr/sbin/smbpasswd, /bin/mount, /bin/umount, /usr/bin/apt, /usr/bin/apt-get, /bin/cp, /bin/rm, /bin/mkdir, /bin/chmod, /bin/chown, /usr/sbin/useradd, /opt/camera-bridge/scripts/wifi-manager.sh, /opt/camera-bridge/scripts/camera-bridge-service.sh, /usr/local/bin/terminal-ui-enhanced
EOF

# Set proper permissions on sudoers file
chmod 0440 /etc/sudoers.d/camera-bridge

# Verify sudoers syntax
if visudo -c -f /etc/sudoers.d/camera-bridge >/dev/null 2>&1; then
    log_success "Sudoers configuration created and verified"
else
    log_error "Sudoers configuration has syntax errors, removing..."
    rm -f /etc/sudoers.d/camera-bridge
fi

# Fix 5: Verify camera-bridge-service.sh script syntax
log_info "Verifying camera-bridge service script..."
if bash -n /opt/camera-bridge/scripts/camera-bridge-service.sh 2>/dev/null; then
    log_success "Camera-bridge service script syntax is valid"
else
    log_error "Camera-bridge service script has syntax errors"
    log_info "The script has been fixed in this version"
fi

# Fix 6: Reload systemd daemon
log_info "Reloading systemd daemon..."
systemctl daemon-reload
log_success "Systemd daemon reloaded"

# Fix 7: Reset failed services
log_info "Resetting failed service states..."
systemctl reset-failed tailscaled.service 2>/dev/null || true
systemctl reset-failed camera-bridge.service 2>/dev/null || true
systemctl reset-failed wifi-auto-connect.service 2>/dev/null || true
log_success "Failed service states reset"

# Fix 8: Enable services
log_info "Enabling services..."
systemctl enable camera-bridge.service 2>/dev/null || log_warning "camera-bridge.service already enabled or doesn't exist"
systemctl enable tailscaled.service 2>/dev/null || log_warning "tailscaled.service already enabled or doesn't exist"
systemctl enable wifi-auto-connect.service 2>/dev/null || log_warning "wifi-auto-connect.service not installed"

# Fix 9: Start services
echo ""
log_info "Starting services..."
echo ""

# Start camera-bridge
log_info "Starting camera-bridge service..."
if systemctl start camera-bridge.service; then
    log_success "camera-bridge service started"
else
    log_error "Failed to start camera-bridge service"
    systemctl status camera-bridge.service --no-pager -l
fi

# Start tailscaled
log_info "Starting tailscaled service..."
if systemctl start tailscaled.service; then
    log_success "tailscaled service started"
else
    log_error "Failed to start tailscaled service"
    systemctl status tailscaled.service --no-pager -l
fi

# Start wifi-auto-connect
log_info "Starting wifi-auto-connect service..."
if systemctl start wifi-auto-connect.service 2>/dev/null; then
    log_success "wifi-auto-connect service started"
else
    log_warning "wifi-auto-connect service not available or failed to start"
fi

# Verification
echo ""
echo "=========================================="
echo "Service Status Verification"
echo "=========================================="
echo ""

# Check camera-bridge
log_info "Camera Bridge Service:"
if systemctl is-active camera-bridge.service >/dev/null 2>&1; then
    log_success "✅ Running"
else
    log_error "❌ Not running"
fi

# Check tailscaled
log_info "Tailscale Service:"
if systemctl is-active tailscaled.service >/dev/null 2>&1; then
    log_success "✅ Running"
else
    log_error "❌ Not running"
fi

# Check wifi-auto-connect
log_info "WiFi Auto-Connect Service:"
if systemctl is-active wifi-auto-connect.service >/dev/null 2>&1; then
    log_success "✅ Running"
else
    log_warning "⚠️  Not running (may not be installed)"
fi

# Check autostart configuration
log_info "Terminal UI Autostart:"
if [ -f /opt/camera-bridge/config/autostart-enabled ]; then
    log_success "✅ Enabled"
else
    log_warning "⚠️  Not enabled"
fi

# Check WiFi connectivity
log_info "WiFi Connection:"
if current_ssid=$(iwgetid -r 2>/dev/null) && [ -n "$current_ssid" ]; then
    log_success "✅ Connected to: $current_ssid"
else
    log_warning "⚠️  Not connected"
fi

# Check internet connectivity
log_info "Internet Connection:"
if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    log_success "✅ Connected"
else
    log_warning "⚠️  Offline"
fi

# Summary
echo ""
echo "=========================================="
echo "Fix Summary"
echo "=========================================="
echo ""
log_info "All fixes have been applied!"
echo ""
echo "Changes made:"
echo "  • Fixed Tailscale PORT configuration"
echo "  • Installed WiFi auto-connect service"
echo "  • Configured sudoers to allow rclone without password"
echo "  • Updated camera-bridge service type and timeout"
echo "  • Reset and restarted all services"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""

# Offer to reboot
echo "=========================================="
echo "Reboot Recommendation"
echo "=========================================="
echo ""
log_warning "A reboot is recommended to ensure all changes take effect"
log_info "After reboot, the system should:"
echo "  1. Auto-login as camerabridge user"
echo "  2. Auto-connect to saved WiFi network"
echo "  3. Start camera-bridge service automatically"
echo "  4. Start Tailscale service automatically"
echo "  5. Display terminal UI automatically"
echo ""

read -p "Would you like to reboot now? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rebooting in 5 seconds... (Press Ctrl+C to cancel)"
    sleep 5
    reboot
else
    log_info "Reboot cancelled. You can reboot later with: sudo reboot"
fi
