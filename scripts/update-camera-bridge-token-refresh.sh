#!/bin/bash

# Update script to add token refresh capability to existing Camera Bridge installation

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "  Camera Bridge Token Refresh Update"
echo -e "==========================================${NC}"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run with sudo${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Paths
SCRIPT_DIR="/home/tom/camera-bridge/scripts"
INSTALL_DIR="/opt/camera-bridge/scripts"
SYSTEMD_DIR="/etc/systemd/system"

# Create directories if needed
mkdir -p "$INSTALL_DIR" 2>/dev/null
mkdir -p "/var/log/camera-bridge" 2>/dev/null

echo "Updating Camera Bridge with token refresh capability..."
echo ""

# Step 1: Copy token manager script
echo -n "1. Installing token manager script... "
if [ -f "$SCRIPT_DIR/dropbox-token-manager.sh" ]; then
    cp "$SCRIPT_DIR/dropbox-token-manager.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/dropbox-token-manager.sh"
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    exit 1
fi

# Step 2: Copy enhanced service script
echo -n "2. Installing enhanced service script... "
if [ -f "$SCRIPT_DIR/camera-bridge-service-with-refresh.sh" ]; then
    cp "$SCRIPT_DIR/camera-bridge-service-with-refresh.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/camera-bridge-service-with-refresh.sh"
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    exit 1
fi

# Step 3: Backup current systemd service
echo -n "3. Backing up current service file... "
if [ -f "$SYSTEMD_DIR/camera-bridge.service" ]; then
    cp "$SYSTEMD_DIR/camera-bridge.service" "$SYSTEMD_DIR/camera-bridge.service.backup-$(date +%Y%m%d)"
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ No existing service found${NC}"
fi

# Step 4: Update systemd service to use enhanced version
echo -n "4. Updating systemd service file... "
cat > "$SYSTEMD_DIR/camera-bridge.service" << 'EOF'
[Unit]
Description=Camera Bridge Service with Token Refresh
Documentation=https://github.com/your-repo/camera-bridge
After=network.target network-online.target
Wants=network-online.target
Requires=network.target

[Service]
Type=forking
User=root
Group=root
ExecStart=/opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh start
ExecStop=/opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh stop
ExecReload=/opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh restart
PIDFile=/run/camera-bridge.pid

# Restart policy
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Security settings
NoNewPrivileges=false
ProtectHome=false
ProtectSystem=false

# Environment
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=SMB_SHARE=/srv/samba/camera-share
Environment=LOG_FILE=/var/log/camera-bridge/service.log
Environment=TOKEN_MANAGER=/opt/camera-bridge/scripts/dropbox-token-manager.sh

# Standard output and error
StandardOutput=journal
StandardError=journal
SyslogIdentifier=camera-bridge

# Working directory
WorkingDirectory=/opt/camera-bridge

# Timeout settings
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
Alias=camera-sync.service
EOF
echo -e "${GREEN}✓${NC}"

# Step 5: Install systemd timer for token refresh
echo -n "5. Installing systemd timer for token refresh... "
cat > "$SYSTEMD_DIR/dropbox-token-refresh.service" << 'EOF'
[Unit]
Description=Dropbox Token Refresh for Camera Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/camera-bridge/scripts/dropbox-token-manager.sh auto
StandardOutput=append:/var/log/camera-bridge/token-refresh.log
StandardError=append:/var/log/camera-bridge/token-refresh.log
Restart=on-failure
RestartSec=5m

[Install]
WantedBy=multi-user.target
EOF

cat > "$SYSTEMD_DIR/dropbox-token-refresh.timer" << 'EOF'
[Unit]
Description=Dropbox Token Refresh Timer
Requires=dropbox-token-refresh.service

[Timer]
OnBootSec=30min
OnUnitActiveSec=3h
Persistent=true
RandomizedDelaySec=5m

[Install]
WantedBy=timers.target
EOF
echo -e "${GREEN}✓${NC}"

# Step 6: Add cron job as backup
echo -n "6. Setting up cron backup... "
CRON_CMD="/opt/camera-bridge/scripts/dropbox-token-manager.sh auto >/dev/null 2>&1"
CRON_JOB="0 */3 * * * $CRON_CMD"
(crontab -l 2>/dev/null | grep -v "dropbox-token-manager.sh"; echo "$CRON_JOB") | crontab -
echo -e "${GREEN}✓${NC}"

# Step 7: Reload systemd
echo -n "7. Reloading systemd configuration... "
systemctl daemon-reload
systemctl enable dropbox-token-refresh.timer
echo -e "${GREEN}✓${NC}"

# Step 8: Create initial timestamp file
echo -n "8. Creating token timestamp file... "
sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone 2>/dev/null
date +%s > /home/camerabridge/.config/rclone/.dropbox-token-timestamp
chown camerabridge:camerabridge /home/camerabridge/.config/rclone/.dropbox-token-timestamp 2>/dev/null
echo -e "${GREEN}✓${NC}"

# Step 9: Update terminal UI to use version with QR code support
echo -n "9. Updating terminal UI... "
if [ -f "$SCRIPT_DIR/terminal-ui.sh" ]; then
    # Copy the terminal-ui.sh which has QR code support
    cp "$SCRIPT_DIR/terminal-ui.sh" "$INSTALL_DIR/terminal-ui.sh"
    chmod +x "$INSTALL_DIR/terminal-ui.sh"

    # Create symlink in /usr/local/bin for easy access
    ln -sf "$INSTALL_DIR/terminal-ui.sh" /usr/local/bin/terminal-ui 2>/dev/null

    # Also update the enhanced version if it exists
    if [ -f "$SCRIPT_DIR/terminal-ui-enhanced.sh" ]; then
        cp "$SCRIPT_DIR/terminal-ui-enhanced.sh" "$INSTALL_DIR/terminal-ui-enhanced.sh"
        chmod +x "$INSTALL_DIR/terminal-ui-enhanced.sh"
        ln -sf "$INSTALL_DIR/terminal-ui-enhanced.sh" /usr/local/bin/terminal-ui-enhanced 2>/dev/null
    fi

    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Terminal UI not found, skipping${NC}"
fi

# Step 10: Ensure web token entry page exists
echo -n "10. Checking web token entry page... "
WEB_DIR="/opt/camera-bridge/web"
if [ ! -d "$WEB_DIR" ]; then
    mkdir -p "$WEB_DIR"
fi

if [ -f "/home/tom/camera-bridge/web/token-entry.php" ]; then
    cp "/home/tom/camera-bridge/web/token-entry.php" "$WEB_DIR/"
    chown www-data:www-data "$WEB_DIR/token-entry.php" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Web token entry page not found${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo -e "     Update Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Your Camera Bridge has been updated with:"
echo "  ✓ Automatic token refresh every 3 hours"
echo "  ✓ Token refresh on service startup"
echo "  ✓ Offline detection and recovery"
echo "  ✓ Systemd timer for reliability"
echo "  ✓ Cron backup for redundancy"
echo "  ✓ Terminal UI with QR code token entry"
echo "  ✓ Web-based token entry support"
echo ""
echo "Next steps:"
echo ""
echo "1. Restart the camera-bridge service:"
echo -e "   ${YELLOW}sudo systemctl restart camera-bridge${NC}"
echo ""
echo "2. Start the token refresh timer:"
echo -e "   ${YELLOW}sudo systemctl start dropbox-token-refresh.timer${NC}"
echo ""
echo "3. Check token status:"
echo -e "   ${YELLOW}sudo $INSTALL_DIR/dropbox-token-manager.sh status${NC}"
echo ""
echo "4. Launch Terminal UI with QR code support:"
echo -e "   ${YELLOW}sudo terminal-ui${NC}"
echo "   or"
echo -e "   ${YELLOW}sudo $INSTALL_DIR/terminal-ui.sh${NC}"
echo ""
echo "Manual commands available:"
echo "  • Refresh now: sudo $INSTALL_DIR/dropbox-token-manager.sh refresh"
echo "  • Validate: sudo $INSTALL_DIR/dropbox-token-manager.sh validate"
echo "  • Check timer: systemctl status dropbox-token-refresh.timer"
echo ""

# Check current token status
echo "Current token status:"
echo "--------------------"
if [ -x "$INSTALL_DIR/dropbox-token-manager.sh" ]; then
    "$INSTALL_DIR/dropbox-token-manager.sh" status 2>/dev/null || echo "Token manager not yet configured"
fi

echo ""
read -p "Would you like to restart the camera-bridge service now? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Stopping current service..."
    systemctl stop camera-bridge 2>/dev/null
    sleep 2

    echo "Starting updated service..."
    systemctl start camera-bridge
    systemctl start dropbox-token-refresh.timer

    echo ""
    echo -e "${GREEN}Services restarted!${NC}"
    echo ""
    echo "Service status:"
    systemctl status camera-bridge --no-pager | head -15
fi

echo ""
echo -e "${BLUE}Note: The token will now automatically refresh every 3 hours.${NC}"
echo -e "${BLUE}No manual intervention needed for token expiry!${NC}"