#!/bin/bash

# Camera Bridge Terminal UI v2.0
# Complete UI with all production fixes

DIALOG_HEIGHT=22
DIALOG_WIDTH=75
TITLE="Camera Bridge Manager v2.0"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect network interfaces
WIFI_INTERFACE=$(ip link | grep -E "^[0-9]+: w" | cut -d: -f2 | tr -d ' ' | head -1)
ETH_INTERFACE=$(ip link | grep -E "^[0-9]+: e" | cut -d: -f2 | tr -d ' ' | head -1)

# Default to common names if not detected
: ${WIFI_INTERFACE:=wlan0}
: ${ETH_INTERFACE:=eth0}

# Temporary directory
TEMP_DIR="/tmp/camera-bridge-ui"
mkdir -p "$TEMP_DIR"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
    clear
}
trap cleanup EXIT

# Check prerequisites
check_requirements() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo -e "${RED}Error: 'dialog' is not installed. Please install it:${NC}"
        echo "sudo apt install dialog"
        exit 1
    fi

    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Some functions require root. Run with sudo for full functionality.${NC}"
        sleep 2
    fi
}

# Main Menu
show_main_menu() {
    while true; do
        dialog --title "$TITLE" \
            --menu "Network: WiFi($WIFI_INTERFACE) Eth($ETH_INTERFACE)\n\nSelect an option:" \
            20 70 12 \
            1 "📡 WiFi Configuration" \
            2 "💾 Dropbox Setup" \
            3 "📊 System Status" \
            4 "🔧 Service Management" \
            5 "📁 File Management" \
            6 "🌐 Network Settings" \
            7 "📋 View Logs" \
            8 "🔄 Quick Setup Wizard" \
            9 "ℹ️  System Information" \
            10 "🛠️  Maintenance Tools" \
            11 "❓ Help & About" \
            12 "🚪 Exit" \
            2>"$TEMP_DIR/menu_choice"

        if [ $? -ne 0 ]; then
            break
        fi

        choice=$(cat "$TEMP_DIR/menu_choice")

        case $choice in
            1) wifi_configuration ;;
            2) dropbox_setup ;;
            3) system_status ;;
            4) service_management ;;
            5) file_management ;;
            6) network_settings ;;
            7) view_logs ;;
            8) quick_setup_wizard ;;
            9) system_information ;;
            10) maintenance_tools ;;
            11) show_help ;;
            12) break ;;
        esac
    done
}

# WiFi Configuration
wifi_configuration() {
    local submenu=true
    while $submenu; do
        dialog --title "WiFi Configuration" \
            --menu "WiFi Interface: $WIFI_INTERFACE\n\nSelect an option:" \
            15 60 6 \
            1 "View Current Status" \
            2 "Scan for Networks" \
            3 "Connect to Network" \
            4 "Disconnect" \
            5 "Show Saved Networks" \
            6 "Back to Main Menu" \
            2>"$TEMP_DIR/wifi_choice"

        if [ $? -ne 0 ]; then
            submenu=false
            continue
        fi

        case $(cat "$TEMP_DIR/wifi_choice") in
            1) wifi_status ;;
            2) scan_wifi_networks ;;
            3) connect_to_wifi ;;
            4) disconnect_wifi ;;
            5) show_saved_networks ;;
            6) submenu=false ;;
        esac
    done
}

