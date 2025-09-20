#!/bin/bash

# Camera Bridge Autostart Setup Script
# Provides multiple options for configuring automatic startup

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "    Camera Bridge Autostart Setup"
echo -e "==========================================${NC}"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Note: Some options require sudo access${NC}"
    echo ""
fi

echo "Select autostart method:"
echo ""
echo "1) Add to user's .bashrc (starts when you open terminal)"
echo "2) Add to user's .profile (starts on login)"
echo "3) Create systemd user service (starts on boot)"
echo "4) Configure auto-login to console (requires sudo)"
echo "5) Create desktop autostart entry"
echo "6) Remove all autostart configurations"
echo "7) Exit"
echo ""
read -p "Choose option [1-7]: " choice

case $choice in
    1)
        echo ""
        echo "Adding to .bashrc..."

        # Check if already added
        if grep -q "camera-bridge-autostart.sh" ~/.bashrc 2>/dev/null; then
            echo -e "${YELLOW}Already configured in .bashrc${NC}"
        else
            cat >> ~/.bashrc << 'EOF'

# Camera Bridge Autostart
if [ -f "$HOME/camera-bridge-autostart.sh" ] && [ -z "$CAMERA_BRIDGE_STARTED" ]; then
    export CAMERA_BRIDGE_STARTED=1
    $HOME/camera-bridge-autostart.sh
fi
EOF
            echo -e "${GREEN}✓ Added to .bashrc${NC}"
            echo "Camera Bridge will start when you open a new terminal"
        fi
        ;;

    2)
        echo ""
        echo "Adding to .profile..."

        # Check if already added
        if grep -q "camera-bridge-autostart.sh" ~/.profile 2>/dev/null; then
            echo -e "${YELLOW}Already configured in .profile${NC}"
        else
            cat >> ~/.profile << 'EOF'

# Camera Bridge Autostart
if [ -f "$HOME/camera-bridge-autostart.sh" ] && [ -z "$CAMERA_BRIDGE_STARTED" ]; then
    export CAMERA_BRIDGE_STARTED=1
    $HOME/camera-bridge-autostart.sh
fi
EOF
            echo -e "${GREEN}✓ Added to .profile${NC}"
            echo "Camera Bridge will start on next login"
        fi
        ;;

    3)
        echo ""
        echo "Creating systemd user service..."

        # Create user systemd directory
        mkdir -p ~/.config/systemd/user/

        # Create service file
        cat > ~/.config/systemd/user/camera-bridge-autostart.service << EOF
[Unit]
Description=Camera Bridge Terminal UI
After=graphical-session.target

[Service]
Type=simple
ExecStart=/home/tom/camera-bridge-autostart.sh --no-delay
Restart=on-failure
RestartSec=5
Environment="TERM=xterm-256color"

[Install]
WantedBy=default.target
EOF

        # Enable service
        systemctl --user daemon-reload
        systemctl --user enable camera-bridge-autostart.service

        echo -e "${GREEN}✓ Systemd user service created and enabled${NC}"
        echo "Start now with: systemctl --user start camera-bridge-autostart.service"
        ;;

    4)
        echo ""
        if [ "$EUID" -ne 0 ]; then
            echo -e "${RED}This option requires sudo access${NC}"
            echo "Run: sudo $0"
            exit 1
        fi

        echo "Configuring auto-login to console..."

        # Create override directory
        mkdir -p /etc/systemd/system/getty@tty1.service.d/

        # Create override configuration
        cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin tom --noclear %I \$TERM
EOF

        # Add autostart to profile
        if ! grep -q "camera-bridge-autostart.sh" /home/tom/.profile 2>/dev/null; then
            cat >> /home/tom/.profile << 'EOF'

# Camera Bridge Autostart (console auto-login)
if [ "$(tty)" = "/dev/tty1" ] && [ -f "$HOME/camera-bridge-autostart.sh" ]; then
    $HOME/camera-bridge-autostart.sh
fi
EOF
        fi

        systemctl daemon-reload
        systemctl restart getty@tty1.service

        echo -e "${GREEN}✓ Console auto-login configured${NC}"
        echo "System will auto-login to user 'tom' and start Camera Bridge on tty1"
        ;;

    5)
        echo ""
        echo "Creating desktop autostart entry..."

        # Create autostart directory
        mkdir -p ~/.config/autostart/

        # Create desktop entry
        cat > ~/.config/autostart/camera-bridge.desktop << EOF
[Desktop Entry]
Type=Application
Name=Camera Bridge Manager
Comment=Camera Bridge Terminal UI
Exec=gnome-terminal -- /home/tom/camera-bridge-autostart.sh
Icon=camera-photo
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=System;
EOF

        echo -e "${GREEN}✓ Desktop autostart entry created${NC}"
        echo "Camera Bridge will start when you log into the desktop"
        ;;

    6)
        echo ""
        echo "Removing autostart configurations..."

        # Remove from .bashrc
        sed -i '/# Camera Bridge Autostart/,/^fi$/d' ~/.bashrc 2>/dev/null

        # Remove from .profile
        sed -i '/# Camera Bridge Autostart/,/^fi$/d' ~/.profile 2>/dev/null

        # Remove systemd user service
        systemctl --user stop camera-bridge-autostart.service 2>/dev/null
        systemctl --user disable camera-bridge-autostart.service 2>/dev/null
        rm -f ~/.config/systemd/user/camera-bridge-autostart.service

        # Remove desktop entry
        rm -f ~/.config/autostart/camera-bridge.desktop

        # Remove auto-login (requires sudo)
        if [ "$EUID" -eq 0 ]; then
            rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
            systemctl daemon-reload
            systemctl restart getty@tty1.service
        fi

        # Remove disable flag
        rm -f ~/.no-camera-bridge-autostart

        echo -e "${GREEN}✓ All autostart configurations removed${NC}"
        ;;

    7)
        echo "Exiting..."
        exit 0
        ;;

    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Additional commands:"
echo "  • Test autostart: $HOME/camera-bridge-autostart.sh"
echo "  • Disable temporarily: touch ~/.no-camera-bridge-autostart"
echo "  • Re-enable: rm ~/.no-camera-bridge-autostart"