#!/bin/bash

# Setup auto-login for camerabridge user with Terminal UI

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "  Camera Bridge Auto-Login Setup"
echo -e "==========================================${NC}"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run with sudo${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if camerabridge user exists
if ! id -u camerabridge >/dev/null 2>&1; then
    echo -e "${YELLOW}Creating camerabridge user...${NC}"
    useradd -m -s /bin/bash -c "Camera Bridge User" camerabridge
    echo -e "${GREEN}✓ User created${NC}"
else
    echo -e "${GREEN}✓ camerabridge user exists${NC}"
fi

echo ""
echo "Setting up auto-login for camerabridge user..."
echo ""

# Step 1: Configure auto-login on tty1
echo -n "1. Configuring auto-login on tty1... "
mkdir -p /etc/systemd/system/getty@tty1.service.d/

cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin camerabridge --noclear %I $TERM
EOF
echo -e "${GREEN}✓${NC}"

# Step 2: Create autostart script for camerabridge user
echo -n "2. Creating autostart script... "
cat > /home/camerabridge/camera-bridge-autostart.sh << 'EOFA'
#!/bin/bash

# Camera Bridge Auto-Start for camerabridge user

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Only run on tty1
if [ "$(tty)" != "/dev/tty1" ]; then
    exit 0
fi

# Clear screen and show banner
clear
echo -e "${CYAN}=========================================="
echo -e "     📷 CAMERA BRIDGE SYSTEM${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# Show system info
echo -e "${GREEN}System Information:${NC}"
echo "• User: $(whoami)"
echo "• Hostname: $(hostname)"
echo "• IP Address: $(hostname -I | awk '{print $1}')"
echo "• Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

# Check service status
echo -e "${GREEN}Service Status:${NC}"
if systemctl is-active --quiet camera-bridge 2>/dev/null; then
    echo "• Camera Bridge: ✓ Running"

    # Check token status if available
    if [ -x "/opt/camera-bridge/scripts/dropbox-token-manager.sh" ]; then
        TOKEN_STATUS=$(sudo /opt/camera-bridge/scripts/dropbox-token-manager.sh status 2>/dev/null | grep "Status:" | tail -1)
        echo "• Token: $TOKEN_STATUS"
    fi
else
    echo "• Camera Bridge: ✗ Stopped"
fi

if systemctl is-active --quiet smbd 2>/dev/null; then
    echo "• SMB Share: ✓ Running"
else
    echo "• SMB Share: ✗ Stopped"
fi

if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "• Web Interface: ✓ Running (http://$(hostname -I | awk '{print $1}'))"
else
    echo "• Web Interface: ✗ Stopped"
fi

echo ""
echo -e "${YELLOW}=========================================="
echo -e "    Starting Terminal Interface${NC}"
echo -e "${YELLOW}==========================================${NC}"
echo ""

# Find terminal UI with QR code support
TERMINAL_UI=""
for path in "/opt/camera-bridge/scripts/terminal-ui.sh" \
            "/usr/local/bin/terminal-ui" \
            "/home/tom/camera-bridge/scripts/terminal-ui.sh"; do
    if [ -x "$path" ]; then
        TERMINAL_UI="$path"
        break
    fi
done

if [ -z "$TERMINAL_UI" ]; then
    echo -e "${RED}Error: Terminal UI not found!${NC}"
    echo ""
    echo "Please ensure Camera Bridge is properly installed."
    echo ""
    echo "Press any key to continue to shell..."
    read -n 1
else
    # Check if we should auto-start
    if [ ! -f "$HOME/.no-camera-bridge-autostart" ]; then
        echo "Options:"
        echo "  Press 'S' to start Camera Bridge Manager"
        echo "  Press 'T' to test token status"
        echo "  Press 'Q' to quit to shell"
        echo ""
        echo -ne "Starting automatically in 5 seconds... "

        for i in 5 4 3 2 1; do
            echo -ne "$i "
            read -t 1 -n 1 key
            if [ $? -eq 0 ]; then
                echo ""
                case "$key" in
                    s|S)
                        echo "Starting Camera Bridge Manager..."
                        sleep 1
                        exec sudo "$TERMINAL_UI"
                        ;;
                    t|T)
                        echo ""
                        echo "Testing token status..."
                        if [ -x "/opt/camera-bridge/scripts/dropbox-token-manager.sh" ]; then
                            sudo /opt/camera-bridge/scripts/dropbox-token-manager.sh status
                        else
                            echo "Token manager not found"
                        fi
                        echo ""
                        echo "Press any key to continue..."
                        read -n 1
                        exec "$0"
                        ;;
                    q|Q)
                        echo ""
                        echo "Exiting to shell..."
                        exit 0
                        ;;
                esac
            fi
        done

        echo ""
        echo "Starting Camera Bridge Manager..."
        sleep 1
        exec sudo "$TERMINAL_UI"
    else
        echo "Auto-start is disabled."
        echo "Remove $HOME/.no-camera-bridge-autostart to re-enable"
    fi