# WiFi Status
wifi_status() {
    local status_info=""

    # Check if connected
    local ssid=$(iwgetid -r 2>/dev/null || echo "Not connected")
    local ip=$(ip addr show $WIFI_INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    status_info="Interface: $WIFI_INTERFACE\n"
    status_info+="SSID: $ssid\n"
    status_info+="IP Address: ${ip:-No IP assigned}\n"

    # Signal strength if connected
    if [ "$ssid" != "Not connected" ]; then
        local signal=$(iwconfig $WIFI_INTERFACE 2>/dev/null | grep "Link Quality" | awk '{print $2}' | cut -d= -f2)
        status_info+="\nSignal: $signal"
    fi

    dialog --title "WiFi Status" --msgbox "$status_info" 12 50
}

# Scan WiFi Networks
scan_wifi_networks() {
    dialog --infobox "Scanning for WiFi networks..." 3 40

    # Scan and format results
    sudo iwlist $WIFI_INTERFACE scan 2>/dev/null | \
        grep -E "ESSID:|Signal level" | \
        sed 'N;s/\n/ /' | \
        sed 's/.*Signal level=/Signal: /; s/.*ESSID:"/SSID: /; s/"//' | \
        head -10 > "$TEMP_DIR/scan_results"

    if [ -s "$TEMP_DIR/scan_results" ]; then
        dialog --title "Available Networks" \
            --textbox "$TEMP_DIR/scan_results" 20 70
    else
        dialog --title "Scan Results" \
            --msgbox "No networks found or scanning failed.\n\nMake sure WiFi is enabled." 8 50
    fi
}

# Connect to WiFi
connect_to_wifi() {
    # Get SSID
    dialog --title "Connect to WiFi" \
        --inputbox "Enter WiFi network name (SSID):" 8 60 \
        2>"$TEMP_DIR/wifi_ssid"

    if [ $? -ne 0 ] || [ ! -s "$TEMP_DIR/wifi_ssid" ]; then
        return
    fi

    local ssid=$(cat "$TEMP_DIR/wifi_ssid")

    # Get password
    dialog --title "Connect to WiFi" \
        --passwordbox "Enter password for '$ssid':" 8 60 \
        2>"$TEMP_DIR/wifi_pass"

    if [ $? -ne 0 ]; then
        return
    fi

    local password=$(cat "$TEMP_DIR/wifi_pass")

    # Create wpa_supplicant config
    cat > /tmp/wpa_temp.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
}
EOF

    # Apply configuration
    dialog --infobox "Connecting to $ssid..." 3 40

    sudo cp /tmp/wpa_temp.conf /etc/wpa_supplicant/wpa_supplicant.conf
    sudo systemctl restart wpa_supplicant
    sudo dhclient $WIFI_INTERFACE 2>/dev/null

    sleep 3

    # Check if connected
    if iwgetid -r | grep -q "$ssid"; then
        local ip=$(ip addr show $WIFI_INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        dialog --title "Success" \
            --msgbox "Connected to $ssid\n\nIP Address: $ip" 8 50
    else
        dialog --title "Connection Failed" \
            --msgbox "Failed to connect to $ssid\n\nPlease check credentials and try again." 8 50
    fi

    rm -f /tmp/wpa_temp.conf
}

# Disconnect WiFi
disconnect_wifi() {
    sudo ip link set $WIFI_INTERFACE down
    sleep 1
    sudo ip link set $WIFI_INTERFACE up
    dialog --title "WiFi Disconnected" --msgbox "WiFi has been disconnected" 6 40
}

# Show saved networks
show_saved_networks() {
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        grep "ssid=" /etc/wpa_supplicant/wpa_supplicant.conf | \
            sed 's/.*ssid="//' | sed 's/"//' > "$TEMP_DIR/saved_networks"

        if [ -s "$TEMP_DIR/saved_networks" ]; then
            dialog --title "Saved Networks" \
                --textbox "$TEMP_DIR/saved_networks" 15 50
        else
            dialog --title "Saved Networks" \
                --msgbox "No saved networks found" 6 40
        fi
    else
        dialog --title "Saved Networks" \
            --msgbox "No WiFi configuration found" 6 40
    fi
}

# Dropbox Setup
dropbox_setup() {
    local submenu=true
    while $submenu; do
        # Check if configured
        local dropbox_status="Not Configured"
        if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
            if grep -q "dropbox" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
                dropbox_status="Configured ✓"
            fi
        fi

        dialog --title "Dropbox Configuration" \
            --menu "Status: $dropbox_status\n\nSelect an option:" \
            15 60 6 \
            1 "Enter Access Token" \
            2 "Test Connection" \
            3 "View Configuration" \
            4 "Manual Sync Now" \
            5 "Remove Configuration" \
            6 "Back to Main Menu" \
            2>"$TEMP_DIR/dropbox_choice"

        if [ $? -ne 0 ]; then
            submenu=false
            continue
        fi

        case $(cat "$TEMP_DIR/dropbox_choice") in
            1) configure_dropbox_token ;;
            2) test_dropbox_connection ;;
            3) view_dropbox_config ;;
            4) manual_sync ;;
            5) remove_dropbox_config ;;
            6) submenu=false ;;
        esac
    done
}

