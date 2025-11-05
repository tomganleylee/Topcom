#!/bin/bash

# Enhanced Terminal UI for Camera Bridge Management
# Now includes USB Gadget Mode support for Pi Zero 2 W

DIALOG_HEIGHT=22
DIALOG_WIDTH=75
TITLE="Camera Bridge Manager v1.1"

# Color definitions for non-dialog output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Temporary files for dialog operations
TEMP_DIR="/tmp/camera-bridge-ui"
mkdir -p "$TEMP_DIR"

# Detect hardware capabilities
detect_pi_zero() {
    if [ -f "/proc/device-tree/model" ]; then
        if grep -q "Pi Zero 2" /proc/device-tree/model 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check if USB gadget mode is supported
usb_gadget_supported() {
    detect_pi_zero && [ -d "/sys/class/udc" ] && ls /sys/class/udc | grep -q .
}

# Get current operation mode
get_operation_mode() {
    local config_file="/opt/camera-bridge/config/camera-bridge.conf"
    if [ -f "$config_file" ]; then
        local mode=$(grep "OPERATION_MODE" "$config_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        echo "${mode:-smb}"
    else
        echo "smb"
    fi
}

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
    clear
}

# Set trap for cleanup
trap cleanup EXIT

# Check if dialog is installed
check_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo -e "${RED}Error: 'dialog' is not installed. Please install it first:${NC}"
        echo "sudo apt install dialog"
        exit 1
    fi
}

# Check if user has required permissions
check_permissions() {
    if [ "$EUID" -ne 0 ] && ! groups | grep -q sudo; then
        dialog --title "Permission Error" --msgbox "This interface requires sudo permissions for system management.\n\nPlease run as root or ensure your user is in the sudo group." 10 60
        exit 1
    fi
}

# Enhanced main menu with USB gadget support
show_main_menu() {
    while true; do
        local current_mode=$(get_operation_mode)
        local mode_text="Current Mode: $current_mode"

        # Add hardware info if Pi Zero 2 W
        if detect_pi_zero; then
            mode_text="$mode_text (Pi Zero 2 W)"
        fi

        local menu_options=(
            1 "Operation Mode Management"
            2 "WiFi Status & Management"
            3 "Dropbox Configuration"
            4 "System Status"
            5 "View Logs"
            6 "Network Settings"
            7 "Service Management"
            8 "File Management"
            9 "System Information"
            10 "Maintenance Tools"
            11 "Quick Setup Wizard"
            12 "Help & About"
            13 "Exit"
        )

        dialog --title "$TITLE" --menu "$mode_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 13 "${menu_options[@]}" 2>"$TEMP_DIR/menu_choice"

        if [ $? -ne 0 ]; then
            exit 0
        fi

        choice=$(cat "$TEMP_DIR/menu_choice")
        case $choice in
            1) operation_mode_menu ;;
            2) wifi_menu ;;
            3) dropbox_menu ;;
            4) system_status ;;
            5) view_logs ;;
            6) network_settings ;;
            7) service_management ;;
            8) file_management ;;
            9) system_info ;;
            10) maintenance_menu ;;
            11) setup_wizard ;;
            12) help_about ;;
            13) exit 0 ;;
            *) show_main_menu ;;
        esac
    done
}

# NEW: Operation Mode Management Menu
operation_mode_menu() {
    while true; do
        local current_mode=$(get_operation_mode)
        local status_text="Current Mode: $current_mode"

        # Add USB gadget specific status
        if [ "$current_mode" = "usb-gadget" ]; then
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                local gadget_status=$(usb-gadget-manager.sh status 2>/dev/null | grep "Status:" | cut -d: -f2 | xargs)
                status_text="$status_text ($gadget_status)"
            fi
        fi

        local menu_options=(
            1 "View Current Status"
            2 "Switch to SMB Mode"
            3 "Switch to USB Gadget Mode"
            4 "USB Gadget Management"
            5 "Mode Configuration"
            6 "Back to Main Menu"
        )

        # Disable USB gadget options if not supported
        if ! usb_gadget_supported; then
            menu_options=(
                1 "View Current Status"
                2 "Switch to SMB Mode"
                5 "Mode Configuration"
                6 "Back to Main Menu"
            )
        fi

        dialog --title "Operation Mode Management" --menu "$status_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 "${menu_options[@]}" 2>"$TEMP_DIR/mode_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/mode_choice")
        case $choice in
            1) show_mode_status ;;
            2) switch_to_smb_mode ;;
            3) switch_to_usb_gadget_mode ;;
            4) usb_gadget_management ;;
            5) mode_configuration ;;
            6) return ;;
            *) ;;
        esac
    done
}

# Show detailed mode status
show_mode_status() {
    local current_mode=$(get_operation_mode)
    local status_info="OPERATION MODE STATUS\n"
    status_info+="====================\n\n"
    status_info+="Current Mode: $current_mode\n\n"

    case "$current_mode" in
        "smb")
            status_info+="SMB Network Sharing Mode\n"
            status_info+="• Monitor Path: /srv/samba/camera-share\n"
            status_info+="• SMB Service: $(systemctl is-active smbd 2>/dev/null || echo 'inactive')\n"
            status_info+="• Network Access: \\\\$(hostname -I | awk '{print $1}')\\\\photos\n"
            ;;
        "usb-gadget")
            status_info+="USB Gadget Mode (Pi Zero 2 W)\n"
            status_info+="• Monitor Path: /mnt/camera-bridge-usb\n"
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                local gadget_info=$(usb-gadget-manager.sh status 2>/dev/null | tail -n +3)
                status_info+="• $gadget_info\n"
            else
                status_info+="• USB Gadget Manager: Not available\n"
            fi
            ;;
    esac

    # Add hardware information
    status_info+="\nHardware Information:\n"
    if detect_pi_zero; then
        status_info+="• Device: Pi Zero 2 W (USB Gadget Capable)\n"
        status_info+="• USB Controllers: $(ls /sys/class/udc 2>/dev/null | wc -l) available\n"
    else
        status_info+="• Device: Standard Linux system\n"
        status_info+="• USB Gadget: Not supported\n"
    fi

    dialog --title "Operation Mode Status" --msgbox "$status_info" 20 80
}

