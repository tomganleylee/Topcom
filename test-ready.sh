#!/bin/bash

# Quick readiness test for Camera Bridge

echo "🔍 Camera Bridge Readiness Check"
echo "================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

READY=true

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    READY=false
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check SMB services
echo "Checking SMB Services..."
if systemctl is-active --quiet smbd; then
    check_pass "SMB daemon (smbd) is running"
else
    check_fail "SMB daemon (smbd) is NOT running"
fi

if systemctl is-active --quiet nmbd; then
    check_pass "NetBIOS daemon (nmbd) is running"
else
    check_fail "NetBIOS daemon (nmbd) is NOT running"
fi

# 2. Check SMB user
echo ""
echo "Checking SMB User..."
if id "camera" &>/dev/null; then
    check_pass "SMB user 'camera' exists"
else
    check_fail "SMB user 'camera' does NOT exist"
fi

# 3. Check SMB share directory
echo ""
echo "Checking SMB Share..."
if [ -d "/srv/samba/camera-share" ]; then
    check_pass "SMB share directory exists: /srv/samba/camera-share"

    # Check permissions
    SHARE_OWNER=$(stat -c '%U' /srv/samba/camera-share)
    if [ "$SHARE_OWNER" = "camera" ] || [ "$SHARE_OWNER" = "camerabridge" ]; then
        check_pass "Share directory has correct ownership"
    else
        check_warn "Share directory owner is '$SHARE_OWNER' (expected 'camera' or 'camerabridge')"
    fi
else
    check_fail "SMB share directory does NOT exist"
fi

# 4. Check if photos share is configured
echo ""
echo "Checking SMB Configuration..."
if grep -q "\[photos\]" /etc/samba/smb.conf 2>/dev/null; then
    check_pass "Photos share is configured in smb.conf"
else
    check_fail "Photos share NOT found in smb.conf"
fi

# 5. Check camera-bridge service
echo ""
echo "Checking Camera Bridge Service..."
if [ -f "/etc/systemd/system/camera-bridge.service" ]; then
    check_pass "Camera bridge service is installed"

    if systemctl is-enabled --quiet camera-bridge 2>/dev/null; then
        check_pass "Camera bridge service is enabled"
    else
        check_warn "Camera bridge service is not enabled"
    fi

    if systemctl is-active --quiet camera-bridge; then
        check_pass "Camera bridge service is running"
    else
        check_warn "Camera bridge service is not running (start with: sudo systemctl start camera-bridge)"
    fi
else
    check_fail "Camera bridge service is NOT installed"
fi

# 6. Check Dropbox/rclone configuration
echo ""
echo "Checking Dropbox Configuration..."
if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
    if sudo -u camerabridge rclone listremotes 2>/dev/null | grep -q "dropbox:"; then
        check_pass "Dropbox is configured in rclone"

        # Test connection
        if sudo -u camerabridge rclone lsd dropbox: &>/dev/null; then
            check_pass "Dropbox connection is working"
        else
            check_fail "Cannot connect to Dropbox (check token)"
        fi
    else
        check_fail "Dropbox remote not found in rclone config"
    fi
else
    check_fail "rclone configuration not found for camerabridge user"
fi

# 7. Check network
echo ""
echo "Checking Network..."
IP=$(hostname -I | awk '{print $1}')
if [ -n "$IP" ]; then
    check_pass "Network is configured. IP: $IP"
else
    check_warn "No IP address found"
fi

# Final assessment
echo ""
echo "================================="
if [ "$READY" = true ]; then
    echo -e "${GREEN}✅ SYSTEM IS READY FOR TESTING!${NC}"
    echo ""
    echo "Test Instructions:"
    echo "1. Connect your laptop to the network"
    echo "2. Access SMB share: \\\\${IP}\\photos"
    echo "3. Use credentials: camera / camera123"
    echo "4. Drop a photo file into the share"
    echo "5. Check Dropbox for synced files"
    echo ""
    echo "Monitor sync activity:"
    echo "  sudo journalctl -u camera-bridge -f"
else
    echo -e "${RED}❌ SYSTEM NEEDS CONFIGURATION${NC}"
    echo ""
    echo "Required Actions:"

    if ! systemctl is-active --quiet smbd || ! systemctl is-active --quiet nmbd; then
        echo "• Start SMB services: sudo systemctl start smbd nmbd"
    fi

    if ! id "camera" &>/dev/null; then
        echo "• Create SMB user: sudo ./scripts/install-packages.sh"
    fi

    if ! [ -d "/srv/samba/camera-share" ]; then
        echo "• Create share directory: sudo mkdir -p /srv/samba/camera-share"
    fi

    if ! grep -q "\[photos\]" /etc/samba/smb.conf 2>/dev/null; then
        echo "• Configure SMB share: sudo ./scripts/install-packages.sh"
    fi

    if ! [ -f "/etc/systemd/system/camera-bridge.service" ]; then
        echo "• Install camera-bridge service: sudo ./scripts/install-packages.sh"
    fi

    if ! [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        echo "• Configure Dropbox: sudo ./setup-dropbox.sh"
    fi
fi
echo "================================="