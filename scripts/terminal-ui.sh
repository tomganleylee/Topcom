#!/bin/bash

# Terminal UI for Camera Bridge Management
# Provides a comprehensive interface for local system management

DIALOG_HEIGHT=20
DIALOG_WIDTH=70
TITLE="Camera Bridge Manager"

# Color definitions for non-dialog output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Temporary files for dialog operations
TEMP_DIR="/tmp/camera-bridge-ui"
mkdir -p "$TEMP_DIR"

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

# Main menu
show_main_menu() {
    while true; do
        dialog --title "$TITLE" --menu "Choose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 12 \
            1 "WiFi Status & Management" \
            2 "Dropbox Configuration" \
            3 "System Status" \
            4 "View Logs" \
            5 "Network Settings" \
            6 "Service Management" \
            7 "File Management" \
            8 "System Information" \
            9 "Maintenance Tools" \
            10 "Quick Setup Wizard" \
            11 "Help & About" \
            12 "Exit" 2>"$TEMP_DIR/menu_choice"

        if [ $? -ne 0 ]; then
            exit 0
        fi

        choice=$(cat "$TEMP_DIR/menu_choice")
        case $choice in
            1) wifi_menu ;;
            2) dropbox_menu ;;
            3) system_status ;;
            4) view_logs ;;
            5) network_settings ;;
            6) service_management ;;
            7) file_management ;;
            8) system_info ;;
            9) maintenance_menu ;;
            10) setup_wizard ;;
            11) help_about ;;
            12) exit 0 ;;
            *) show_main_menu ;;
        esac
    done
}

# WiFi management menu
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

        dialog --title "WiFi Management" --menu "$status_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
            1 "Show WiFi Status" \
            2 "Scan Networks" \
            3 "Connect to Network" \
            4 "Manual Connection" \
            5 "Start Setup Hotspot" \
            6 "Stop Setup Hotspot" \
            7 "Monitor Connection" \
            8 "Reset WiFi Settings" \
            9 "Advanced WiFi Tools" \
            10 "Back to Main Menu" 2>"$TEMP_DIR/wifi_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/wifi_choice")
        case $choice in
            1) show_wifi_status ;;
            2) scan_and_connect ;;
            3) scan_and_connect ;;
            4) manual_connect ;;
            5) start_hotspot ;;
            6) stop_hotspot ;;
            7) monitor_wifi ;;
            8) reset_wifi ;;
            9) advanced_wifi_menu ;;
            10) return ;;
            *) ;;
        esac
    done
}

show_wifi_status() {
    local status_info
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        status_info=$(sudo /opt/camera-bridge/scripts/wifi-manager.sh status 2>&1)
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        status_info=$(sudo $HOME/camera-bridge/scripts/wifi-manager.sh status 2>&1)
    else
        status_info="WiFi manager script not found"
    fi

    dialog --title "WiFi Status" --msgbox "$status_info" 15 60
}

scan_and_connect() {
    dialog --title "Scanning..." --infobox "Scanning for WiFi networks..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found" 8 40
        return
    fi

    # Scan for networks
    local networks
    networks=$(sudo "$wifi_script" scan 2>/dev/null)

    if [ -z "$networks" ]; then
        dialog --title "No Networks" --msgbox "No WiFi networks found." 8 40
        return
    fi

    # Create menu options
    local menu_options=""
    local i=1
    while IFS= read -r network; do
        if [ -n "$network" ] && [ "$network" != "Not connected" ]; then
            menu_options="$menu_options $i \"$network\""
            i=$((i+1))
        fi
    done <<< "$networks"

    if [ -z "$menu_options" ]; then
        dialog --title "No Networks" --msgbox "No valid WiFi networks found." 8 40
        return
    fi

    # Show network selection
    eval "dialog --title 'Available Networks' --menu 'Select a network:' $DIALOG_HEIGHT $DIALOG_WIDTH 10 $menu_options" 2>"$TEMP_DIR/network_choice"

    if [ $? -eq 0 ]; then
        choice=$(cat "$TEMP_DIR/network_choice")
        selected_network=$(echo "$networks" | sed -n "${choice}p")

        # Get password
        dialog --title "WiFi Password" --passwordbox "Enter password for $selected_network:" 10 50 2>"$TEMP_DIR/wifi_password"

        if [ $? -eq 0 ]; then
            password=$(cat "$TEMP_DIR/wifi_password")

            dialog --title "Connecting..." --infobox "Connecting to $selected_network..." 5 50

            if sudo "$wifi_script" connect "$selected_network" "$password" >/dev/null 2>&1; then
                dialog --title "Success" --msgbox "Connected to $selected_network successfully!" 8 50
            else
                dialog --title "Error" --msgbox "Failed to connect to $selected_network\n\nCheck password and try again." 10 50
            fi
        fi
    fi

    rm -f "$TEMP_DIR/wifi_password"
}