# Switch to SMB mode
switch_to_smb_mode() {
    dialog --title "Switching Mode..." --infobox "Switching to SMB network sharing mode..." 5 50

    # Find enhanced service script
    local service_script=""
    if [ -x "/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh" ]; then
        service_script="/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh"
    elif [ -x "$HOME/camera-bridge/scripts/camera-bridge-service-enhanced.sh" ]; then
        service_script="$HOME/camera-bridge/scripts/camera-bridge-service-enhanced.sh"
    fi

    if [ -n "$service_script" ]; then
        if sudo "$service_script" switch-mode smb >/dev/null 2>&1; then
            sudo systemctl restart camera-bridge 2>/dev/null || true
            dialog --title "Mode Switched" --msgbox "Successfully switched to SMB network sharing mode.\n\nThe camera bridge service has been restarted.\n\nCameras can now connect via network share." 12 60
        else
            dialog --title "Error" --msgbox "Failed to switch to SMB mode.\n\nCheck logs for details." 8 50
        fi
    else
        dialog --title "Error" --msgbox "Enhanced camera bridge service not found." 8 50
    fi
}

# Switch to USB gadget mode
switch_to_usb_gadget_mode() {
    if ! usb_gadget_supported; then
        dialog --title "Not Supported" --msgbox "USB Gadget mode is only supported on Pi Zero 2 W with USB OTG capability.\n\nYour current hardware does not support this feature." 10 60
        return
    fi

    dialog --title "USB Gadget Mode" --yesno "Switch to USB Gadget Mode?\n\nThis will:\n• Disable SMB network sharing\n• Enable USB mass storage emulation\n• Allow direct camera USB connection\n• Require camera bridge service restart\n\nContinue?" 14 60

    if [ $? -eq 0 ]; then
        dialog --title "Switching Mode..." --infobox "Switching to USB gadget mode..." 5 50

        # Find enhanced service script
        local service_script=""
        if [ -x "/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh" ]; then
            service_script="/opt/camera-bridge/scripts/camera-bridge-service-enhanced.sh"
        elif [ -x "$HOME/camera-bridge/scripts/camera-bridge-service-enhanced.sh" ]; then
            service_script="$HOME/camera-bridge/scripts/camera-bridge-service-enhanced.sh"
        fi

        if [ -n "$service_script" ]; then
            if sudo "$service_script" switch-mode usb-gadget >/dev/null 2>&1; then
                sudo systemctl restart camera-bridge 2>/dev/null || true
                dialog --title "Mode Switched" --msgbox "Successfully switched to USB Gadget mode.\n\nThe Pi Zero 2 W will now appear as a USB storage device when connected to a camera.\n\nConnect the USB cable and configure your camera to use the USB storage." 14 65
            else
                dialog --title "Error" --msgbox "Failed to switch to USB gadget mode.\n\nEnsure the USB gadget manager is installed and the required kernel modules are available." 10 65
            fi
        else
            dialog --title "Error" --msgbox "Enhanced camera bridge service not found." 8 50
        fi
    fi
}

# USB Gadget Management Menu
usb_gadget_management() {
    if ! usb_gadget_supported; then
        dialog --title "Not Supported" --msgbox "USB Gadget management is only available on Pi Zero 2 W." 8 50
        return
    fi

    while true; do
        dialog --title "USB Gadget Management" --menu "Manage USB gadget functionality:" $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
            1 "Show USB Gadget Status" \
            2 "Setup USB Storage" \
            3 "Enable USB Gadget" \
            4 "Disable USB Gadget" \
            5 "Mount Storage Locally" \
            6 "Unmount Storage" \
            7 "Reset USB Gadget" \
            8 "Monitor USB Activity" \
            9 "Back to Mode Menu" 2>"$TEMP_DIR/usb_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/usb_choice")
        case $choice in
            1) show_usb_gadget_status ;;
            2) setup_usb_storage ;;
            3) enable_usb_gadget ;;
            4) disable_usb_gadget ;;
            5) mount_usb_storage ;;
            6) unmount_usb_storage ;;
            7) reset_usb_gadget ;;
            8) monitor_usb_activity ;;
            9) return ;;
            *) ;;
        esac
    done
}

# Show USB gadget status
show_usb_gadget_status() {
    if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
        local status=$(usb-gadget-manager.sh status 2>/dev/null)
        dialog --title "USB Gadget Status" --msgbox "$status" 20 80
    else
        dialog --title "Error" --msgbox "USB gadget manager not found" 8 40
    fi
}

# Setup USB storage
setup_usb_storage() {
    dialog --title "USB Storage Size" --inputbox "Enter storage size in MB (default: 2048):" 10 50 "2048" 2>"$TEMP_DIR/storage_size"

    if [ $? -eq 0 ]; then
        local size=$(cat "$TEMP_DIR/storage_size")
        if [[ "$size" =~ ^[0-9]+$ ]] && [ "$size" -gt 0 ]; then
            dialog --title "Setting up..." --infobox "Creating USB storage ($size MB)..." 5 50

            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                if sudo usb-gadget-manager.sh setup "$size" >/dev/null 2>&1; then
                    dialog --title "Success" --msgbox "USB storage created successfully.\n\nStorage size: ${size}MB\nRun 'Enable USB Gadget' to activate." 10 50
                else
                    dialog --title "Error" --msgbox "Failed to setup USB storage.\n\nCheck logs for details." 8 50
                fi
            else
                dialog --title "Error" --msgbox "USB gadget manager not found" 8 40
            fi
        else
            dialog --title "Invalid Input" --msgbox "Please enter a valid number greater than 0" 8 40
        fi
    fi
}

# Enable USB gadget
enable_usb_gadget() {
    dialog --title "Enabling..." --infobox "Enabling USB gadget mode..." 5 40

    if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
        if sudo usb-gadget-manager.sh enable >/dev/null 2>&1; then
            dialog --title "Success" --msgbox "USB gadget enabled successfully.\n\nThe Pi Zero 2 W is now acting as a USB storage device.\n\nConnect to camera via USB cable." 12 55
        else
            dialog --title "Error" --msgbox "Failed to enable USB gadget.\n\nEnsure USB storage is set up first." 8 50
        fi
    else
        dialog --title "Error" --msgbox "USB gadget manager not found" 8 40
    fi
}

# Disable USB gadget
disable_usb_gadget() {
    dialog --title "Disabling..." --infobox "Disabling USB gadget mode..." 5 40

    if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
        sudo usb-gadget-manager.sh disable >/dev/null 2>&1
        dialog --title "Disabled" --msgbox "USB gadget disabled." 8 30
    else
        dialog --title "Error" --msgbox "USB gadget manager not found" 8 40
    fi
}

# Monitor USB activity
monitor_usb_activity() {
    dialog --title "USB Activity Monitor" --msgbox "USB activity monitoring will start in the terminal.\nPress Ctrl+C to stop monitoring and return to the menu." 10 60

    clear
    echo -e "${GREEN}USB Gadget Activity Monitor${NC}"
    echo "Press Ctrl+C to return to menu..."
    echo ""

    if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
        sudo usb-gadget-manager.sh monitor || true
    else
        echo "USB gadget manager not found"
        sleep 3
    fi

    echo ""
    echo "Press any key to return to menu..."
    read -n 1
}

