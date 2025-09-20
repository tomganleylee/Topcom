#!/bin/bash

# Installation script for Dropbox token refresh system
# This sets up automatic token refresh to handle 4-hour expiry

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "    Dropbox Token Refresh Setup"
echo -e "==========================================${NC}"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run with sudo${NC}"
    exit 1
fi

# Source directory
SOURCE_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_DIR="$SOURCE_DIR/../config"

echo "Installing token refresh system..."

# 1. Copy token manager script
echo -n "Installing token manager script... "
if cp "$SOURCE_DIR/dropbox-token-manager.sh" /opt/camera-bridge/scripts/ 2>/dev/null || \
   cp "$SOURCE_DIR/dropbox-token-manager.sh" /usr/local/bin/ 2>/dev/null; then
    chmod +x /opt/camera-bridge/scripts/dropbox-token-manager.sh 2>/dev/null || \
    chmod +x /usr/local/bin/dropbox-token-manager.sh 2>/dev/null
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Failed to copy to system location, using local${NC}"
fi

# 2. Copy enhanced service script
echo -n "Installing enhanced service script... "
if [ -f "$SOURCE_DIR/camera-bridge-service-with-refresh.sh" ]; then
    cp "$SOURCE_DIR/camera-bridge-service-with-refresh.sh" /opt/camera-bridge/scripts/ 2>/dev/null || \
    cp "$SOURCE_DIR/camera-bridge-service-with-refresh.sh" /usr/local/bin/ 2>/dev/null
    chmod +x /opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh 2>/dev/null || \
    chmod +x /usr/local/bin/camera-bridge-service-with-refresh.sh 2>/dev/null
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Enhanced service script not found${NC}"
fi

# 3. Install systemd timer and service
echo -n "Installing systemd timer for automatic refresh... "
if [ -f "$CONFIG_DIR/dropbox-token-refresh.service" ] && [ -f "$CONFIG_DIR/dropbox-token-refresh.timer" ]; then
    cp "$CONFIG_DIR/dropbox-token-refresh.service" /etc/systemd/system/
    cp "$CONFIG_DIR/dropbox-token-refresh.timer" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable dropbox-token-refresh.timer
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Systemd files not found${NC}"
fi

# 4. Update camera-bridge service to use enhanced version
echo -n "Updating camera-bridge service... "
if [ -f /etc/systemd/system/camera-bridge.service ]; then
    # Backup current service
    cp /etc/systemd/system/camera-bridge.service /etc/systemd/system/camera-bridge.service.backup

    # Update to use enhanced service with token refresh
    sed -i 's|camera-bridge-service\.sh|camera-bridge-service-with-refresh.sh|g' /etc/systemd/system/camera-bridge.service

    systemctl daemon-reload
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Camera bridge service not found${NC}"
fi

# 5. Create cron job as backup
echo -n "Setting up cron job for token refresh... "
CRON_CMD="/opt/camera-bridge/scripts/dropbox-token-manager.sh auto >/dev/null 2>&1"
CRON_JOB="0 */3 * * * $CRON_CMD"

# Add to root's crontab if not already present
(crontab -l 2>/dev/null | grep -v "dropbox-token-manager.sh"; echo "$CRON_JOB") | crontab -
echo -e "${GREEN}✓${NC}"

# 6. Initial token check
echo ""
echo "Checking current token status..."
if [ -x "/opt/camera-bridge/scripts/dropbox-token-manager.sh" ]; then
    /opt/camera-bridge/scripts/dropbox-token-manager.sh status
elif [ -x "$SOURCE_DIR/dropbox-token-manager.sh" ]; then
    "$SOURCE_DIR/dropbox-token-manager.sh" status
fi

echo ""
echo -e "${GREEN}=========================================="
echo -e "    Installation Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Token refresh system has been installed with:"
echo "  • Automatic refresh every 3 hours"
echo "  • Refresh on service startup"
echo "  • Offline period detection"
echo "  • Systemd timer for reliability"
echo "  • Cron backup for redundancy"
echo ""
echo "Next steps:"
echo "  1. Restart camera-bridge service:"
echo "     sudo systemctl restart camera-bridge"
echo ""
echo "  2. Start the token refresh timer:"
echo "     sudo systemctl start dropbox-token-refresh.timer"
echo ""
echo "  3. Check token status:"
echo "     sudo /opt/camera-bridge/scripts/dropbox-token-manager.sh status"
echo ""
echo "Manual commands:"
echo "  • Refresh token now: sudo dropbox-token-manager.sh refresh"
echo "  • Validate token: sudo dropbox-token-manager.sh validate"
echo "  • Check timer: systemctl status dropbox-token-refresh.timer"
echo ""

# Offer to restart service now
read -p "Would you like to restart the camera-bridge service now? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Restarting camera-bridge service..."
    systemctl restart camera-bridge
    systemctl start dropbox-token-refresh.timer

    echo ""
    echo -e "${GREEN}Services restarted successfully!${NC}"
    echo ""
    systemctl status camera-bridge --no-pager | head -10
fi

echo ""
echo -e "${BLUE}Note: For long-term reliability, consider setting up a Dropbox"
echo -e "app with refresh tokens instead of short-lived access tokens.${NC}"
echo ""
echo "Run this command to set up refresh tokens:"
echo "  sudo dropbox-token-manager.sh setup-refresh-token"