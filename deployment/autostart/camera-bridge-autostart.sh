#!/bin/bash

# Camera Bridge Auto-Start Script
# This script handles the automatic startup of Camera Bridge Terminal UI

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Clear screen and show banner
clear
echo -e "${CYAN}=========================================="
echo -e "     📷 CAMERA BRIDGE SYSTEM${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# Show system info
echo -e "${GREEN}System Information:${NC}"
echo "• Hostname: $(hostname)"
echo "• IP Address: $(hostname -I | awk '{print $1}')"
echo "• Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

# Check service status
echo -e "${GREEN}Service Status:${NC}"
if systemctl is-active --quiet camera-bridge 2>/dev/null; then
    echo "• Camera Bridge: ✓ Running"
else
    echo "• Camera Bridge: ✗ Stopped"
fi

if systemctl is-active --quiet smbd 2>/dev/null; then
    echo "• SMB Share: ✓ Running"
else
    echo "• SMB Share: ✗ Stopped"
fi

if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "• Web Interface: ✓ Running"
else
    echo "• Web Interface: ✗ Stopped"
fi

echo ""
echo -e "${YELLOW}=========================================="
echo -e "    Camera Bridge Terminal Interface${NC}"
echo -e "${YELLOW}==========================================${NC}"
echo ""

# Find the terminal UI script
TERMINAL_UI=""
if [ -x "/home/tom/camera-bridge/scripts/terminal-ui.sh" ]; then
    TERMINAL_UI="/home/tom/camera-bridge/scripts/terminal-ui.sh"
elif [ -x "/usr/local/bin/terminal-ui" ]; then
    TERMINAL_UI="/usr/local/bin/terminal-ui"
elif [ -x "/opt/camera-bridge/scripts/terminal-ui.sh" ]; then
    TERMINAL_UI="/opt/camera-bridge/scripts/terminal-ui.sh"
fi

if [ -z "$TERMINAL_UI" ]; then
    echo -e "${RED}Error: Camera Bridge Terminal UI not found!${NC}"
    echo ""
    echo "Please ensure Camera Bridge is properly installed."
    echo "Installation locations checked:"
    echo "  • /home/tom/camera-bridge/scripts/terminal-ui.sh"
    echo "  • /usr/local/bin/terminal-ui"
    echo "  • /opt/camera-bridge/scripts/terminal-ui.sh"
    echo ""
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Check if we should auto-start
if [ "$1" = "--no-delay" ]; then
    # Start immediately without countdown
    exec "$TERMINAL_UI"
else
    echo "Options:"
    echo "  Press 'S' to start Camera Bridge Manager"
    echo "  Press 'Q' to quit to shell"
    echo "  Press 'D' to disable autostart"
    echo ""
    echo -ne "Starting automatically in "

    # Countdown with option to interrupt
    for i in 5 4 3 2 1; do
        echo -ne "${BLUE}${i}${NC} "
        read -t 1 -n 1 key
        if [ $? -eq 0 ]; then
            echo ""
            case "$key" in
                s|S)
                    echo "Starting Camera Bridge Manager..."
                    exec "$TERMINAL_UI"
                    ;;
                q|Q)
                    echo ""
                    echo "Exiting to shell..."
                    exit 0
                    ;;
                d|D)
                    echo ""
                    echo "Creating disable flag..."
                    touch "$HOME/.no-camera-bridge-autostart"
                    echo "Autostart disabled. Remove $HOME/.no-camera-bridge-autostart to re-enable."
                    exit 0
                    ;;
                *)
                    echo "Unknown option. Starting Camera Bridge Manager..."
                    exec "$TERMINAL_UI"
                    ;;
            esac
        fi
    done

    echo ""
    echo ""
    echo "Starting Camera Bridge Manager..."
    sleep 1

    # Start the terminal UI
    exec "$TERMINAL_UI"
fi