# [Continue with existing functions but enhanced...]

# Enhanced system status with mode information
system_status() {
    # Gather system information
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' 2>/dev/null || echo "N/A")
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df -h / | awk 'NR==2{printf "%s", $5}' 2>/dev/null || echo "N/A")
    local uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' 2>/dev/null || echo "N/A")
    local current_mode=$(get_operation_mode)

    # Service status
    local bridge_status="Unknown"
    if systemctl is-active --quiet camera-bridge 2>/dev/null; then
        bridge_status="Running"
    elif [ -f "/var/run/camera-bridge.pid" ] && kill -0 "$(cat /var/run/camera-bridge.pid)" 2>/dev/null; then
        bridge_status="Running"
    else
        bridge_status="Stopped"
    fi

    local smb_status="Stopped"
    if systemctl is-active --quiet smbd 2>/dev/null; then
        smb_status="Running"
    fi

    # WiFi status
    local wifi_status="Not connected"
    if command -v iwgetid >/dev/null 2>&1; then
        local current_ssid=$(iwgetid -r 2>/dev/null)
        if [ -n "$current_ssid" ]; then
            wifi_status="Connected to: $current_ssid"
        fi
    fi

    # Mode-specific information
    local mode_info=""
    case "$current_mode" in
        "usb-gadget")
            mode_info="USB Gadget Mode Active"
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                local gadget_active=$(usb-gadget-manager.sh status 2>/dev/null | grep "Status:" | cut -d: -f2 | xargs)
                mode_info="USB Gadget: $gadget_active"
            fi
            ;;
        "smb")
            mode_info="SMB Network Mode Active"
            ;;
    esac

    local status_info="SYSTEM STATUS
================

Hardware:
• CPU Usage: ${cpu_usage}%
• Memory Usage: ${memory_usage}
• Disk Usage: ${disk_usage}
• Uptime: ${uptime_info}
$(detect_pi_zero && echo "• Device: Pi Zero 2 W" || echo "• Device: Standard System")

Operation Mode:
• $mode_info

Services:
• Camera Bridge: ${bridge_status}
• SMB Server: ${smb_status}

Network:
• ${wifi_status}
• $(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "IP: " $2}' | head -1)

Recent Activity:
• $(find /srv/samba/camera-share /mnt/camera-bridge-usb -type f -mtime -1 2>/dev/null | wc -l) files added today
• Log size: $(du -h /var/log/camera-bridge/service.log 2>/dev/null | cut -f1 || echo "0B")"

    dialog --title "System Status" --msgbox "$status_info" 24 80
}

# [Include all other existing functions from the original terminal-ui.sh...]
# WiFi menu, Dropbox menu, etc. (keeping them the same)

# Enhanced WiFi management menu (keeping existing functionality)
wifi_menu() {
    while true; do
        # Get current status
        local status_text="Checking status..."
        if command -v iwgetid >/dev/null 2>&1; then
            if current_ssid=$(iwgetid -r 2>/dev/null) && [ -n "$current_ssid" ]; then
                status_text="Connected to: $current_ssid"
            else
                status_text="Not connected"
            fi
        fi

        dialog --title "WiFi Management" --menu "$status_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 12 \
            1 "Show WiFi Status" \
            2 "Scan Networks" \
            3 "Connect to Network" \
            4 "Manual Connection" \
            5 "Saved Networks" \
            6 "Auto-Connect" \
            7 "Start Setup Hotspot" \
            8 "Stop Setup Hotspot" \
            9 "Monitor Connection" \
            10 "Reset WiFi Settings" \
            11 "Advanced WiFi Tools" \
            12 "Back to Main Menu" 2>"$TEMP_DIR/wifi_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/wifi_choice")
        case $choice in
            1) show_wifi_status ;;
            2) scan_and_connect ;;
            3) scan_and_connect ;;
            4) manual_connect ;;
            5) saved_networks_menu ;;
            6) auto_connect_menu ;;
            7) start_hotspot ;;
            8) stop_hotspot ;;
            9) monitor_wifi ;;
            10) reset_wifi ;;
            11) advanced_wifi_menu ;;
            12) return ;;
            *) ;;
        esac
    done
}

# [Keep all other existing functions but shortened for space...]

