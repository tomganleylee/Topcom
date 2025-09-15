#!/bin/bash

# Setup Boot Splash Screen for Camera Bridge
# Creates a custom boot splash with status display

set -e

LOG_FILE="/var/log/camera-bridge/setup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Create custom boot splash service
create_boot_splash_service() {
    log_message "Creating boot splash service"

    cat > /etc/systemd/system/camera-bridge-splash.service << 'EOF'
[Unit]
Description=Camera Bridge Boot Splash
DefaultDependencies=no
After=local-fs.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/camera-bridge-splash
StandardOutput=tty
TTYPath=/dev/tty1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    log_message "Boot splash service created"
}

# Create boot splash script
create_splash_script() {
    log_message "Creating boot splash script"

    cat > /usr/local/bin/camera-bridge-splash << 'EOF'
#!/bin/bash

# Camera Bridge Boot Splash Script

# Clear screen and hide cursor
clear
echo -e "\033[?25l"

# Set colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Display boot splash
cat << 'SPLASH'
████████████████████████████████████████████████████████████████████████
██                                                                    ██
██    ███████   █████  ██     ██ ███████ ██████   █████      ██████   ██
██   ██    ██  ██   ██ ███   ███ ██      ██   ██ ██   ██     ██   ██  ██
██   ██        ██   ██ ████ ████ █████   ██████  ███████     ██████   ██
██   ██    ██  ██   ██ ██ ███ ██ ██      ██   ██ ██   ██     ██   ██  ██
██    ███████   █████  ██     ██ ███████ ██   ██ ██   ██     ██████   ██
██                                                                    ██
██                     ██████  ██████  ██ ██████   ██████ ███████     ██
██                     ██   ██ ██   ██ ██ ██   ██ ██      ██          ██
██                     ██████  ██████  ██ ██   ██ ██   ██ █████       ██
██                     ██   ██ ██   ██ ██ ██   ██ ██    ██ ██          ██
██                     ██████  ██   ██ ██ ██████   ██████  ███████     ██
██                                                                    ██
████████████████████████████████████████████████████████████████████████
SPLASH

echo ""
echo -e "${CYAN}              Automatic Photo Sync to Cloud Storage${NC}"
echo ""
echo -e "${WHITE}Starting Camera Bridge System...${NC}"
echo ""

# Show hardware detection
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
    if echo "$MODEL" | grep -qi "pi zero 2"; then
        echo -e "${GREEN}🔌 Pi Zero 2 W detected - USB Gadget Mode available${NC}"
    elif echo "$MODEL" | grep -qi "raspberry pi"; then
        echo -e "${GREEN}🥧 Raspberry Pi detected - Network SMB Mode ready${NC}"
    else
        echo -e "${BLUE}💻 Hardware: $MODEL${NC}"
    fi
else
    echo -e "${BLUE}💻 Generic Linux system detected${NC}"
fi

echo ""
echo -e "${YELLOW}Initializing services...${NC}"

# Show service status with animation
services=(
    "Checking filesystem"
    "Loading camera bridge modules"
    "Configuring network interfaces"
    "Preparing cloud sync"
    "Starting monitoring services"
)

for service in "${services[@]}"; do
    echo -n "  $service"

    # Simple animation
    for i in {1..3}; do
        sleep 0.3
        echo -n "."
    done

    echo -e " ${GREEN}✓${NC}"
    sleep 0.2
done

echo ""
echo -e "${GREEN}Camera Bridge System Ready!${NC}"
echo ""
echo -e "${WHITE}Preparing user interface...${NC}"

# Wait a moment before handing off to login
sleep 2

# Show cursor again
echo -e "\033[?25h"
EOF

    chmod +x /usr/local/bin/camera-bridge-splash
    log_message "Boot splash script created"
}

