#!/bin/bash

# Camera Bridge Installation Verification Script
# Checks if all components are properly installed and configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "=========================================="
echo "📷 CAMERA BRIDGE INSTALLATION VERIFICATION"
echo "=========================================="
echo ""

# Check core services
echo "Core Services:"
if systemctl is-enabled smbd >/dev/null 2>&1; then
    log_success "SMB daemon (smbd) is enabled"
else
    log_error "SMB daemon (smbd) is not enabled"
fi

if systemctl is-enabled nmbd >/dev/null 2>&1; then
    log_success "NetBIOS daemon (nmbd) is enabled"
else
    log_error "NetBIOS daemon (nmbd) is not enabled"
fi

if systemctl is-enabled nginx >/dev/null 2>&1; then
    log_success "Web server (nginx) is enabled"
else
    log_error "Web server (nginx) is not enabled"
fi

echo ""

# Check users
echo "User Accounts:"
if id camerabridge >/dev/null 2>&1; then
    log_success "User 'camerabridge' exists"

    # Check if user has sudo privileges
    if groups camerabridge | grep -q sudo; then
        log_success "User 'camerabridge' has sudo privileges"
    else
        log_warning "User 'camerabridge' does not have sudo privileges"
    fi
else
    log_error "User 'camerabridge' does not exist"
fi

if id camera >/dev/null 2>&1; then
    log_success "User 'camera' exists"
else
    log_error "User 'camera' does not exist"
fi

echo ""

# Check seamless boot components
echo "Seamless Boot Experience:"

# Check auto-login
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ] || \
   [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
    log_success "Auto-login is configured"

    # Check which user auto-login is configured for
    if grep -q "camerabridge" /etc/systemd/system/getty@tty1.service.d/* 2>/dev/null; then
        log_success "Auto-login configured for 'camerabridge' user"
    else
        log_warning "Auto-login configured but not for 'camerabridge' user"
    fi
else
    log_error "Auto-login is not configured"
fi

# Check boot splash
if [ -f /etc/systemd/system/camera-bridge-splash.service ]; then
    log_success "Boot splash service exists"

    if systemctl is-enabled camera-bridge-splash >/dev/null 2>&1; then
        log_success "Boot splash service is enabled"
    else
        log_error "Boot splash service is not enabled"
    fi
else
    log_error "Boot splash service does not exist"
fi

if [ -f /usr/local/bin/camera-bridge-splash ]; then
    log_success "Boot splash script is installed"
else
    log_error "Boot splash script is not installed"
fi

# Check autostart script
if [ -f /usr/local/bin/camera-bridge-autostart ]; then
    log_success "Autostart script is installed"

    if [ -x /usr/local/bin/camera-bridge-autostart ]; then
        log_success "Autostart script is executable"
    else
        log_error "Autostart script is not executable"
    fi
else
    log_error "Autostart script is not installed"
fi

# Check autostart configuration
if [ -f /opt/camera-bridge/config/autostart-enabled ]; then
    log_success "Autostart is enabled"
else
    log_warning "Autostart control file not found (will be created on first use)"
fi

# Check user profile configuration
if [ -f /home/camerabridge/.profile ]; then
    if grep -q "camera-bridge-autostart" /home/camerabridge/.profile; then
        log_success "User profile configured for autostart"
    else
        log_error "User profile not configured for autostart"
    fi
else
    log_warning "User profile does not exist"
fi

echo ""

# Check directories and permissions
echo "Directories and Permissions:"

if [ -d /opt/camera-bridge ]; then
    log_success "Camera bridge directory exists (/opt/camera-bridge)"

    if [ -O /opt/camera-bridge ] || [ "$(stat -c %U /opt/camera-bridge)" = "camerabridge" ]; then
        log_success "Camera bridge directory has correct ownership"
    else
        log_warning "Camera bridge directory ownership may be incorrect"
    fi
else
    log_warning "Camera bridge directory does not exist (/opt/camera-bridge)"
fi

if [ -d /var/log/camera-bridge ]; then
    log_success "Log directory exists (/var/log/camera-bridge)"
else
    log_warning "Log directory does not exist (/var/log/camera-bridge)"
fi

echo ""

# Network and connectivity tests
echo "Network Configuration:"

# Check if system has an IP address
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
if [ -n "$IP" ]; then
    log_success "System has IP address: $IP"
    echo "  Web interface will be available at: http://$IP"
else
    log_warning "System does not have an IP address"
fi

# Check internet connectivity
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "Internet connectivity: Available"
else
    log_warning "Internet connectivity: Not available"
fi

echo ""

# Summary and recommendations
echo "=========================================="
echo "SUMMARY AND RECOMMENDATIONS"
echo "=========================================="

# Count successful checks
SUCCESS_COUNT=0
TOTAL_CHECKS=0

# Core services (3 checks)
systemctl is-enabled smbd >/dev/null 2>&1 && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
systemctl is-enabled nmbd >/dev/null 2>&1 && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
systemctl is-enabled nginx >/dev/null 2>&1 && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
TOTAL_CHECKS=$((TOTAL_CHECKS + 3))

# Users (2 checks)
id camerabridge >/dev/null 2>&1 && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
id camera >/dev/null 2>&1 && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
TOTAL_CHECKS=$((TOTAL_CHECKS + 2))

# Seamless boot (4 main checks)
([ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ] || \
 [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]) && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
[ -f /etc/systemd/system/camera-bridge-splash.service ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
[ -f /usr/local/bin/camera-bridge-splash ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
[ -f /usr/local/bin/camera-bridge-autostart ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
TOTAL_CHECKS=$((TOTAL_CHECKS + 4))

echo "Installation Status: $SUCCESS_COUNT/$TOTAL_CHECKS components configured correctly"

if [ $SUCCESS_COUNT -eq $TOTAL_CHECKS ]; then
    echo ""
    log_success "Installation appears to be complete!"
    echo ""
    echo "Ready to reboot and test seamless boot experience:"
    echo "  sudo reboot"
    echo ""
elif [ $SUCCESS_COUNT -ge 5 ]; then
    echo ""
    log_warning "Core installation complete, but seamless boot needs manual setup"
    echo ""
    echo "Run these commands to complete seamless boot setup:"

    if ! ([ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ] || \
          [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]); then
        echo "  sudo ./scripts/setup-auto-login.sh enable"
    fi

    if [ ! -f /etc/systemd/system/camera-bridge-splash.service ]; then
        echo "  sudo ./scripts/setup-boot-splash.sh enable"
    fi

    if [ ! -f /usr/local/bin/camera-bridge-autostart ]; then
        echo "  sudo cp scripts/camera-bridge-autostart.sh /usr/local/bin/camera-bridge-autostart"
        echo "  sudo chmod +x /usr/local/bin/camera-bridge-autostart"
    fi

    echo ""
    echo "Then reboot: sudo reboot"
    echo ""
else
    echo ""
    log_error "Installation appears incomplete"
    echo ""
    echo "Consider running the installation script again:"
    echo "  sudo ./scripts/install-packages.sh"
    echo ""
fi

# Quick test commands
echo "Quick Test Commands:"
echo "  Verify setup:       $0"
echo "  Test autostart:     sudo -u camerabridge /usr/local/bin/camera-bridge-autostart"
echo "  Check auto-login:   sudo ./scripts/setup-auto-login.sh status"
echo "  Check boot splash:  sudo ./scripts/setup-boot-splash.sh status"
echo "  View logs:          sudo tail -f /var/log/camera-bridge/setup.log"

echo ""
echo "For support, check the documentation in docs/ directory"