manual_connect() {
    dialog --title "Manual WiFi Connection" --inputbox "Enter SSID:" 10 50 2>"$TEMP_DIR/manual_ssid"

    if [ $? -eq 0 ]; then
        ssid=$(cat "$TEMP_DIR/manual_ssid")
        if [ -n "$ssid" ]; then
            dialog --title "WiFi Password" --passwordbox "Enter password for $ssid:" 10 50 2>"$TEMP_DIR/manual_password"

            if [ $? -eq 0 ]; then
                password=$(cat "$TEMP_DIR/manual_password")

                dialog --title "Connecting..." --infobox "Connecting to $ssid..." 5 50

                # Find WiFi manager script
                local wifi_script=""
                if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
                    wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
                elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
                    wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
                fi

                if [ -n "$wifi_script" ]; then
                    if sudo "$wifi_script" connect "$ssid" "$password" >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Connected to $ssid successfully!" 8 50
                    else
                        dialog --title "Error" --msgbox "Failed to connect to $ssid" 8 50
                    fi
                else
                    dialog --title "Error" --msgbox "WiFi manager script not found" 8 40
                fi
            fi
        fi
    fi

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

# Dropbox configuration menu
dropbox_menu() {
    while true; do
        # Check if Dropbox is configured
        local status="Not configured"
        if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ] && grep -q "\[dropbox\]" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
            status="Configured"
        fi

        dialog --title "Dropbox Configuration" --menu "Status: $status\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
            1 "Test Dropbox Connection" \
            2 "Configure Dropbox Token" \
            3 "View Dropbox Status" \
            4 "Manual Sync Now" \
            5 "View Sync Logs" \
            6 "Dropbox Settings" \
            7 "Back to Main Menu" 2>"$TEMP_DIR/dropbox_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/dropbox_choice")
        case $choice in
            1) test_dropbox ;;
            2) configure_dropbox ;;
            3) view_dropbox_status ;;
            4) manual_sync ;;
            5) view_sync_logs ;;
            6) dropbox_settings ;;
            7) return ;;
            *) ;;
        esac
    done
}

