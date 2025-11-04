#!/bin/bash

# Camera Bridge Auto-start Script
# Displays boot status and launches terminal UI seamlessly

set -e

LOG_FILE="/var/log/camera-bridge/autostart.log"
CONFIG_DIR="/opt/camera-bridge/config"
USER="camerabridge"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$1"
}

# Detect hardware type
detect_hardware() {
    if [ -f /proc/device-tree/model ]; then
        local model=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
        if echo "$model" | grep -qi "pi zero 2"; then
            echo "pi-zero-2w"
        elif echo "$model" | grep -qi "raspberry pi"; then
            echo "raspberry-pi"
        else
            echo "generic"
        fi
    else
        echo "generic"
    fi
}

# Check if services are ready
wait_for_services() {
    local max_wait=30
    local wait_count=0

    echo "Waiting for camera bridge services..."

    while [ $wait_count -lt $max_wait ]; do
        # Check if camera-bridge service exists and is loaded
        if systemctl list-unit-files | grep -q camera-bridge; then
            echo "Camera bridge service found"
            return 0
        fi

        echo -n "."
        sleep 1
        wait_count=$((wait_count + 1))
    done

    echo ""
    echo "Warning: Camera bridge service not found after ${max_wait} seconds"
    return 1
}

# Display welcome banner
show_welcome_banner() {
    local hardware_type="$1"

    clear
    echo "════════════════════════════════════════════════════════════════"
    echo "              📷 Camera Bridge System Ready 📷"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    case "$hardware_type" in
        "pi-zero-2w")
            echo "🔌 Pi Zero 2 W detected - USB Gadget Mode available"
            echo "   Connect via USB-C for direct camera integration"
            ;;
        "raspberry-pi")
            echo "🌐 Raspberry Pi detected - Network SMB Mode ready"
            echo "   Configure WiFi for camera network sharing"
            ;;
        *)
            echo "💻 Generic system detected - Network SMB Mode available"
            echo "   Configure network for camera sharing"
            ;;
    esac

    echo ""
    echo "System Status:"

    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "   ✅ Internet connection: Connected"
    else
        echo "   ❌ Internet connection: Offline"
    fi

    # Check Dropbox configuration
    if [ -f "/home/$USER/.config/rclone/rclone.conf" ] && \
       sudo -u "$USER" rclone lsd dropbox: >/dev/null 2>&1; then
        echo "   ✅ Dropbox: Configured and accessible"
    else
        echo "   ⚠️  Dropbox: Not configured or inaccessible"
    fi

    # Check camera bridge service
    if systemctl is-active camera-bridge >/dev/null 2>&1; then
        echo "   ✅ Camera Bridge Service: Running"
    elif systemctl is-enabled camera-bridge >/dev/null 2>&1; then
        echo "   ⚠️  Camera Bridge Service: Enabled but not running"
    else
        echo "   ❌ Camera Bridge Service: Not configured"
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

# Show quick start instructions
show_quick_start() {
    local hardware_type="$1"

    echo "Quick Start Instructions:"
    echo ""

    case "$hardware_type" in
        "pi-zero-2w")
            echo "USB Gadget Mode (Recommended for Pi Zero 2 W):"
            echo "  1. Enable USB gadget: sudo /usr/local/bin/usb-gadget-manager.sh enable"
            echo "  2. Connect to camera via USB-C cable"
            echo "  3. Camera will see this device as USB storage"
            echo "  4. Photos will automatically sync to Dropbox"
            echo ""
            echo "Network Mode (Alternative):"
            echo "  1. Configure WiFi in terminal UI"
            echo "  2. Set up camera to connect to WiFi network"
            echo "  3. Configure camera to use SMB share"
            ;;
        *)
            echo "Network SMB Mode:"
            echo "  1. Configure WiFi/Ethernet connection"
            echo "  2. Set up camera to connect to same network"
            echo "  3. Configure camera to save to SMB share"
            echo "  4. Photos will automatically sync to Dropbox"
            ;;
    esac

    echo ""
    echo "Press ENTER to continue to Camera Bridge Terminal UI..."
    echo "Or press 'q' to exit to shell"
    echo ""
}