# Initialize and start
main() {
    check_dialog
    check_permissions

    # Create log directory if needed
    sudo mkdir -p /var/log/camera-bridge 2>/dev/null || true

    # Show connection info on startup
    local eth_ip=$(ip -4 addr show eno1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    local wifi_ip=$(ip -4 addr show wlx24ec99bfe35b 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    local client_ip=$(ip -4 addr show wlp1s0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    local hotspot_status="inactive"
    if systemctl is-active --quiet hostapd 2>/dev/null; then
        hotspot_status="active"
    fi

    local startup_info="Camera Bridge - Network Information
==========================================

Ethernet Bridge (Cameras):
• IP Address: ${eth_ip:-Not configured}
• Network: 192.168.10.0/24

WiFi Access Point:
• Status: $hotspot_status
• SSID: CameraBridge-Setup
• Password: camera123
• IP Address: ${wifi_ip:-Not configured}
• Network: 192.168.50.0/24

Client WiFi (Internet):
• IP Address: ${client_ip:-Not connected}

Press any key to continue to main menu..."

    dialog --title "Network Status" --msgbox "$startup_info" 20 70

    clear
    show_main_menu
}

# WiFi Management Functions (Real implementations)
show_wifi_status() {
    dialog --title "Loading..." --infobox "Getting WiFi status..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -n "$wifi_script" ]; then
        # Get connection status
        local status_info=$(sudo "$wifi_script" status 2>/dev/null)

        # Add additional system information
        local interface_status=""
        if command -v iwconfig >/dev/null 2>&1; then
            local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
            if [ -n "$wifi_iface" ]; then
                interface_status=$(iwconfig "$wifi_iface" 2>/dev/null | grep -E "(ESSID|Frequency|Access Point|Bit Rate|Signal level)" | head -5)
            fi
        fi

        # Get hotspot status
        local hotspot_status="Stopped"
        if systemctl is-active --quiet hostapd 2>/dev/null; then
            hotspot_status="Running (CameraBridge-Setup)"
        fi

        # Format comprehensive status
        if [ -n "$status_info" ]; then
            status_info="$status_info

Interface Details:
$interface_status

Setup Hotspot: $hotspot_status

Commands Available:
• Press 'R' to refresh
• Press 'C' to connect to network
• Press 'S' to start hotspot"
        else
            status_info="Unable to get WiFi status.

Basic Information:
• Interface: $(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1 || echo "Not detected")
• Setup Hotspot: $hotspot_status
• Check that WiFi hardware is available

Try using 'Scan Networks' to test connectivity."
        fi
    else
        status_info="ERROR: WiFi manager script not found!

Expected locations:
• /opt/camera-bridge/scripts/wifi-manager.sh
• $HOME/camera-bridge/scripts/wifi-manager.sh

Please ensure the Camera Bridge is properly installed."
    fi

    # Show status with options
    dialog --title "WiFi Status" --msgbox "$status_info" 20 80
}

scan_and_connect() {
    # Show scanning progress
    dialog --title "Scanning..." --infobox "Scanning for WiFi networks...\nThis may take 10-15 seconds." 6 50

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 50
        return
    fi

    # Scan for networks
    local networks=$(sudo "$wifi_script" scan 2>/dev/null)

    if [ -z "$networks" ]; then
        dialog --title "No Networks Found" --msgbox "No WiFi networks were found.\n\nPossible causes:\n• WiFi is disabled\n• No networks in range\n• Hardware issues\n\nTry:\n• Moving closer to a WiFi router\n• Check that WiFi hardware is enabled\n• Use WiFi Status to check interface" 14 60
        return
    fi

    # Convert networks to menu format
    local menu_options=""
    local count=0
    while IFS= read -r network; do
        if [ -n "$network" ]; then
            count=$((count + 1))
            menu_options="$menu_options $count \"$network\""
        fi
    done <<< "$networks"

    if [ $count -eq 0 ]; then
        dialog --title "No Networks" --msgbox "No valid networks found" 8 50
        return
    fi

    # Add refresh and cancel options
    count=$((count + 1))
    menu_options="$menu_options $count \"🔄 Refresh Networks\""
    count=$((count + 1))
    menu_options="$menu_options $count \"❌ Cancel\""

    # Show network selection menu
    eval "dialog --title \"Available Networks\" --menu \"Choose a network to connect:\" $DIALOG_HEIGHT $DIALOG_WIDTH $count $menu_options 2>\"$TEMP_DIR/network_choice\""

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/network_choice")

    # Get selected network name
    local selected_network=""
    local current_count=0
    while IFS= read -r network; do
        if [ -n "$network" ]; then
            current_count=$((current_count + 1))
            if [ $current_count -eq $choice ]; then
                selected_network="$network"
                break
            fi
        fi
    done <<< "$networks"

    # Handle special options
    if [ -z "$selected_network" ]; then
        if [ $choice -eq $((count - 1)) ]; then
            # Refresh - call function again
            scan_and_connect
            return
        else
            # Cancel
            return
        fi
    fi

    # Prompt for password
    dialog --title "Network Password" --passwordbox "Enter password for network:\n$selected_network\n\n(Leave empty for open networks)" 12 60 2>"$TEMP_DIR/wifi_password"

    if [ $? -ne 0 ]; then
        rm -f "$TEMP_DIR/wifi_password"
        return
    fi

    local password=$(cat "$TEMP_DIR/wifi_password")
    rm -f "$TEMP_DIR/wifi_password"

    # Show connection progress
    dialog --title "Connecting..." --infobox "Connecting to: $selected_network\n\nThis may take up to 30 seconds...\nPlease wait..." 8 60

    # Attempt connection
    if [ -n "$password" ]; then
        if timeout 60 sudo "$wifi_script" connect "$selected_network" "$password" >/dev/null 2>&1; then
            # Verify connection
            sleep 3
            if current_ssid=$(iwgetid -r 2>/dev/null) && [ "$current_ssid" = "$selected_network" ]; then
                local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
                local ip_addr=$(ip addr show "$wifi_iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
                dialog --title "Connection Successful" --msgbox "✓ Connected to: $selected_network\n\nConnection Details:\n• IP Address: ${ip_addr:-Obtaining...}\n• Network saved for auto-reconnect\n• Signal strength: $(iwconfig "$wifi_iface" 2>/dev/null | grep "Signal level" | sed 's/.*Signal level=\([^ ]*\).*/\1/' || echo "Unknown")\n\nInternet connectivity should now be available." 14 70
            else
                dialog --title "Connection Issues" --msgbox "Connection completed but verification failed.\n\nNetwork: $selected_network\n\nThis might indicate:\n• Very weak signal\n• Network authentication issues\n• Brief connection that dropped\n\nSuggestions:\n• Try connecting again\n• Move closer to the router\n• Check if password is correct\n• Use WiFi Status to check connection" 16 70
            fi
        else
            dialog --title "Connection Failed" --msgbox "Failed to connect to: $selected_network\n\nPossible causes:\n• Incorrect password\n• Network is out of range\n• Network compatibility issues\n• Router configuration problems\n\nSuggestions:\n• Verify the password is correct\n• Move closer to the router\n• Try a different network\n• Check WiFi Status for interface issues" 16 70
        fi
    else
        # Open network (no password)
        if timeout 60 sudo "$wifi_script" connect "$selected_network" "" >/dev/null 2>&1; then
            sleep 3
            if current_ssid=$(iwgetid -r 2>/dev/null) && [ "$current_ssid" = "$selected_network" ]; then
                dialog --title "Connection Successful" --msgbox "✓ Connected to open network: $selected_network\n\nConnection established successfully.\nNetwork saved for auto-reconnect." 10 60
            else
                dialog --title "Connection Issues" --msgbox "Open network connection had verification issues.\n\nNetwork: $selected_network" 10 60
            fi
        else
            dialog --title "Connection Failed" --msgbox "Failed to connect to open network: $selected_network" 8 60
        fi
    fi

    # Cleanup
    rm -f "$TEMP_DIR/network_choice"
}

manual_connect() {
    # Get SSID
    dialog --title "Manual Connection" --inputbox "Enter network SSID (name):" 10 50 2>"$TEMP_DIR/manual_ssid"
    if [ $? -ne 0 ]; then
        return
    fi

    local ssid=$(cat "$TEMP_DIR/manual_ssid")
    if [ -z "$ssid" ]; then
        dialog --title "Invalid Input" --msgbox "SSID cannot be empty" 8 40
        rm -f "$TEMP_DIR/manual_ssid"
        return
    fi

    # Get password
    dialog --title "Network Password" --passwordbox "Enter password for:\n$ssid\n\n(Leave empty for open networks)" 10 50 2>"$TEMP_DIR/manual_password"
    if [ $? -ne 0 ]; then
        rm -f "$TEMP_DIR/manual_ssid"
        return
    fi

    local password=$(cat "$TEMP_DIR/manual_password")

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 50
        rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_password"
        return
    fi

    # Show connection progress
    dialog --title "Connecting..." --infobox "Connecting to: $ssid\n\nThis may take up to 30 seconds..." 7 50

    # Attempt connection
    if timeout 60 sudo "$wifi_script" connect "$ssid" "$password" >/dev/null 2>&1; then
        sleep 3
        if current_ssid=$(iwgetid -r 2>/dev/null) && [ "$current_ssid" = "$ssid" ]; then
            dialog --title "Connection Successful" --msgbox "✓ Successfully connected to: $ssid\n\nNetwork saved for auto-reconnect." 10 50
        else
            dialog --title "Connection Issues" --msgbox "Connection process completed but verification failed.\n\nNetwork: $ssid" 10 60
        fi
    else
        dialog --title "Connection Failed" --msgbox "Failed to connect to: $ssid\n\nPlease verify:\n• SSID is correct\n• Password is correct\n• Network is in range" 12 50
    fi

    # Cleanup
    rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_password"
}

start_hotspot() {
    dialog --title "Starting Hotspot..." --infobox "Starting setup hotspot..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -n "$wifi_script" ]; then
        if sudo "$wifi_script" start-ap >/dev/null 2>&1; then
            dialog --title "Hotspot Active" --msgbox "Setup hotspot is now active.\n\nSSID: CameraBridge-Setup\nPassword: setup123\nWebUI: http://192.168.4.1" 12 50
        else
            dialog --title "Error" --msgbox "Failed to start hotspot" 8 40
        fi
    else
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 40
    fi
}

stop_hotspot() {
    dialog --title "Stopping Hotspot..." --infobox "Stopping setup hotspot..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -n "$wifi_script" ]; then
        sudo "$wifi_script" stop-ap >/dev/null 2>&1
        dialog --title "Hotspot Stopped" --msgbox "Setup hotspot has been stopped." 8 40
    else
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 40
    fi
}

monitor_wifi() {
    dialog --title "WiFi Monitor" --msgbox "WiFi monitoring will start in the terminal.\nPress Ctrl+C to stop monitoring and return to the menu." 10 60

    clear
    echo -e "${GREEN}WiFi Connection Monitor${NC}"
    echo "Press Ctrl+C to return to menu..."
    echo ""

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -n "$wifi_script" ]; then
        sudo "$wifi_script" monitor || true
    else
        echo "WiFi manager script not found"
        sleep 3
    fi

    echo ""
    echo "Press any key to return to menu..."
    read -n 1
}

reset_wifi() {
    if dialog --title "Reset WiFi Settings" --yesno "This will:\n\n• Disconnect from current WiFi network\n• Clear all saved network configurations\n• Stop any running hotspot\n• Reset WiFi interface to defaults\n\nThis action cannot be undone.\n\nAre you sure you want to continue?" 14 60; then

        dialog --title "Resetting..." --infobox "Resetting WiFi settings...\nThis may take a moment." 6 50

        # Find WiFi manager script
        local wifi_script=""
        if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
            wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
        elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
            wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
        fi

        if [ -n "$wifi_script" ]; then
            # Use the reset function from wifi-manager
            if sudo "$wifi_script" reset >/dev/null 2>&1; then
                sleep 2
                dialog --title "Reset Complete" --msgbox "WiFi settings have been reset successfully.\n\n• All network configurations cleared\n• WiFi interface reset\n• Ready for new configuration\n\nYou can now:\n• Scan for networks\n• Use manual connection\n• Start setup hotspot" 12 60
            else
                dialog --title "Reset Failed" --msgbox "Failed to reset WiFi settings.\n\nTry:\n• Check that you have proper permissions\n• Ensure WiFi hardware is available\n• Use advanced WiFi tools for manual reset" 10 60
            fi
        else
            dialog --title "Error" --msgbox "WiFi manager script not found.\n\nCannot perform reset without the script." 8 50
        fi
    fi
}

advanced_wifi_menu() {
    while true; do
        dialog --title "Advanced WiFi Tools" --menu "Choose an advanced option:" $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
            1 "Saved Networks Management" \
            2 "Auto-Connect Settings" \
            3 "WiFi Auto-Connect Service" \
            4 "Network Diagnostics" \
            5 "Interface Management" \
            6 "Connection Logs" \
            7 "Back to WiFi Menu" 2>"$TEMP_DIR/advanced_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/advanced_choice")
        case $choice in
            1) saved_networks_menu ;;
            2) auto_connect_menu ;;
            3) wifi_service_management ;;
            4) network_diagnostics ;;
            5) interface_management ;;
            6) view_wifi_logs ;;
            7) return ;;
            *) ;;
        esac
    done
}
# Saved Networks Management Functions
saved_networks_menu() {
    while true; do
        # Get saved networks count
        local saved_count="0"
        local wifi_script=""
        if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
            wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
        elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
            wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
        fi

        if [ -n "$wifi_script" ]; then
            saved_count=$(sudo "$wifi_script" list-saved 2>/dev/null | grep -c "^[0-9]\+\." || echo "0")
        fi

        local status_text="Saved Networks: $saved_count"

        dialog --title "Saved Networks" --menu "$status_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
            1 "📋 List Saved Networks" \
            2 "🔗 Connect to Saved Network" \
            3 "🗑️ Remove Saved Network" \
            4 "📊 Network Details" \
            5 "⚙️ Auto-Connect Settings" \
            6 "🔄 Refresh List" \
            7 "Back to WiFi Menu" 2>"$TEMP_DIR/saved_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/saved_choice")
        case $choice in
            1) list_saved_networks ;;
            2) connect_to_saved_network ;;
            3) remove_saved_network ;;
            4) show_network_details ;;
            5) auto_connect_settings ;;
            6) continue ;;
            7) return ;;
            *) ;;
        esac
    done
}