configure_dropbox() {
    dialog --title "Dropbox Setup" --msgbox "To configure Dropbox:\n\n1. Visit dropbox.com/developers/apps\n2. Create new app (App folder access)\n3. Generate access token\n4. Enter token in next screen\n\nNote: The token will be stored securely for the camerabridge user." 15 70

    dialog --title "Dropbox Token" --inputbox "Enter your Dropbox access token:" 10 70 2>"$TEMP_DIR/dropbox_token"

    if [ $? -eq 0 ]; then
        token=$(cat "$TEMP_DIR/dropbox_token")
        if [ -n "$token" ]; then
            # Create rclone config
            sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone 2>/dev/null || sudo mkdir -p /home/camerabridge/.config/rclone

            cat > "$TEMP_DIR/rclone.conf" << EOF
[dropbox]
type = dropbox
token = {"access_token":"$token","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
EOF

            sudo cp "$TEMP_DIR/rclone.conf" /home/camerabridge/.config/rclone/rclone.conf
            sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null || true
            sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

            # Test connection
            if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
                dialog --title "Success" --msgbox "Dropbox configured successfully!\n\nThe camera bridge will now sync photos to your Dropbox automatically." 10 50
            else
                dialog --title "Error" --msgbox "Failed to connect to Dropbox.\n\nPlease check your token and try again." 10 60
            fi
        fi
    fi

    rm -f "$TEMP_DIR/dropbox_token" "$TEMP_DIR/rclone.conf"
}

test_dropbox() {
    dialog --title "Testing..." --infobox "Testing Dropbox connection..." 5 40

    if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        dialog --title "Test Result" --msgbox "Dropbox connection: OK ✓\n\nYour Dropbox is properly configured and accessible." 8 40
    else
        dialog --title "Test Result" --msgbox "Dropbox connection: FAILED ✗\n\nPlease check your configuration and internet connection." 10 50
    fi
}

view_dropbox_status() {
    local info
    if command -v rclone >/dev/null 2>&1 && sudo -u camerabridge rclone about dropbox: >/dev/null 2>&1; then
        info=$(sudo -u camerabridge rclone about dropbox: 2>/dev/null | head -10)
        if [ -n "$info" ]; then
            dialog --title "Dropbox Status" --msgbox "$info" 15 70
        else
            dialog --title "Dropbox Status" --msgbox "Connected to Dropbox, but unable to retrieve detailed information." 8 50
        fi
    else
        dialog --title "Dropbox Status" --msgbox "Cannot connect to Dropbox.\n\nPlease check your configuration." 8 50
    fi
}

manual_sync() {
    dialog --title "Manual Sync" --infobox "Starting manual sync to Dropbox...\nThis may take a while depending on the number of files." 6 60

    clear
    echo -e "${GREEN}Manual Dropbox Sync${NC}"
    echo "Syncing photos to Dropbox..."
    echo ""

    if sudo -u camerabridge rclone sync /srv/samba/camera-share dropbox:Camera-Photos --include "*.{jpg,jpeg,png,tiff,raw,dng,cr2,nef,orf,arw,JPG,JPEG,PNG,TIFF,RAW,DNG,CR2,NEF,ORF,ARW}" --progress 2>&1; then
        echo ""
        echo -e "${GREEN}✓ Manual sync completed successfully!${NC}"
    else
        echo ""
        echo -e "${RED}✗ Manual sync failed. Check logs for details.${NC}"
    fi

    echo ""
    echo "Press any key to continue..."
    read -n 1
}

# System status
system_status() {
    # Gather system information
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' 2>/dev/null || echo "N/A")
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df -h / | awk 'NR==2{printf "%s", $5}' 2>/dev/null || echo "N/A")
    local uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' 2>/dev/null || echo "N/A")

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

    local status_info="SYSTEM STATUS
================

Hardware:
• CPU Usage: ${cpu_usage}%
• Memory Usage: ${memory_usage}
• Disk Usage: ${disk_usage}
• Uptime: ${uptime_info}

Services:
• Camera Bridge: ${bridge_status}
• SMB Server: ${smb_status}

Network:
• ${wifi_status}
• $(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "IP: " $2}' | head -1)

Recent Activity:
• $(find /srv/samba/camera-share -type f -mtime -1 2>/dev/null | wc -l) files added today
• Log size: $(du -h /var/log/camera-bridge/service.log 2>/dev/null | cut -f1 || echo "0B")"

    dialog --title "System Status" --msgbox "$status_info" 22 70
}

# View logs
view_logs() {
    dialog --title "Log Viewer" --menu "Select log to view:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
        1 "Camera Bridge Service Log" \
        2 "WiFi Manager Log" \
        3 "System Log (last 50 lines)" \
        4 "Samba Log" \
        5 "Nginx Error Log" \
        6 "All Logs Summary" \
        7 "Back to Main Menu" 2>"$TEMP_DIR/log_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/log_choice")
    case $choice in
        1)
            if [ -f "/var/log/camera-bridge/service.log" ]; then
                dialog --title "Camera Bridge Service Log" --textbox /var/log/camera-bridge/service.log 22 90
            else
                dialog --title "No Log" --msgbox "Camera bridge service log not found" 8 40
            fi
            ;;
        2)
            if [ -f "/var/log/camera-bridge/wifi.log" ]; then
                dialog --title "WiFi Manager Log" --textbox /var/log/camera-bridge/wifi.log 22 90
            else
                dialog --title "No Log" --msgbox "WiFi manager log not found" 8 40
            fi
            ;;
        3)
            journalctl -n 50 > "$TEMP_DIR/system.log" 2>/dev/null
            dialog --title "System Log" --textbox "$TEMP_DIR/system.log" 22 90
            ;;
        4)
            if [ -f "/var/log/samba/log.smbd" ]; then
                tail -50 /var/log/samba/log.smbd > "$TEMP_DIR/samba.log" 2>/dev/null
                dialog --title "Samba Log" --textbox "$TEMP_DIR/samba.log" 22 90
            else
                dialog --title "No Log" --msgbox "Samba log not found" 8 40
            fi
            ;;
        5)
            if [ -f "/var/log/nginx/error.log" ]; then
                tail -50 /var/log/nginx/error.log > "$TEMP_DIR/nginx.log" 2>/dev/null
                dialog --title "Nginx Error Log" --textbox "$TEMP_DIR/nginx.log" 22 90
            else
                dialog --title "No Log" --msgbox "Nginx error log not found" 8 40
            fi
            ;;
        6) show_logs_summary ;;
        7) return ;;
    esac

    view_logs
}