# Configure plymouth (if available) for better boot experience
configure_plymouth() {
    if command -v plymouth >/dev/null 2>&1; then
        log_message "Configuring plymouth boot splash"

        # Create custom plymouth theme directory
        mkdir -p /usr/share/plymouth/themes/camera-bridge

        # Create theme configuration
        cat > /usr/share/plymouth/themes/camera-bridge/camera-bridge.plymouth << 'EOF'
[Plymouth Theme]
Name=Camera Bridge
Description=Camera Bridge boot theme
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/camera-bridge
ScriptFile=/usr/share/plymouth/themes/camera-bridge/camera-bridge.script
EOF

        # Create simple script for plymouth
        cat > /usr/share/plymouth/themes/camera-bridge/camera-bridge.script << 'EOF'
# Simple Camera Bridge plymouth script
Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

# Title text
title_image = Image.Text("Camera Bridge", 1, 1, 1);
title_sprite = Sprite(title_image);
title_sprite.SetPosition(Window.GetWidth() / 2 - title_image.GetWidth() / 2,
                        Window.GetHeight() / 2 - 50);

# Status text
status = "Starting Camera Bridge System...";
status_image = Image.Text(status, 0.8, 0.8, 0.8);
status_sprite = Sprite(status_image);
status_sprite.SetPosition(Window.GetWidth() / 2 - status_image.GetWidth() / 2,
                         Window.GetHeight() / 2 + 20);

# Progress function
fun progress_callback(duration, progress) {
    if (progress >= 0.8) {
        status = "Camera Bridge Ready!";
    } else if (progress >= 0.6) {
        status = "Configuring services...";
    } else if (progress >= 0.4) {
        status = "Loading modules...";
    } else if (progress >= 0.2) {
        status = "Checking hardware...";
    } else {
        status = "Starting Camera Bridge System...";
    }

    status_image = Image.Text(status, 0.8, 0.8, 0.8);
    status_sprite.SetImage(status_image);
    status_sprite.SetPosition(Window.GetWidth() / 2 - status_image.GetWidth() / 2,
                             Window.GetHeight() / 2 + 20);
}

Plymouth.SetBootProgressFunction(progress_callback);
EOF

        log_message "Plymouth theme created"
    else
        log_message "Plymouth not available, skipping theme configuration"
    fi
}

# Update installation scripts to include boot splash
update_installation_scripts() {
    log_message "Updating installation scripts to include boot splash"

    # Update the main installation script
    local install_script="/home/tom/camera-bridge/scripts/install-packages.sh"

    if [ -f "$install_script" ]; then
        # Add boot splash setup to installation
        if ! grep -q "setup-boot-splash.sh" "$install_script"; then
            echo "" >> "$install_script"
            echo "# Setup boot splash" >> "$install_script"
            echo "log_message \"Setting up boot splash\"" >> "$install_script"
            echo "./setup-boot-splash.sh enable" >> "$install_script"
        fi
        log_message "Updated main installation script"
    fi

    # Update Pi Zero 2W installation script
    local pi_install_script="/home/tom/camera-bridge/raspberry-pi/pi-zero-2w/scripts/install-pi-zero-2w.sh"

    if [ -f "$pi_install_script" ]; then
        if ! grep -q "setup-boot-splash.sh" "$pi_install_script"; then
            # Add near the end, before final messages
            sed -i '/^log_message "Installation complete"/i \
\
# Setup boot splash and auto-login\
log_message "Configuring seamless user experience"\
"$SCRIPT_DIR/../../../scripts/setup-boot-splash.sh" enable\
"$SCRIPT_DIR/../../../scripts/setup-auto-login.sh" enable' "$pi_install_script"
        fi
        log_message "Updated Pi Zero 2W installation script"
    fi
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This script must be run as root"
        exit 1
    fi

    # Ensure log directory exists
    mkdir -p "$(dirname $LOG_FILE)"

    case "$1" in
        "enable")
            log_message "Enabling boot splash screen"
            create_splash_script
            create_boot_splash_service
            configure_plymouth
            update_installation_scripts

            # Enable the service
            systemctl enable camera-bridge-splash.service

            log_message "Boot splash screen enabled"
            echo "Boot splash screen has been enabled"
            echo "It will appear on the next system boot"
            ;;

        "disable")
            log_message "Disabling boot splash screen"

            # Disable and remove service
            systemctl disable camera-bridge-splash.service 2>/dev/null || true
            rm -f /etc/systemd/system/camera-bridge-splash.service
            rm -f /usr/local/bin/camera-bridge-splash

            # Remove plymouth theme
            rm -rf /usr/share/plymouth/themes/camera-bridge

            systemctl daemon-reload

            log_message "Boot splash screen disabled"
            echo "Boot splash screen has been disabled"
            ;;

        "status")
            if systemctl is-enabled camera-bridge-splash.service >/dev/null 2>&1; then
                echo "Boot splash: ENABLED"
                echo "Service: camera-bridge-splash.service"
                echo "Script: /usr/local/bin/camera-bridge-splash"
            else
                echo "Boot splash: DISABLED"
            fi

            if [ -d /usr/share/plymouth/themes/camera-bridge ]; then
                echo "Plymouth theme: INSTALLED"
            else
                echo "Plymouth theme: NOT INSTALLED"
            fi
            ;;

        *)
            echo "Usage: $0 {enable|disable|status}"
            echo ""
            echo "  enable  - Enable boot splash screen"
            echo "  disable - Disable boot splash screen"
            echo "  status  - Show current configuration"
            exit 1
            ;;
    esac
}

main "$@"