# List saved networks
list_saved_networks() {
    dialog --title "Loading..." --infobox "Getting saved networks..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 50
        return
    fi

    # Get saved networks with current availability
    local networks_output=$(sudo "$wifi_script" list-saved 2>/dev/null)
    local available_networks=$(sudo "$wifi_script" scan 2>/dev/null | tr '\n' '|')

    if [ -z "$networks_output" ] || [[ "$networks_output" == *"No saved networks"* ]]; then
        dialog --title "No Saved Networks" --msgbox "No networks have been saved yet.\n\nTo save a network:\n• Use 'Connect to Network' or 'Manual Connection'\n• Networks are automatically saved after successful connection\n\nSaved networks allow for:\n• Quick reconnection\n• Automatic connection when in range\n• Password-less switching between known networks" 12 60
        return
    fi

    # Format output with availability status
    local formatted_output=""
    if [ -n "$available_networks" ]; then
        formatted_output=$(echo "$networks_output" | while IFS= read -r line; do
            if echo "$line" | grep -q "^[0-9]\+\."; then
                # Extract SSID from the line
                local ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
                if echo "$available_networks" | grep -q "|$ssid|"; then
                    echo "$line ⚡ Available"
                else
                    echo "$line ⭕ Not in range"
                fi
            else
                echo "$line"
            fi
        done)
    else
        formatted_output="$networks_output

⚠️ Could not scan for available networks"
    fi

    # Show in scrollable format with proper newlines
    local display_text="$formatted_output

✓ = Password saved | ○ = Open network
🔄 = Auto-connect enabled | ⏸️ = Auto-connect disabled
⚡ = Currently available | ⭕ = Not in range

Press OK to return to menu"

    dialog --title "Saved Networks" --msgbox "$display_text" 20 80
}