show_logs_summary() {
    local summary="LOG SUMMARY
===========

"

    # Camera Bridge Service
    if [ -f "/var/log/camera-bridge/service.log" ]; then
        local bridge_lines=$(wc -l < /var/log/camera-bridge/service.log 2>/dev/null || echo "0")
        local bridge_errors=$(grep -c "ERROR" /var/log/camera-bridge/service.log 2>/dev/null || echo "0")
        summary="$summary• Service Log: $bridge_lines lines, $bridge_errors errors
"
    fi

    # System errors
    local sys_errors=$(journalctl -p err --since "24 hours ago" | wc -l 2>/dev/null || echo "0")
    summary="$summary• System Errors (24h): $sys_errors
"

    # Disk space
    local log_size=$(du -sh /var/log 2>/dev/null | cut -f1 || echo "Unknown")
    summary="$summary• Total log disk usage: $log_size

Recent Events:
$(journalctl --since "1 hour ago" -n 5 --no-pager 2>/dev/null | tail -5)"

    dialog --title "Logs Summary" --msgbox "$summary" 20 80
}

# Network settings
network_settings() {
    dialog --title "Network Settings" --menu "Choose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
        1 "Show IP Configuration" \
        2 "Show Network Interfaces" \
        3 "Network Diagnostics" \
        4 "Restart Networking" \
        5 "Firewall Status" \
        6 "Port Scanner" \
        7 "Back to Main Menu" 2>"$TEMP_DIR/network_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/network_choice")
    case $choice in
        1)
            ip_info=$(ip addr show 2>/dev/null | grep -E "(inet |UP)")
            dialog --title "IP Configuration" --msgbox "$ip_info" 15 80
            ;;
        2)
            interface_info=$(ip link show 2>/dev/null)
            dialog --title "Network Interfaces" --msgbox "$interface_info" 15 80
            ;;
        3) network_diagnostics ;;
        4)
            dialog --title "Restarting..." --infobox "Restarting network services..." 5 40
            sudo systemctl restart NetworkManager 2>/dev/null || sudo systemctl restart networking 2>/dev/null || true
            sleep 3
            dialog --title "Complete" --msgbox "Network services restarted" 8 40
            ;;
        5) show_firewall_status ;;
        6) port_scanner ;;
        7) return ;;
    esac

    network_settings
}

network_diagnostics() {
    dialog --title "Running Diagnostics..." --infobox "Running network diagnostics...\nThis may take a moment." 6 50

    local diag_result="NETWORK DIAGNOSTICS
===================

"

    # Test internet connectivity
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        diag_result="$diag_result✓ Internet connectivity: OK
"
    else
        diag_result="$diag_result✗ Internet connectivity: FAILED
"
    fi

    # Test DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        diag_result="$diag_result✓ DNS resolution: OK
"
    else
        diag_result="$diag_result✗ DNS resolution: FAILED
"
    fi

    # Check default gateway
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ] && ping -c 1 "$gateway" >/dev/null 2>&1; then
        diag_result="$diag_result✓ Gateway ($gateway): OK
"
    else
        diag_result="$diag_result✗ Gateway: FAILED or not found
"
    fi

    diag_result="$diag_result
Network Configuration:
$(ip addr show | grep -E '(inet |state)')"

    dialog --title "Network Diagnostics" --msgbox "$diag_result" 20 80
}