# Configure Dropbox with Token
configure_dropbox_token() {
    dialog --title "Dropbox Access Token" \
        --inputbox "Enter your Dropbox Access Token:\n\n(Get this from Dropbox App Console)" \
        10 70 \
        2>"$TEMP_DIR/dropbox_token"

    if [ $? -ne 0 ] || [ ! -s "$TEMP_DIR/dropbox_token" ]; then
        return
    fi

    local token=$(cat "$TEMP_DIR/dropbox_token")

    # Create rclone configuration
    sudo mkdir -p /home/camerabridge/.config/rclone

    cat > /tmp/rclone_temp.conf << EOF
[dropbox]
type = dropbox
token = {"access_token":"$token","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
EOF

    sudo cp /tmp/rclone_temp.conf /home/camerabridge/.config/rclone/rclone.conf
    sudo chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone
    sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    rm -f /tmp/rclone_temp.conf

    # Test connection
    dialog --infobox "Testing Dropbox connection..." 3 40

    if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Create Camera-Photos folder
        sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null

        # Restart service
        sudo systemctl restart camera-bridge 2>/dev/null

        dialog --title "Success" \
            --msgbox "Dropbox configured successfully!\n\nPhotos will sync to:\nDropbox/Camera-Photos/" 9 50
    else
        dialog --title "Configuration Failed" \
            --msgbox "Failed to connect to Dropbox.\n\nPlease check your access token." 8 50
    fi
}

# Test Dropbox Connection
test_dropbox_connection() {
    dialog --infobox "Testing Dropbox connection..." 3 40

    if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Get some info
        local folders=$(sudo -u camerabridge rclone lsd dropbox: 2>/dev/null | head -5)
        dialog --title "Connection Successful" \
            --msgbox "✓ Dropbox is connected!\n\nFolders:\n$folders" 15 60
    else
        dialog --title "Connection Failed" \
            --msgbox "✗ Cannot connect to Dropbox\n\nPlease check configuration." 8 50
    fi
}

# View Dropbox Configuration
view_dropbox_config() {
    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        # Don't show the full token for security
        grep -E "^\[|^type" /home/camerabridge/.config/rclone/rclone.conf > "$TEMP_DIR/dropbox_config"
        echo "" >> "$TEMP_DIR/dropbox_config"
        echo "Token: [CONFIGURED]" >> "$TEMP_DIR/dropbox_config"

        dialog --title "Dropbox Configuration" \
            --textbox "$TEMP_DIR/dropbox_config" 12 60
    else
        dialog --title "Dropbox Configuration" \
            --msgbox "No Dropbox configuration found" 6 50
    fi
}

# Manual Sync
manual_sync() {
    dialog --title "Manual Sync" \
        --yesno "Sync all photos from SMB share to Dropbox now?" 7 50

    if [ $? -eq 0 ]; then
        dialog --infobox "Syncing photos to Dropbox..." 3 40

        sudo -u camerabridge rclone copy /srv/samba/camera-share/ dropbox:Camera-Photos/ \
            --include "*.{jpg,jpeg,png,gif,bmp,JPG,JPEG,PNG,GIF,BMP}" \
            --verbose 2>&1 | tail -20 > "$TEMP_DIR/sync_result"

        dialog --title "Sync Complete" \
            --textbox "$TEMP_DIR/sync_result" 20 70
    fi
}

# Remove Dropbox Configuration
remove_dropbox_config() {
    dialog --title "Remove Dropbox" \
        --yesno "Remove Dropbox configuration?\n\nThis will stop automatic syncing." 8 50

    if [ $? -eq 0 ]; then
        sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
        sudo systemctl stop camera-bridge 2>/dev/null

        dialog --title "Configuration Removed" \
            --msgbox "Dropbox configuration has been removed" 6 50
    fi
}

# System Status
system_status() {
    local status=""

    # Service status
    status="SERVICES:\n"
    for service in camera-bridge smbd nginx dnsmasq; do
        if systemctl is-active $service >/dev/null 2>&1; then
            status+="✓ $service: Running\n"
        else
            status+="✗ $service: Stopped\n"
        fi
    done

    # Network status
    status+="\nNETWORK:\n"
    local wifi_ip=$(ip addr show $WIFI_INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    local eth_ip=$(ip addr show $ETH_INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    status+="WiFi ($WIFI_INTERFACE): ${wifi_ip:-Not connected}\n"
    status+="Ethernet ($ETH_INTERFACE): ${eth_ip:-Not configured}\n"

    # SMB Share
    status+="\nSMB SHARE:\n"
    status+="Path: /srv/samba/camera-share\n"
    local file_count=$(ls -1 /srv/samba/camera-share 2>/dev/null | wc -l)
    status+="Files: $file_count\n"

    dialog --title "System Status" --msgbox "$status" 20 60
}

# Service Management
service_management() {
    local submenu=true
    while $submenu; do
        dialog --title "Service Management" \
            --menu "Select a service to manage:" \
            15 60 7 \
            1 "Camera Bridge Service" \
            2 "SMB File Sharing" \
            3 "Web Server (nginx)" \
            4 "DHCP Server (dnsmasq)" \
            5 "Start All Services" \
            6 "Stop All Services" \
            7 "Back to Main Menu" \
            2>"$TEMP_DIR/service_choice"

        if [ $? -ne 0 ]; then
            submenu=false
            continue
        fi

        case $(cat "$TEMP_DIR/service_choice") in
            1) manage_service "camera-bridge" ;;
            2) manage_service "smbd" ;;
            3) manage_service "nginx" ;;
            4) manage_service "dnsmasq" ;;
            5) start_all_services ;;
            6) stop_all_services ;;
            7) submenu=false ;;
        esac
    done
}