# Handle user input for startup options
handle_startup_input() {
    local choice

    # Set input timeout
    if read -t 10 -p "Choice: " choice; then
        case "$choice" in
            "q"|"Q"|"quit"|"exit")
                echo "Exiting to shell..."
                return 1
                ;;
            *)
                return 0
                ;;
        esac
    else
        # Timeout - proceed to UI
        echo ""
        echo "Proceeding to Camera Bridge UI..."
        return 0
    fi
}

# Launch terminal UI with proper error handling
launch_terminal_ui() {
    local ui_path=""

    # Find the appropriate UI script (prefer full-featured terminal-ui.sh)
    if [ -f "/usr/local/bin/camera-bridge-ui" ]; then
        ui_path="/usr/local/bin/camera-bridge-ui"
    elif [ -f "/usr/local/bin/terminal-ui" ]; then
        ui_path="/usr/local/bin/terminal-ui"
    elif [ -f "/opt/camera-bridge/scripts/terminal-ui.sh" ]; then
        ui_path="/opt/camera-bridge/scripts/terminal-ui.sh"
    elif [ -f "/usr/local/bin/terminal-ui-enhanced" ]; then
        ui_path="/usr/local/bin/terminal-ui-enhanced"
    elif [ -f "/opt/camera-bridge/scripts/terminal-ui-enhanced.sh" ]; then
        ui_path="/opt/camera-bridge/scripts/terminal-ui-enhanced.sh"
    else
        echo "ERROR: Camera Bridge UI not found!"
        echo "Available options:"
        echo "  1. Run setup: sudo /opt/camera-bridge/scripts/install-packages.sh"
        echo "  2. Check installation: ls -la /usr/local/bin/camera-bridge*"
        echo "  3. Manual start: sudo /opt/camera-bridge/scripts/terminal-ui.sh"
        echo ""
        echo "Press ENTER to exit..."
        read
        return 1
    fi

    log_message "Launching Camera Bridge UI: $ui_path"

    # Launch the UI
    while true; do
        if sudo "$ui_path"; then
            # UI exited normally
            echo ""
            echo "Camera Bridge UI exited."
            echo "Options:"
            echo "  r) Restart UI"
            echo "  s) Exit to shell"
            echo "  q) Quit (same as s)"
            echo ""
            read -p "Choice [r/s/q]: " choice

            case "$choice" in
                "r"|"R"|"restart")
                    clear
                    continue
                    ;;
                "s"|"S"|"shell"|"q"|"Q"|"quit"|*)
                    echo "Exiting to shell..."
                    break
                    ;;
            esac
        else
            # UI failed to start or crashed
            echo ""
            echo "ERROR: Camera Bridge UI failed to start or crashed"
            echo "Check logs: sudo journalctl -u camera-bridge"
            echo "Or manual start: sudo $ui_path"
            echo ""
            echo "Press ENTER to exit to shell..."
            read
            break
        fi
    done
}

# Main autostart function
main() {
    # Ensure log directory exists
    mkdir -p "$(dirname $LOG_FILE)" 2>/dev/null || true

    log_message "Camera Bridge autostart initiated"

    # Detect hardware
    HARDWARE_TYPE=$(detect_hardware)
    log_message "Hardware detected: $HARDWARE_TYPE"

    # Show welcome banner
    show_welcome_banner "$HARDWARE_TYPE"

    # Wait for services to be ready
    wait_for_services

    # Show quick start instructions
    show_quick_start "$HARDWARE_TYPE"

    # Handle user input
    if handle_startup_input; then
        # User wants to proceed to UI
        launch_terminal_ui
    else
        # User chose to exit
        log_message "User chose to exit to shell"
    fi

    log_message "Camera Bridge autostart completed"
}

# Check if running as the correct user
if [ "$USER" != "camerabridge" ] && [ "$USER" != "root" ]; then
    echo "Warning: Running as user '$USER'"
    echo "Camera Bridge is typically run as 'camerabridge' user"
    echo ""
fi

# Run main function
main "$@"