# Service management
service_management() {
    dialog --title "Service Management" --menu "Choose service to manage:" $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
        1 "Camera Bridge Service" \
        2 "SMB/Samba Server" \
        3 "WiFi Services" \
        4 "Web Server (Nginx)" \
        5 "All Services Status" \
        6 "Start All Services" \
        7 "Restart All Services" \
        8 "Service Logs" \
        9 "Back to Main Menu" 2>"$TEMP_DIR/service_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/service_choice")
    case $choice in
        1) manage_camera_bridge_service ;;
        2) manage_smb_service ;;
        3) manage_wifi_services ;;
        4) manage_web_service ;;
        5) show_all_services_status ;;
        6) start_all_services ;;
        7) restart_all_services ;;
        8) view_logs ;;
        9) return ;;
    esac

    service_management
}

manage_camera_bridge_service() {
    local status="Unknown"
    if systemctl is-active --quiet camera-bridge 2>/dev/null; then
        status="Running"
    elif [ -f "/var/run/camera-bridge.pid" ] && kill -0 "$(cat /var/run/camera-bridge.pid)" 2>/dev/null; then
        status="Running (manual)"
    else
        status="Stopped"
    fi

    dialog --title "Camera Bridge Service ($status)" --menu "Choose action:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
        1 "Start Service" \
        2 "Stop Service" \
        3 "Restart Service" \
        4 "View Status" \
        5 "Test Dropbox Connection" \
        6 "Manual Sync" \
        7 "Back" 2>"$TEMP_DIR/bridge_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/bridge_choice")
    case $choice in
        1)
            sudo systemctl start camera-bridge 2>/dev/null || {
                # Try starting manually if systemd service doesn't exist
                local script_path="/opt/camera-bridge/scripts/camera-bridge-service.sh"
                if [ -x "$script_path" ]; then
                    sudo "$script_path" start &
                fi
            }
            dialog --title "Service" --msgbox "Camera Bridge service start command issued" 8 40
            ;;
        2)
            sudo systemctl stop camera-bridge 2>/dev/null || {
                local script_path="/opt/camera-bridge/scripts/camera-bridge-service.sh"
                if [ -x "$script_path" ]; then
                    sudo "$script_path" stop
                fi
            }
            dialog --title "Service" --msgbox "Camera Bridge service stopped" 8 40
            ;;
        3)
            sudo systemctl restart camera-bridge 2>/dev/null || {
                local script_path="/opt/camera-bridge/scripts/camera-bridge-service.sh"
                if [ -x "$script_path" ]; then
                    sudo "$script_path" restart &
                fi
            }
            dialog --title "Service" --msgbox "Camera Bridge service restarted" 8 40
            ;;
        4)
            local detailed_status=$(systemctl status camera-bridge 2>/dev/null || echo "Systemd service not available")
            dialog --title "Service Status" --msgbox "$detailed_status" 15 80
            ;;
        5) test_dropbox ;;
        6) manual_sync ;;
        7) return ;;
    esac

    manage_camera_bridge_service
}

# System information
system_info() {
    local sys_info="SYSTEM INFORMATION
==================

Hardware:
• CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs 2>/dev/null || echo 'Unknown')
• Memory: $(lsmem | grep 'Total online memory' | awk '{print $4}' 2>/dev/null || free -h | grep 'Mem:' | awk '{print $2}')
• Storage: $(lsblk | grep disk | awk '{print $4}' | head -1 2>/dev/null || echo 'Unknown')

Network Interfaces:
$(ip link show | grep -E '^[0-9]+:' | awk -F: '{print "• " $2}' | sed 's/^ *//' | head -5)

Operating System:
• $(lsb_release -d 2>/dev/null | awk -F: '{print $2}' | xargs || echo 'Linux')
• Kernel: $(uname -r)
• Architecture: $(uname -m)

Camera Bridge:
• Version: 1.0
• Install Path: /opt/camera-bridge
• Config Path: /home/camerabridge/.config"

    dialog --title "System Information" --msgbox "$sys_info" 20 70
}