fi
EOFA

chown camerabridge:camerabridge /home/camerabridge/camera-bridge-autostart.sh
chmod +x /home/camerabridge/camera-bridge-autostart.sh
echo -e "${GREEN}✓${NC}"

# Step 3: Add to .bashrc for camerabridge user
echo -n "3. Adding to camerabridge .bashrc... "
if ! grep -q "camera-bridge-autostart.sh" /home/camerabridge/.bashrc 2>/dev/null; then
    cat >> /home/camerabridge/.bashrc << 'EOF'

# Camera Bridge Auto-Start
if [ -f "$HOME/camera-bridge-autostart.sh" ] && [ -z "$CAMERA_BRIDGE_STARTED" ]; then
    export CAMERA_BRIDGE_STARTED=1
    $HOME/camera-bridge-autostart.sh
fi
EOF
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}Already configured${NC}"
fi

# Step 4: Grant sudo permissions for camerabridge user (for terminal UI)
echo -n "4. Configuring sudo permissions... "
cat > /etc/sudoers.d/camerabridge << 'EOF'
# Allow camerabridge user to run camera bridge management commands
camerabridge ALL=(ALL) NOPASSWD: /opt/camera-bridge/scripts/terminal-ui.sh
camerabridge ALL=(ALL) NOPASSWD: /usr/local/bin/terminal-ui
camerabridge ALL=(ALL) NOPASSWD: /opt/camera-bridge/scripts/dropbox-token-manager.sh
camerabridge ALL=(ALL) NOPASSWD: /opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl status camera-bridge
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl start camera-bridge
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop camera-bridge
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart camera-bridge
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl status smbd
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl status nginx
EOF
echo -e "${GREEN}✓${NC}"

# Step 5: Reload systemd
echo -n "5. Reloading systemd... "
systemctl daemon-reload
systemctl restart getty@tty1
echo -e "${GREEN}✓${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo -e "     Auto-Login Setup Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Configuration:"
echo "  • User: camerabridge"
echo "  • Auto-login: tty1 (console)"
echo "  • Auto-start: Terminal UI with QR code support"
echo "  • Token refresh: Automatic every 3 hours"
echo ""
echo "The system will now:"
echo "  1. Auto-login as 'camerabridge' on boot"
echo "  2. Show system status"
echo "  3. Start Terminal UI automatically"
echo "  4. Handle token refresh in background"
echo ""
echo "To test now:"
echo -e "  ${YELLOW}sudo systemctl restart getty@tty1${NC}"
echo "  Then switch to tty1 (Ctrl+Alt+F1)"
echo ""
echo "To disable auto-start temporarily:"
echo -e "  ${YELLOW}touch /home/camerabridge/.no-camera-bridge-autostart${NC}"
echo ""
echo "To switch to manual login:"
echo -e "  ${YELLOW}sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf${NC}"
echo -e "  ${YELLOW}sudo systemctl daemon-reload${NC}"
echo -e "  ${YELLOW}sudo systemctl restart getty@tty1${NC}"