# Connect to a saved network
connect_to_saved_network() {
    dialog --title "Loading..." --infobox "Getting saved networks..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 50
        return
    fi

    # Get saved networks and format for menu
    local networks_output=$(sudo "$wifi_script" list-saved 2>/dev/null)

    if [ -z "$networks_output" ] || [[ "$networks_output" == *"No saved networks"* ]]; then
        dialog --title "No Saved Networks" --msgbox "No networks available for connection.\n\nSave networks first by using:\n• Scan Networks\n• Manual Connection" 10 50
        return
    fi

    # Parse networks into menu format
    local menu_options=""
    local network_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^[0-9]\+\."; then
            network_count=$((network_count + 1))
            local status_icon=$(echo "$line" | sed 's/^[0-9]\+\. \([✓○]\) .*/\1/')
            local ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
            menu_options="$menu_options $network_count \"$status_icon $ssid\""
        fi
    done <<< "$networks_output"

    if [ $network_count -eq 0 ]; then
        dialog --title "No Networks" --msgbox "No saved networks found for connection" 8 50
        return
    fi

    # Show network selection menu
    eval "dialog --title \"Connect to Saved Network\" --menu \"Choose a network to connect:\" $DIALOG_HEIGHT $DIALOG_WIDTH $network_count $menu_options 2>\"$TEMP_DIR/network_choice\""

    if [ $? -ne 0 ]; then
        return
    fi

    local choice=$(cat "$TEMP_DIR/network_choice")

    # Get selected network SSID
    local selected_ssid=""
    local current_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^[0-9]\+\."; then
            current_count=$((current_count + 1))
            if [ $current_count -eq $choice ]; then
                selected_ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
                break
            fi
        fi
    done <<< "$networks_output"

    if [ -z "$selected_ssid" ]; then
        dialog --title "Error" --msgbox "Failed to identify selected network" 8 50
        return
    fi

    # Show connection progress
    dialog --title "Connecting..." --infobox "Connecting to saved network:\n$selected_ssid\n\nPlease wait..." 7 60

    # Attempt connection
    if timeout 60 sudo "$wifi_script" connect-saved "$selected_ssid" >/dev/null 2>&1; then
        # Verify connection
        sleep 3
        if current_ssid=$(iwgetid -r 2>/dev/null) && [ "$current_ssid" = "$selected_ssid" ]; then
            local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
            local ip_addr=$(ip addr show "$wifi_iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
            dialog --title "Connection Successful" --msgbox "✓ Connected to saved network: $selected_ssid\n\nConnection Details:\n• IP Address: ${ip_addr:-Obtaining...}\n• Using saved credentials\n• Network priority updated\n\nInternet connectivity should be available." 12 70
        else
            dialog --title "Connection Issues" --msgbox "Connection completed but verification failed.\n\nNetwork: $selected_ssid\n\nThis might indicate:\n• Weak signal or interference\n• Network configuration changes\n• Temporary network issues\n\nTry:\n• Check WiFi Status in a moment\n• Move closer to the access point\n• Remove and re-add the network if issues persist" 16 70
        fi
    else
        dialog --title "Connection Failed" --msgbox "Failed to connect to saved network:\n$selected_ssid\n\nPossible causes:\n• Network is out of range\n• Network credentials changed\n• Router/AP issues\n• Interface problems\n\nSuggestions:\n• Check network availability with 'Scan Networks'\n• Remove and re-add the network if credentials changed\n• Try manual connection to test\n• Check WiFi Status for interface issues" 18 70
    fi

    # Cleanup
    rm -f "$TEMP_DIR/network_choice"
}

# Remove a saved network
remove_saved_network() {
    dialog --title "Loading..." --infobox "Getting saved networks..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 50
        return
    fi

    # Get saved networks
    local networks_output=$(sudo "$wifi_script" list-saved 2>/dev/null)

    if [ -z "$networks_output" ] || [[ "$networks_output" == *"No saved networks"* ]]; then
        dialog --title "No Saved Networks" --msgbox "No saved networks to remove." 8 50
        return
    fi

    # Parse networks into menu format
    local menu_options=""
    local network_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^[0-9]\+\."; then
            network_count=$((network_count + 1))
            local status_icon=$(echo "$line" | sed 's/^[0-9]\+\. \([✓○]\) .*/\1/')
            local ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
            menu_options="$menu_options $network_count \"$status_icon $ssid\""
        fi
    done <<< "$networks_output"

    if [ $network_count -eq 0 ]; then
        dialog --title "No Networks" --msgbox "No saved networks found" 8 50
        return
    fi

    # Add cancel option
    menu_options="$menu_options $((network_count + 1)) \"❌ Cancel\""

    # Show network selection menu
    eval "dialog --title \"Remove Saved Network\" --menu \"Choose a network to remove:\" $DIALOG_HEIGHT $DIALOG_WIDTH $((network_count + 1)) $menu_options 2>\"$TEMP_DIR/remove_choice\""

    if [ $? -ne 0 ]; then
        return
    fi

    local choice=$(cat "$TEMP_DIR/remove_choice")

    # Check for cancel
    if [ $choice -eq $((network_count + 1)) ]; then
        rm -f "$TEMP_DIR/remove_choice"
        return
    fi

    # Get selected network SSID
    local selected_ssid=""
    local current_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^[0-9]\+\."; then
            current_count=$((current_count + 1))
            if [ $current_count -eq $choice ]; then
                selected_ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
                break
            fi
        fi
    done <<< "$networks_output"

    if [ -z "$selected_ssid" ]; then
        dialog --title "Error" --msgbox "Failed to identify selected network" 8 50
        rm -f "$TEMP_DIR/remove_choice"
        return
    fi

    # Confirm removal
    if dialog --title "Confirm Removal" --yesno "Remove saved network:\n\n$selected_ssid\n\nThis will:\n• Delete saved credentials\n• Require re-entering password for future connections\n• Remove from auto-connect list\n\nThis action cannot be undone.\n\nAre you sure?" 14 60; then

        dialog --title "Removing..." --infobox "Removing saved network:\n$selected_ssid" 6 50

        if sudo "$wifi_script" remove-saved "$selected_ssid" >/dev/null 2>&1; then
            dialog --title "Network Removed" --msgbox "✓ Successfully removed:\n$selected_ssid\n\nThe network has been deleted from saved networks.\nYou will need to enter credentials again to reconnect." 10 60
        else
            dialog --title "Removal Failed" --msgbox "Failed to remove network:\n$selected_ssid\n\nThe network may not exist in saved networks or there was a system error." 10 60
        fi
    fi

    # Cleanup
    rm -f "$TEMP_DIR/remove_choice"
}

# Auto-connect menu
auto_connect_menu() {
    while true; do
        dialog --title "Auto-Connect" --menu "WiFi Auto-Connect Options:" $DIALOG_HEIGHT $DIALOG_WIDTH 6 \
            1 "Try Auto-Connect Now" \
            2 "Show Auto-Connect Status" \
            3 "Auto-Connect Settings" \
            4 "Connection Priority Info" \
            5 "Back to WiFi Menu" 2>"$TEMP_DIR/auto_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/auto_choice")
        case $choice in
            1)
                dialog --title "Auto-Connecting..." --infobox "Attempting to auto-connect to saved networks...\n\nScanning for available networks..." 7 60

                if sudo "/opt/camera-bridge/scripts/wifi-manager.sh" auto-connect >/dev/null 2>&1; then
                    sleep 2
                    if current_ssid=$(iwgetid -r 2>/dev/null) && [ -n "$current_ssid" ]; then
                        dialog --title "Auto-Connect Success" --msgbox "✓ Auto-connected successfully!\n\nConnected to: $current_ssid\n\nAuto-connect found and connected to a saved network that was in range." 10 60
                    else
                        dialog --title "Auto-Connect Issues" --msgbox "Auto-connect completed but connection verification failed.\n\nThis might indicate:\n• Very weak signal\n• Network authentication issues\n• Brief connection that dropped\n\nCheck WiFi Status for current connection state." 12 60
                    fi
                else
                    dialog --title "Auto-Connect Failed" --msgbox "Auto-connect could not establish a connection.\n\nPossible reasons:\n• No saved networks in range\n• All saved networks have connectivity issues\n• WiFi hardware problems\n• All available networks require updated credentials\n\nTry:\n• Manual connection to test specific networks\n• Check that saved networks are broadcasting\n• Verify WiFi interface status" 16 60
                fi
                ;;
            2)
                local status_info=$(sudo "/opt/camera-bridge/scripts/wifi-manager.sh" list-saved 2>/dev/null)
                if [ -n "$status_info" ] && [[ "$status_info" != *"No saved networks"* ]]; then
                    dialog --title "Auto-Connect Status" --msgbox "Auto-Connect Status:\n\n$status_info\n\n🔄 = Auto-connect enabled for this network\n⏸️ = Auto-connect disabled for this network\n\nNetworks with auto-connect enabled will be tried automatically when:\n• System starts up\n• WiFi connection is lost\n• Manual auto-connect is triggered" 18 70
                else
                    dialog --title "No Auto-Connect Networks" --msgbox "No networks configured for auto-connect.\n\nTo enable auto-connect:\n• Connect to networks normally\n• Networks are automatically saved with auto-connect enabled\n• Use the priority settings to control connection order" 12 60
                fi
                ;;
            3)
                dialog --title "Auto-Connect Settings" --msgbox "Auto-connect settings are managed per network.\n\nTo modify auto-connect behavior:\n• All newly connected networks have auto-connect enabled by default\n• Individual network auto-connect status is managed through the network details\n• Connection priority determines which network is preferred when multiple are available\n\nFor system-wide auto-connect control, this feature will be added in a future update." 14 70
                ;;
            4)
                dialog --title "Connection Priority" --msgbox "Network Priority Information:\n\n• Higher priority numbers = preferred networks\n• Networks with passwords typically get priority 10\n• Open networks typically get priority 5\n• Priority is automatically assigned based on network type\n• When multiple saved networks are available, highest priority connects first\n\nPriority modification features will be added in future updates." 14 70
                ;;
            5)
                return
                ;;
        esac
    done
    rm -f "$TEMP_DIR/auto_choice"
}