# Manage individual service
manage_service() {
    local service=$1
    local status=$(systemctl is-active $service)

    dialog --title "Manage $service" \
        --menu "Status: $status\n\nSelect action:" \
        12 50 4 \
        1 "Start" \
        2 "Stop" \
        3 "Restart" \
        4 "View Status" \
        2>"$TEMP_DIR/action"

    if [ $? -eq 0 ]; then
        case $(cat "$TEMP_DIR/action") in
            1)
                sudo systemctl start $service
                dialog --msgbox "$service started" 6 40
                ;;
            2)
                sudo systemctl stop $service
                dialog --msgbox "$service stopped" 6 40
                ;;
            3)
                sudo systemctl restart $service
                dialog --msgbox "$service restarted" 6 40
                ;;
            4)
                systemctl status $service --no-pager > "$TEMP_DIR/service_status"
                dialog --title "$service Status" \
                    --textbox "$TEMP_DIR/service_status" 20 70
                ;;
        esac
    fi
}

# View Logs
view_logs() {
    dialog --title "View Logs" \
        --menu "Select log to view:" \
        12 50 4 \
        1 "Camera Bridge Service" \
        2 "SMB (Samba)" \
        3 "Web Server (nginx)" \
        4 "System Messages" \
        2>"$TEMP_DIR/log_choice"

    if [ $? -eq 0 ]; then
        case $(cat "$TEMP_DIR/log_choice") in
            1)
                sudo journalctl -u camera-bridge -n 100 --no-pager > "$TEMP_DIR/logs"
                ;;
            2)
                sudo tail -100 /var/log/samba/log.smbd > "$TEMP_DIR/logs" 2>/dev/null
                ;;
            3)
                sudo tail -100 /var/log/nginx/error.log > "$TEMP_DIR/logs" 2>/dev/null
                ;;
            4)
                sudo journalctl -n 100 --no-pager > "$TEMP_DIR/logs"
                ;;
        esac

        dialog --title "Log Viewer" --textbox "$TEMP_DIR/logs" 25 80
    fi
}

# Quick Setup Wizard
quick_setup_wizard() {
    dialog --title "Quick Setup Wizard" \
        --msgbox "This wizard will help you set up Camera Bridge.\n\nSteps:\n1. Configure WiFi\n2. Set up Dropbox\n3. Start services\n\nPress OK to continue." 12 60

    # Step 1: WiFi
    dialog --title "Step 1: WiFi" \
        --yesno "Do you need to configure WiFi?" 7 40

    if [ $? -eq 0 ]; then
        connect_to_wifi
    fi

    # Step 2: Dropbox
    dialog --title "Step 2: Dropbox" \
        --yesno "Do you need to configure Dropbox?" 7 40

    if [ $? -eq 0 ]; then
        configure_dropbox_token
    fi

    # Step 3: Start services
    dialog --title "Step 3: Services" \
        --yesno "Start all Camera Bridge services?" 7 40

    if [ $? -eq 0 ]; then
        start_all_services
    fi

    dialog --title "Setup Complete" \
        --msgbox "Camera Bridge setup is complete!\n\nYou can now:\n1. Connect devices via ethernet\n2. Access SMB share: \\\\192.168.10.1\\photos\n3. Photos will sync to Dropbox automatically" 12 60
}

# Start all services
start_all_services() {
    dialog --infobox "Starting services..." 3 30
    sudo systemctl start smbd
    sudo systemctl start nginx
    sudo systemctl start dnsmasq
    sudo systemctl start camera-bridge
    sleep 2
    dialog --msgbox "All services started" 6 40
}

# Stop all services
stop_all_services() {
    dialog --infobox "Stopping services..." 3 30
    sudo systemctl stop camera-bridge
    sudo systemctl stop dnsmasq
    sudo systemctl stop nginx
    sudo systemctl stop smbd
    sleep 2
    dialog --msgbox "All services stopped" 6 40
}