# Help and about
help_about() {
    local help_text="CAMERA BRIDGE MANAGER
=====================

This terminal interface helps you manage your Camera Bridge system.

Key Features:
• WiFi network management and monitoring
• Dropbox configuration and sync management
• System status monitoring and diagnostics
• Log viewing and troubleshooting
• Service management and control

Navigation:
• Use arrow keys to navigate menus
• Press Enter to select options
• Press Esc or Cancel to go back
• Use Tab to switch between buttons

Quick Tips:
• Check System Status for overall health
• Use WiFi Management for connectivity issues
• Configure Dropbox for automatic photo sync
• View Logs for troubleshooting problems
• Use Service Management to control services

For web interface:
• Connect to http://[device-ip] for setup
• Or use hotspot mode at http://192.168.4.1

Version: 1.0
Created for automatic camera photo syncing"

    dialog --title "Help & About" --msgbox "$help_text" 22 70
}

# Setup wizard
setup_wizard() {
    if dialog --title "Setup Wizard" --yesno "Welcome to the Camera Bridge Setup Wizard!\n\nThis will guide you through the basic configuration:\n• WiFi connection\n• Dropbox setup\n• Service configuration\n\nDo you want to continue?" 12 60; then
        # Step 1: WiFi
        if dialog --title "Setup: WiFi" --yesno "Step 1: WiFi Configuration\n\nDo you want to configure WiFi now?\n\nNote: You can also use the setup hotspot mode instead." 10 60; then
            scan_and_connect
        fi

        # Step 2: Dropbox
        if dialog --title "Setup: Dropbox" --yesno "Step 2: Dropbox Configuration\n\nDo you want to configure Dropbox sync now?\n\nThis requires a Dropbox developer token." 10 60; then
            configure_dropbox
        fi

        # Step 3: Services
        dialog --title "Setup: Services" --infobox "Step 3: Starting services..." 5 40
        start_all_services
        sleep 2

        dialog --title "Setup Complete" --msgbox "Basic setup is complete!\n\n• WiFi: $(iwgetid -r 2>/dev/null || echo 'Not configured')\n• Dropbox: $([ -f '/home/camerabridge/.config/rclone/rclone.conf' ] && echo 'Configured' || echo 'Not configured')\n• Services: Started\n\nYou can now connect cameras to the SMB share and photos will automatically sync to Dropbox." 12 60
    fi
}

# Additional helper functions
start_all_services() {
    sudo systemctl start nginx smbd nmbd 2>/dev/null || true
    sudo systemctl start camera-bridge 2>/dev/null || {
        local script_path="/opt/camera-bridge/scripts/camera-bridge-service.sh"
        if [ -x "$script_path" ]; then
            sudo "$script_path" start &
        fi
    }
}

restart_all_services() {
    dialog --title "Restarting Services..." --infobox "Restarting all camera bridge services..." 5 50
    sudo systemctl restart nginx smbd nmbd camera-bridge 2>/dev/null || true
    sleep 3
    dialog --title "Complete" --msgbox "All services restarted" 8 40
}

show_all_services_status() {
    local status_text="SERVICE STATUS
==============

"

    # Check each service
    for service in camera-bridge nginx smbd nmbd hostapd dnsmasq; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status_text="$status_text• $service: Running ✓
"
        else
            status_text="$status_text• $service: Stopped ✗
"
        fi
    done

    dialog --title "All Services Status" --msgbox "$status_text" 15 40
}

# File management functions
file_management() {
    dialog --title "File Management" --menu "Choose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
        1 "Browse Camera Share" \
        2 "Check Disk Space" \
        3 "Recent Photos" \
        4 "Cleanup Old Files" \
        5 "Backup Configuration" \
        6 "Import Configuration" \
        7 "Back to Main Menu" 2>"$TEMP_DIR/file_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/file_choice")
    case $choice in
        1) browse_camera_share ;;
        2) check_disk_space ;;
        3) show_recent_photos ;;
        4) cleanup_files ;;
        5) backup_config ;;
        6) import_config ;;
        7) return ;;
    esac

    file_management
}

browse_camera_share() {
    local share_path="/srv/samba/camera-share"
    if [ -d "$share_path" ]; then
        local file_count=$(find "$share_path" -type f 2>/dev/null | wc -l)
        local total_size=$(du -sh "$share_path" 2>/dev/null | cut -f1)
        local recent_files=$(find "$share_path" -type f -mtime -7 2>/dev/null | head -10 | sed 's|.*/||')

        local browse_info="CAMERA SHARE CONTENTS
=====================

Path: $share_path
Total Files: $file_count
Total Size: $total_size

Recent Files (last 7 days):
$recent_files"

        dialog --title "Camera Share Browser" --msgbox "$browse_info" 18 70
    else
        dialog --title "Error" --msgbox "Camera share directory not found: $share_path" 8 60
    fi
}