# WiFi Service Management
wifi_service_management() {
    while true; do
        local service_status="Unknown"
        if systemctl is-active --quiet wifi-auto-connect.service 2>/dev/null; then
            service_status="Running"
        elif systemctl is-enabled --quiet wifi-auto-connect.service 2>/dev/null; then
            service_status="Enabled (Stopped)"
        else
            service_status="Disabled"
        fi

        dialog --title "WiFi Service Management" --menu "Auto-Connect Service Status: $service_status\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
            1 "Show Service Status" \
            2 "Start Auto-Connect Service" \
            3 "Stop Auto-Connect Service" \
            4 "Enable Auto-Connect Service" \
            5 "Disable Auto-Connect Service" \
            6 "View Service Logs" \
            7 "Restart Service" \
            8 "Back to Advanced Menu" 2>"$TEMP_DIR/service_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/service_choice")
        case $choice in
            1)
                local status_output=$(sudo systemctl status wifi-auto-connect.service 2>&1)
                dialog --title "Service Status" --msgbox "$status_output" 20 80
                ;;
            2)
                dialog --title "Starting..." --infobox "Starting WiFi auto-connect service..." 5 50
                if sudo systemctl start wifi-auto-connect.service 2>/dev/null; then
                    dialog --title "Service Started" --msgbox "WiFi auto-connect service started successfully." 8 50
                else
                    dialog --title "Start Failed" --msgbox "Failed to start WiFi auto-connect service.\nCheck logs for details." 8 50
                fi
                ;;
            3)
                dialog --title "Stopping..." --infobox "Stopping WiFi auto-connect service..." 5 50
                sudo systemctl stop wifi-auto-connect.service 2>/dev/null
                dialog --title "Service Stopped" --msgbox "WiFi auto-connect service stopped." 8 50
                ;;
            4)
                dialog --title "Enabling..." --infobox "Enabling WiFi auto-connect service..." 5 50
                if sudo systemctl enable wifi-auto-connect.service 2>/dev/null; then
                    dialog --title "Service Enabled" --msgbox "WiFi auto-connect service enabled.\nIt will start automatically at boot." 8 50
                else
                    dialog --title "Enable Failed" --msgbox "Failed to enable WiFi auto-connect service." 8 50
                fi
                ;;
            5)
                dialog --title "Disabling..." --infobox "Disabling WiFi auto-connect service..." 5 50
                sudo systemctl disable wifi-auto-connect.service 2>/dev/null
                dialog --title "Service Disabled" --msgbox "WiFi auto-connect service disabled.\nIt will not start automatically at boot." 8 50
                ;;
            6)
                local log_output=$(sudo journalctl -u wifi-auto-connect.service --no-pager -n 50 2>/dev/null)
                if [ -n "$log_output" ]; then
                    dialog --title "Service Logs" --msgbox "$log_output" 24 100
                else
                    dialog --title "No Logs" --msgbox "No recent logs found for wifi-auto-connect service." 8 50
                fi
                ;;
            7)
                dialog --title "Restarting..." --infobox "Restarting WiFi auto-connect service..." 5 50
                if sudo systemctl restart wifi-auto-connect.service 2>/dev/null; then
                    dialog --title "Service Restarted" --msgbox "WiFi auto-connect service restarted successfully." 8 50
                else
                    dialog --title "Restart Failed" --msgbox "Failed to restart WiFi auto-connect service." 8 50
                fi
                ;;
            8)
                return
                ;;
        esac
    done
    rm -f "$TEMP_DIR/service_choice"
}