# File Management
file_management() {
    local share_path="/srv/samba/camera-share"
    local file_count=$(ls -1 $share_path 2>/dev/null | wc -l)
    local total_size=$(du -sh $share_path 2>/dev/null | cut -f1)

    dialog --title "File Management" \
        --menu "Share: $share_path\nFiles: $file_count | Size: $total_size\n\nSelect action:" \
        15 60 5 \
        1 "List Files" \
        2 "Delete All Files" \
        3 "Sync to Dropbox Now" \
        4 "View Recent Activity" \
        5 "Back" \
        2>"$TEMP_DIR/file_choice"

    case $(cat "$TEMP_DIR/file_choice" 2>/dev/null) in
        1)
            ls -lah $share_path > "$TEMP_DIR/file_list" 2>/dev/null
            dialog --title "Files in Share" --textbox "$TEMP_DIR/file_list" 20 70
            ;;
        2)
            dialog --title "Confirm Delete" \
                --yesno "Delete all files in the share?\n\nThis cannot be undone!" 8 50
            if [ $? -eq 0 ]; then
                sudo rm -rf $share_path/*
                dialog --msgbox "All files deleted" 6 40
            fi
            ;;
        3)
            manual_sync
            ;;
        4)
            sudo tail -50 /var/log/camera-bridge/monitor.log > "$TEMP_DIR/activity" 2>/dev/null
            dialog --title "Recent Activity" --textbox "$TEMP_DIR/activity" 20 70
            ;;
    esac
}

# Network Settings
network_settings() {
    local eth_ip="192.168.10.1"
    local dhcp_range="192.168.10.10-50"

    dialog --title "Network Settings" \
        --msgbox "ETHERNET CONFIGURATION:\n\nInterface: $ETH_INTERFACE\nIP Address: $eth_ip\nDHCP Range: $dhcp_range\n\nSMB SHARE:\n\\\\$eth_ip\\photos\n\nCredentials:\nUsername: camera\nPassword: camera123" 16 60
}

# System Information
system_information() {
    local info=""
    info+="SYSTEM:\n"
    info+="Hostname: $(hostname)\n"
    info+="Kernel: $(uname -r)\n"
    info+="Uptime: $(uptime -p)\n"
    info+="\nHARDWARE:\n"
    info+="CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)\n"
    info+="Memory: $(free -h | awk '/^Mem:/ {print $2}')\n"
    info+="\nDISK:\n"
    info+="$(df -h / | tail -1 | awk '{print "Used: "$3" / "$2" ("$5")"}')\n"

    dialog --title "System Information" --msgbox "$info" 18 70
}

# Maintenance Tools
maintenance_tools() {
    dialog --title "Maintenance Tools" \
        --menu "Select tool:" \
        12 60 4 \
        1 "Update System Packages" \
        2 "Clear Log Files" \
        3 "Restart All Services" \
        4 "Back" \
        2>"$TEMP_DIR/maint_choice"

    case $(cat "$TEMP_DIR/maint_choice" 2>/dev/null) in
        1)
            dialog --infobox "Updating packages..." 3 30
            sudo apt update && sudo apt upgrade -y 2>&1 | tail -10 > "$TEMP_DIR/update_result"
            dialog --title "Update Complete" --textbox "$TEMP_DIR/update_result" 15 70
            ;;
        2)
            sudo truncate -s 0 /var/log/camera-bridge/*.log 2>/dev/null
            dialog --msgbox "Log files cleared" 6 40
            ;;
        3)
            sudo systemctl restart smbd nginx dnsmasq camera-bridge
            dialog --msgbox "All services restarted" 6 40
            ;;
    esac
}

# Help
show_help() {
    dialog --title "Help & About" \
        --msgbox "Camera Bridge Terminal UI v2.0\n\n\
This interface helps you manage the Camera Bridge photo sync system.\n\n\
KEY FEATURES:\n\
• WiFi network configuration\n\
• Dropbox cloud storage setup\n\
• SMB file sharing management\n\
• Automatic photo syncing\n\n\
QUICK START:\n\
1. Configure WiFi (if needed)\n\
2. Set up Dropbox with your access token\n\
3. Connect devices via ethernet\n\
4. Photos sync automatically!\n\n\
SMB SHARE: \\\\192.168.10.1\\photos\n\
Username: camera | Password: camera123" 22 65
}

# Main execution
check_requirements
show_main_menu
cleanup