# Maintenance menu
maintenance_menu() {
    dialog --title "Maintenance Tools" --menu "Choose maintenance task:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
        1 "System Health Check" \
        2 "Clear Temp Files" \
        3 "Rotate Log Files" \
        4 "Update System Packages" \
        5 "Reset to Defaults" \
        6 "Create System Backup" \
        7 "Back to Main Menu" 2>"$TEMP_DIR/maint_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/maint_choice")
    case $choice in
        1) system_health_check ;;
        2) clear_temp_files ;;
        3) rotate_logs ;;
        4) update_system ;;
        5) reset_to_defaults ;;
        6) create_backup ;;
        7) return ;;
    esac

    maintenance_menu
}

system_health_check() {
    dialog --title "Running Health Check..." --infobox "Performing system health check...\nThis may take a moment." 6 50

    local health_report="SYSTEM HEALTH CHECK
===================

"

    # Check disk space
    local disk_usage=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        health_report="$health_report✗ Disk Usage: ${disk_usage}% (Critical)
"
    elif [ "$disk_usage" -gt 75 ]; then
        health_report="$health_report⚠ Disk Usage: ${disk_usage}% (Warning)
"
    else
        health_report="$health_report✓ Disk Usage: ${disk_usage}% (OK)
"
    fi

    # Check memory
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    if [ "$mem_usage" -gt 90 ]; then
        health_report="$health_report✗ Memory Usage: ${mem_usage}% (High)
"
    else
        health_report="$health_report✓ Memory Usage: ${mem_usage}% (OK)
"
    fi

    # Check services
    local services_down=0
    for service in camera-bridge smbd nginx; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            services_down=$((services_down + 1))
        fi
    done

    if [ "$services_down" -eq 0 ]; then
        health_report="$health_report✓ All critical services running
"
    else
        health_report="$health_report⚠ $services_down critical service(s) down
"
    fi

    # Check connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        health_report="$health_report✓ Internet connectivity: OK
"
    else
        health_report="$health_report✗ Internet connectivity: Failed
"
    fi

    health_report="$health_report
Recommendations:
• Monitor disk usage regularly
• Keep system updated
• Check logs for errors
• Ensure reliable internet connection"

    dialog --title "System Health Check" --msgbox "$health_report" 18 60
}

# Advanced WiFi menu
advanced_wifi_menu() {
    dialog --title "Advanced WiFi Tools" --menu "Choose advanced option:" $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
        1 "WiFi Interface Details" \
        2 "Signal Strength Monitor" \
        3 "Network Security Scan" \
        4 "WiFi Configuration Backup" \
        5 "Manual iwconfig Commands" \
        6 "Reset WiFi Hardware" \
        7 "Back to WiFi Menu" 2>"$TEMP_DIR/adv_wifi_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/adv_wifi_choice")
    case $choice in
        1) show_wifi_interface_details ;;
        2) monitor_signal_strength ;;
        3) scan_network_security ;;
        4) backup_wifi_config ;;
        5) manual_iwconfig ;;
        6) reset_wifi_hardware ;;
        7) return ;;
    esac

    advanced_wifi_menu
}

show_wifi_interface_details() {
    local wifi_details="WIFI INTERFACE DETAILS
======================

$(iwconfig wlan0 2>/dev/null || echo "Interface not available")

$(ip addr show wlan0 2>/dev/null || echo "No IP information available")

Driver Information:
$(lspci | grep -i wireless || echo "No wireless adapter found in PCI")
$(lsusb | grep -i wireless || echo "No wireless adapter found in USB")"

    dialog --title "WiFi Interface Details" --msgbox "$wifi_details" 20 80
}

# Initialize and start
main() {
    check_dialog
    check_permissions

    # Create log directory if needed
    sudo mkdir -p /var/log/camera-bridge 2>/dev/null || true

    clear
    show_main_menu
}

# Run main function
main "$@"