# Additional WiFi utility functions
network_diagnostics() {
    dialog --title "Network Diagnostics" --msgbox "Running network diagnostics...\n\nThis will check:\n• Interface status\n• Driver information\n• Signal strength\n• Connection quality" 12 60

    clear
    echo -e "${GREEN}WiFi Network Diagnostics${NC}"
    echo "========================="
    echo ""

    # Interface information
    echo "WiFi Interface Information:"
    ip link show | grep -E "wl|wlan" || echo "No WiFi interface found"
    echo ""

    # Current connection
    echo "Current Connection:"
    iwgetid -r 2>/dev/null || echo "Not connected"
    echo ""

    # Signal information
    echo "Signal Information:"
    local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
    if [ -n "$wifi_iface" ]; then
        iwconfig "$wifi_iface" 2>/dev/null | grep -E "(ESSID|Frequency|Access Point|Bit Rate|Signal level)" || echo "No detailed signal info available"
    fi
    echo ""

    echo "Press any key to return to menu..."
    read -n 1
}

interface_management() {
    dialog --title "Interface Management" --msgbox "WiFi Interface Management\n\nThis will show interface controls and management options." 10 60
}

view_wifi_logs() {
    local log_file="/var/log/camera-bridge/wifi-auto-connect.log"
    if [ -f "$log_file" ]; then
        local log_content=$(tail -n 50 "$log_file" 2>/dev/null)
        if [ -n "$log_content" ]; then
            dialog --title "WiFi Auto-Connect Logs" --msgbox "$log_content" 24 100
        else
            dialog --title "Empty Log" --msgbox "Log file exists but is empty." 8 40
        fi
    else
        dialog --title "No Log File" --msgbox "WiFi auto-connect log file not found.\n\nLocation: $log_file" 10 60
    fi
}

# Network details function
show_network_details() {
    dialog --title "Network Details" --msgbox "Network details feature coming soon!\n\nThis will show:\n• Signal strength for saved networks\n• Last connection time\n• Connection history\n• Security information\n• Auto-connect settings per network" 12 60
}

# Auto-connect settings function
auto_connect_settings() {
    dialog --title "Auto-Connect Settings" --msgbox "Auto-connect settings coming soon!\n\nThis will allow:\n• Enable/disable auto-connect globally\n• Set connection retry attempts\n• Configure connection timeouts\n• Manage network priority\n• Set preferred connection order" 12 60
}

dropbox_menu() { dialog --title "Dropbox Menu" --msgbox "Dropbox management functionality" 8 40; }
view_logs() { dialog --title "View Logs" --msgbox "Log viewing functionality" 8 40; }
network_settings() { dialog --title "Network Settings" --msgbox "Network settings functionality" 8 40; }
service_management() { dialog --title "Service Management" --msgbox "Service management functionality" 8 40; }
file_management() { dialog --title "File Management" --msgbox "File management functionality" 8 40; }
system_info() {
    local sys_info="SYSTEM INFORMATION
==================

Hardware:
• CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs 2>/dev/null || echo 'Unknown')
• Memory: $(lsmem | grep 'Total online memory' | awk '{print $4}' 2>/dev/null || free -h | grep 'Mem:' | awk '{print $2}')
• Storage: $(lsblk | grep disk | awk '{print $4}' | head -1 2>/dev/null || echo 'Unknown')

Network Interfaces:
$(ip link show | grep -E '^[0-9]+:' | awk -F: '{print "• " $2}' | sed 's/^ *//' | head -5)

WiFi Access Point:
• SSID: CameraBridge-Setup
• Password: camera123
• Network: 192.168.50.0/24
• Status: $(systemctl is-active hostapd 2>/dev/null || echo 'inactive')

Ethernet Bridge:
• Network: 192.168.10.0/24
• Interface: eno1
• DHCP Range: 192.168.10.10-100

Operating System:
• $(lsb_release -d 2>/dev/null | awk -F: '{print $2}' | xargs || echo 'Linux')
• Kernel: $(uname -r)
• Architecture: $(uname -m)

Camera Bridge:
• Version: 1.1
• Install Path: /opt/camera-bridge
• Mode: $(get_operation_mode)"

    dialog --title "System Information" --msgbox "$sys_info" 24 75
}
maintenance_menu() { dialog --title "Maintenance" --msgbox "Maintenance tools functionality" 8 40; }
setup_wizard() { dialog --title "Setup Wizard" --msgbox "Quick setup wizard functionality" 8 40; }
help_about() { dialog --title "Help & About" --msgbox "Help and about functionality" 8 40; }
mode_configuration() { dialog --title "Mode Config" --msgbox "Mode configuration functionality" 8 40; }
mount_usb_storage() { dialog --title "Mount Storage" --msgbox "USB storage mount functionality" 8 40; }
unmount_usb_storage() { dialog --title "Unmount Storage" --msgbox "USB storage unmount functionality" 8 40; }
reset_usb_gadget() { dialog --title "Reset USB" --msgbox "USB gadget reset functionality" 8 40; }

# Run main function
main "$@"