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
TEMP_DIR="/tmp/camera-bridge-ui-$$"
mkdir -p "$TEMP_DIR" 2>/dev/null || TEMP_DIR="/tmp"

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

        dialog --title "WiFi Management" --menu "$status_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 13 \
            1 "Show WiFi Status" \
            2 "Scan Networks" \
            3 "Connect to Network" \
            4 "Manual Connection" \
            5 "📱 Saved Networks" \
            6 "🔄 Auto-Connect" \
            7 "Start Setup Hotspot" \
            8 "Stop Setup Hotspot" \
            9 "Monitor Connection" \
            10 "Reset WiFi Settings" \
            11 "Advanced WiFi Tools" \
            12 "Network Settings" \
            13 "Back to Main Menu" 2>"$TEMP_DIR/wifi_choice"

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
            10) reset_wifi_settings ;;
            11) advanced_wifi_menu ;;
            12) network_settings_menu ;;
            13) return ;;
            *) ;;
        esac
    done
}

show_wifi_status() {
    dialog --title "Checking..." --infobox "Getting WiFi status..." 5 40

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    local status_info=""
    if [ -n "$wifi_script" ]; then
        # Get comprehensive WiFi status
        status_info=$(sudo "$wifi_script" status 2>/dev/null)

        # If basic status fails, get network info instead
        if [ $? -ne 0 ] || [ -z "$status_info" ]; then
            status_info=$(sudo "$wifi_script" info 2>/dev/null)
        fi

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
        dialog --title "Error" --msgbox "WiFi manager script not found\n\nExpected locations:\n• /opt/camera-bridge/scripts/wifi-manager.sh\n• $HOME/camera-bridge/scripts/wifi-manager.sh" 10 60
        return
    fi

    # Scan for networks with retry logic
    local networks=""
    local scan_attempts=0
    local max_attempts=2

    while [ $scan_attempts -lt $max_attempts ] && [ -z "$networks" ]; do
        scan_attempts=$((scan_attempts + 1))

        if [ $scan_attempts -gt 1 ]; then
            dialog --title "Retrying..." --infobox "Scan attempt $scan_attempts of $max_attempts..." 5 50
        fi

        networks=$(sudo "$wifi_script" scan 2>/dev/null | grep -v "^$" | head -20)

        if [ -z "$networks" ]; then
            sleep 2
        fi
    done

    if [ -z "$networks" ]; then
        dialog --title "No Networks Found" --msgbox "No WiFi networks detected.\n\nPossible causes:\n• WiFi adapter not available\n• No networks in range\n• Permission issues\n\nTry:\n• Check WiFi Status for hardware info\n• Move closer to access points\n• Use Manual Connection for hidden networks" 12 60
        return
    fi

    # Create enhanced menu with network details
    local menu_options=""
    local networks_array=()
    local i=1

    while IFS= read -r network; do
        if [ -n "$network" ] && [ "$network" != "Not connected" ]; then
            # Clean up network name and truncate if too long
            local clean_network=$(echo "$network" | sed 's/[^a-zA-Z0-9_-]//g' | cut -c1-30)
            if [ ${#network} -gt 30 ]; then
                clean_network="${clean_network}..."
            fi

            menu_options="$menu_options $i \"$network\""
            networks_array[$i]="$network"
            i=$((i+1))
        fi
    done <<< "$networks"

    if [ -z "$menu_options" ]; then
        dialog --title "No Valid Networks" --msgbox "No valid WiFi networks found in scan results." 8 50
        return
    fi

    # Show network selection with enhanced dialog
    eval "dialog --title 'Available Networks ($((i-1)) found)' --menu 'Select a network to connect:' $DIALOG_HEIGHT $DIALOG_WIDTH 10 $menu_options" 2>"$TEMP_DIR/network_choice"

    if [ $? -eq 0 ]; then
        choice=$(cat "$TEMP_DIR/network_choice")
        selected_network="${networks_array[$choice]}"

        if [ -n "$selected_network" ]; then
            # Ask for connection type
            dialog --title "Connection Type" --menu "How do you want to connect to:\n$selected_network" 12 60 3 \
                1 "WPA/WPA2 with password" \
                2 "Open network (no password)" \
                3 "Cancel" 2>"$TEMP_DIR/connect_type"

            if [ $? -eq 0 ]; then
                connect_type=$(cat "$TEMP_DIR/connect_type")
                case $connect_type in
                    1)
                        # Get password with confirmation
                        dialog --title "WiFi Password" --inputbox "Enter password for:\n$selected_network\n\n(Leave empty for no password)" 10 60 2>"$TEMP_DIR/wifi_password"

                        if [ $? -eq 0 ]; then
                            password=$(cat "$TEMP_DIR/wifi_password")

                            # Show connection progress
                            dialog --title "Connecting..." --infobox "Connecting to $selected_network...\n\nThis may take up to 30 seconds.\nPlease wait..." 7 60

                            # Attempt connection with timeout
                            if timeout 45 sudo "$wifi_script" connect "$selected_network" "$password" >/dev/null 2>&1; then
                                # Verify connection
                                sleep 3
                                if current_ssid=$(iwgetid -r 2>/dev/null) && [ "$current_ssid" = "$selected_network" ]; then
                                    local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
                                    local ip_addr=$(ip addr show "$wifi_iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
                                    dialog --title "Connection Successful" --msgbox "✓ Connected to: $selected_network\n\nIP Address: ${ip_addr:-Getting IP...}\n\nInternet connectivity will be available shortly." 10 60
                                else
                                    dialog --title "Connection Issues" --msgbox "Connection attempt completed but verification failed.\n\nNetwork: $selected_network\n\nTry:\n• Check WiFi Status\n• Verify password\n• Try Manual Connection" 12 60
                                fi
                            else
                                dialog --title "Connection Failed" --msgbox "Failed to connect to: $selected_network\n\nPossible causes:\n• Incorrect password\n• Network out of range\n• Authentication issues\n\nSuggestions:\n• Verify password is correct\n• Try moving closer to router\n• Check if network supports your device" 14 60
                            fi
                        fi
                        ;;
                    2)
                        # Open network
                        dialog --title "Connecting..." --infobox "Connecting to open network:\n$selected_network..." 6 50

                        if timeout 30 sudo "$wifi_script" connect "$selected_network" "" >/dev/null 2>&1; then
                            dialog --title "Success" --msgbox "Connected to open network:\n$selected_network" 8 50
                        else
                            dialog --title "Failed" --msgbox "Failed to connect to open network:\n$selected_network" 8 50
                        fi
                        ;;
                    3)
                        return
                        ;;
                esac
            fi
        fi
    fi

    # Cleanup temporary files
    rm -f "$TEMP_DIR/wifi_password" "$TEMP_DIR/network_choice" "$TEMP_DIR/connect_type"
}

manual_connect() {
    # Network type selection
    dialog --title "Manual WiFi Connection" --menu "Select connection type:" 12 60 4 \
        1 "Standard WPA/WPA2 Network" \
        2 "Open Network (No Password)" \
        3 "Hidden Network (WPA/WPA2)" \
        4 "Cancel" 2>"$TEMP_DIR/manual_type"

    if [ $? -ne 0 ]; then
        return
    fi

    manual_type=$(cat "$TEMP_DIR/manual_type")
    case $manual_type in
        4)
            return
            ;;
        *)
            ;;
    esac

    # Get SSID
    local ssid_prompt="Enter network SSID (name):"
    if [ "$manual_type" = "3" ]; then
        ssid_prompt="Enter hidden network SSID (exact name):"
    fi

    dialog --title "Network SSID" --inputbox "$ssid_prompt" 10 60 2>"$TEMP_DIR/manual_ssid"

    if [ $? -ne 0 ] || [ ! -s "$TEMP_DIR/manual_ssid" ]; then
        rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_type"
        return
    fi

    ssid=$(cat "$TEMP_DIR/manual_ssid")

    # Validate SSID
    if [ -z "$ssid" ] || [ ${#ssid} -gt 32 ]; then
        dialog --title "Invalid SSID" --msgbox "SSID cannot be empty or longer than 32 characters.\n\nEntered: '$ssid'" 8 60
        rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_type"
        return
    fi

    # Get password if needed
    local password=""
    if [ "$manual_type" != "2" ]; then
        dialog --title "Network Password" --inputbox "Enter password for '$ssid':\n\n(Leave empty if no password)" 10 60 2>"$TEMP_DIR/manual_password"

        if [ $? -ne 0 ]; then
            rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_type"
            return
        fi

        password=$(cat "$TEMP_DIR/manual_password")

        # Validate password length for WPA
        if [ -n "$password" ] && [ ${#password} -lt 8 ]; then
            dialog --title "Invalid Password" --msgbox "WPA/WPA2 passwords must be at least 8 characters long.\n\nCurrent length: ${#password} characters" 8 60
            rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_password" "$TEMP_DIR/manual_type"
            return
        fi
    fi

    # Show connection summary
    local connection_summary="Connection Details:
• SSID: $ssid
• Type: $(case $manual_type in 1) Standard WPA/WPA2;; 2) Open Network;; 3) Hidden WPA/WPA2;; esac)
• Password: $([ -n "$password" ] && echo "Provided" || echo "None")

Proceed with connection?"

    if ! dialog --title "Confirm Connection" --yesno "$connection_summary" 12 60; then
        rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_password" "$TEMP_DIR/manual_type"
        return
    fi

    # Find WiFi manager script
    local wifi_script=""
    if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
    elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
        wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
    fi

    if [ -z "$wifi_script" ]; then
        dialog --title "Error" --msgbox "WiFi manager script not found\n\nExpected locations:\n• /opt/camera-bridge/scripts/wifi-manager.sh\n• $HOME/camera-bridge/scripts/wifi-manager.sh" 10 60
        rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_password" "$TEMP_DIR/manual_type"
        return
    fi

    # Show connection progress
    dialog --title "Connecting..." --infobox "Connecting to '$ssid'...\n\nThis may take up to 45 seconds.\nPlease wait..." 7 60

    # Attempt connection with extended timeout for manual connections
    local connection_result=0
    if timeout 60 sudo "$wifi_script" connect "$ssid" "$password" >/dev/null 2>&1; then
        # Extended verification for manual connections
        sleep 5

        local verification_attempts=0
        local max_verification_attempts=6
        local connected=false

        while [ $verification_attempts -lt $max_verification_attempts ] && [ "$connected" = "false" ]; do
            if current_ssid=$(iwgetid -r 2>/dev/null) && [ "$current_ssid" = "$ssid" ]; then
                connected=true
                break
            fi
            sleep 2
            verification_attempts=$((verification_attempts + 1))
        done

        if [ "$connected" = "true" ]; then
            local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
            local ip_addr=$(ip addr show "$wifi_iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
            local signal_level=$(iwconfig "$wifi_iface" 2>/dev/null | grep "Signal level" | sed 's/.*Signal level=\([^ ]*\).*/\1/' | head -1)

            dialog --title "Connection Successful" --msgbox "✓ Successfully connected to: $ssid\n\nConnection Details:\n• IP Address: ${ip_addr:-Obtaining...}\n• Signal Strength: ${signal_level:-Unknown}\n• Type: $(case $manual_type in 1) Standard WPA/WPA2;; 2) Open Network;; 3) Hidden WPA/WPA2;; esac)\n\nInternet connectivity should be available." 14 70
        else
            dialog --title "Connection Issues" --msgbox "Connection attempt completed but verification failed.\n\nNetwork: $ssid\n\nThis might indicate:\n• Weak signal strength\n• Network authentication issues\n• DHCP assignment delays\n\nTry:\n• Check WiFi Status in a few moments\n• Verify network credentials\n• Move closer to the access point" 16 70
        fi
    else
        case "$manual_type" in
            1|3)
                dialog --title "Connection Failed" --msgbox "Failed to connect to: $ssid\n\nPossible causes:\n• Incorrect password\n• Network not in range\n• Authentication method not supported\n• Network capacity full\n\nSuggestions:\n• Verify SSID spelling is exact\n• Check password (case-sensitive)\n• Try moving closer to router\n• Contact network administrator" 16 70
                ;;
            2)
                dialog --title "Connection Failed" --msgbox "Failed to connect to open network: $ssid\n\nPossible causes:\n• Network not in range\n• Network requires web authentication\n• Network blocks new devices\n• SSID misspelled\n\nSuggestions:\n• Verify SSID spelling\n• Check if captive portal exists\n• Try scanning for the network first" 14 70
                ;;
        esac
    fi

    # Cleanup temporary files
    rm -f "$TEMP_DIR/manual_ssid" "$TEMP_DIR/manual_password" "$TEMP_DIR/manual_type"
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

reset_wifi_settings() {
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

# Saved Networks Management Menu
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
        formatted_output="$networks_output\n\n⚠️ Could not scan for available networks"
    fi

    # Show in scrollable format
    dialog --title "Saved Networks" --msgbox "$formatted_output\n\n✓ = Password saved | ○ = Open network\n🔄 = Auto-connect enabled | ⏸️ = Auto-connect disabled\n⚡ = Currently available | ⭕ = Not in range\n\nPress OK to return to menu" 20 80
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
            # Extract SSID (remove number, status icons, and priority info)
            local ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
            local status_icon=$(echo "$line" | sed 's/^[0-9]\+\. \([✓○]\) .*/\1/')
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

    local selected_index=$(cat "$TEMP_DIR/network_choice")

    # Get the SSID for the selected network
    local selected_ssid=""
    local current_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^[0-9]\+\."; then
            current_count=$((current_count + 1))
            if [ $current_count -eq $selected_index ]; then
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
            local ssid=$(echo "$line" | sed 's/^[0-9]\+\. [✓○] \([^(]*\) (.*/\1/' | xargs)
            local status_icon=$(echo "$line" | sed 's/^[0-9]\+\. \([✓○]\) .*/\1/')
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

    local selected_index=$(cat "$TEMP_DIR/remove_choice")

    # Check if cancel was selected
    if [ $selected_index -eq $((network_count + 1)) ]; then
        rm -f "$TEMP_DIR/remove_choice"
        return
    fi

    # Get the SSID for the selected network
    local selected_ssid=""
    local current_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^[0-9]\+\."; then
            current_count=$((current_count + 1))
            if [ $current_count -eq $selected_index ]; then
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
    dialog --title "Auto-Connect" --infobox "Checking auto-connect status..." 5 40

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

    dialog --title "Auto-Connect" --menu "Choose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 6 \
        1 "🔄 Try Auto-Connect Now" \
        2 "📋 View Auto-Connect Status" \
        3 "⚙️ Auto-Connect Settings" \
        4 "📊 Connection Priority" \
        5 "Back to Saved Networks" 2>"$TEMP_DIR/auto_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/auto_choice")
    case $choice in
        1)
            dialog --title "Auto-Connecting..." --infobox "Attempting to auto-connect to saved networks...\n\nScanning for available networks..." 7 60

            if sudo "$wifi_script" auto-connect >/dev/null 2>&1; then
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
            local status_info=$(sudo "$wifi_script" list-saved 2>/dev/null)
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

    rm -f "$TEMP_DIR/auto_choice"
}

# Network details and settings (placeholder for future expansion)
show_network_details() {
    dialog --title "Network Details" --msgbox "Network details feature coming soon!\n\nThis will show:\n• Signal strength for saved networks\n• Last connection time\n• Connection history\n• Security information\n• Auto-connect settings per network" 12 60
}

# Auto-connect settings (placeholder for future expansion)
auto_connect_settings() {
    dialog --title "Auto-Connect Settings" --msgbox "Auto-connect settings coming soon!\n\nThis will allow:\n• Enable/disable auto-connect globally\n• Set connection retry attempts\n• Configure connection timeouts\n• Manage network priority\n• Set preferred connection order" 12 60
}

# Network settings menu (placeholder for future expansion)
network_settings_menu() {
    dialog --title "Network Settings" --msgbox "Advanced network settings coming soon!\n\nThis will include:\n• WiFi power management\n• Connection profiles\n• Advanced security settings\n• Network diagnostics\n• Interface configuration" 12 60
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
    # Check if already configured
    local config_status="Not Configured"
    local token_type=""

    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        config_status="Configured"
        if grep -q "refresh_token" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
            token_type=" (OAuth2 with auto-refresh)"
        else
            token_type=" (Legacy token - may expire)"
        fi
    fi

    # Show current status and menu
    dialog --title "Dropbox Configuration" --menu "Status: ${config_status}${token_type}\n\nChoose configuration method:" 16 70 5 \
        1 "OAuth2 Setup (Auto-Refresh Token)" \
        2 "Legacy Token (Manual Entry)" \
        3 "Reconfigure Existing Setup" \
        4 "Test Current Configuration" \
        5 "Cancel" 2>"$TEMP_DIR/config_method"

    if [ $? -ne 0 ]; then
        return
    fi

    config_method=$(cat "$TEMP_DIR/config_method")

    case $config_method in
        1)
            # OAuth2 Setup
            configure_dropbox_oauth2
            ;;
        2)
            # Legacy token entry
            configure_dropbox_manual
            ;;
        3)
            # Reconfigure
            if dialog --title "Reconfigure Warning" --yesno "This will replace your existing Dropbox configuration.\n\nAll current settings will be lost.\n\nContinue?" 10 60; then
                sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
                configure_dropbox_oauth2
            fi
            ;;
        4)
            # Test configuration
            dialog --title "Testing..." --infobox "Testing Dropbox connection...\nPlease wait..." 5 45
            if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
                dialog --title "Test Result" --msgbox "✓ Connection successful!\n\nDropbox is working properly." 8 50
            else
                dialog --title "Test Result" --msgbox "✗ Connection failed!\n\nPlease reconfigure Dropbox." 8 50
            fi
            ;;
        5)
            return
            ;;
    esac
}

# OAuth2 Configuration Function
configure_dropbox_oauth2() {
    clear
    dialog --title "OAuth2 Setup - Automatic Token Refresh" --msgbox "DROPBOX OAUTH2 SETUP\n\nThis method provides:\n✓ Automatic token refresh\n✓ Never expires\n✓ Works with Dropbox Business\n✓ One-time setup\n\nYou'll need access to a computer with a web browser.\n\nPress OK to see instructions." 15 65

    # Instructions
    dialog --title "Step 1: Get OAuth2 Token" --msgbox "ON A COMPUTER WITH WEB BROWSER:\n\n1. Open terminal/command prompt\n\n2. Run this command:\n   rclone authorize dropbox\n\n3. Browser will open automatically\n\n4. Log in to Dropbox (personal or business)\n\n5. Click 'Allow' to authorize\n\n6. Copy the ENTIRE token that appears\n   (everything from { to })\n\nThe token looks like:\n{\"access_token\":\"...\",\"refresh_token\":\"...\",\"expiry\":\"...\"}\n\nPress OK when ready to paste." 20 72

    # Get token
    local token_file="$TEMP_DIR/oauth_token"
    dialog --title "Step 2: Enter OAuth2 Token" --inputbox "Paste the complete OAuth2 token here:\n\nIMPORTANT: Include EVERYTHING from { to }" 12 75 2>"$token_file"

    if [ ! -s "$token_file" ]; then
        dialog --title "Cancelled" --msgbox "No token provided. Setup cancelled." 7 45
        return 1
    fi

    local token=$(cat "$token_file")

    # Validate token format
    if [[ "$token" != *"{"* ]] || [[ "$token" != *"}"* ]]; then
        dialog --title "Invalid Format" --msgbox "ERROR: Token must include the curly braces {}!\n\nMake sure to copy the ENTIRE output from rclone authorize." 9 65
        return 1
    fi

    if [[ "$token" != *"access_token"* ]]; then
        dialog --title "Invalid Token" --msgbox "ERROR: This doesn't look like a valid OAuth2 token.\n\nMake sure you used: rclone authorize dropbox" 8 60
        return 1
    fi

    # Check for refresh token
    local has_refresh=0
    if [[ "$token" == *"refresh_token"* ]]; then
        has_refresh=1
        dialog --title "✓ Token Valid" --infobox "✓ OAuth2 token detected\n✓ Refresh token found\n✓ Auto-renewal will work!\n\nConfiguring..." 8 50
        sleep 2
    else
        dialog --title "⚠ Warning" --msgbox "Token is missing refresh_token!\n\nThis token will expire and need manual renewal.\n\nFor best results, use: rclone authorize dropbox" 10 65
    fi

    # Setup configuration
    dialog --title "Configuring..." --infobox "Installing Dropbox configuration...\nPlease wait..." 5 45

    # Ensure user exists
    if ! id "camerabridge" >/dev/null 2>&1; then
        sudo useradd -r -s /bin/false -d /home/camerabridge camerabridge 2>/dev/null || true
    fi

    # Create config directory
    sudo mkdir -p /home/camerabridge/.config/rclone

    # Write config
    cat > "$TEMP_DIR/rclone.conf" << EOFCONF
[dropbox]
type = dropbox
token = $token
EOFCONF

    # Install config
    sudo cp "$TEMP_DIR/rclone.conf" /home/camerabridge/.config/rclone/rclone.conf
    sudo chown -R camerabridge:camerabridge /home/camerabridge/.config
    sudo chmod 700 /home/camerabridge/.config/rclone
    sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    # Test connection
    dialog --title "Testing..." --infobox "Testing Dropbox connection...\nThis may take up to 30 seconds..." 5 50

    if timeout 45 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Success
        local account_info=$(sudo -u camerabridge rclone about dropbox: 2>/dev/null | grep -E "(Used:|Free:|Total:)" | head -3)

        if [ $has_refresh -eq 1 ]; then
            dialog --title "✓ SUCCESS - OAuth2 Configured!" --msgbox "DROPBOX OAUTH2 SETUP COMPLETE!\n\n$account_info\n\n✓ OAuth2 token installed\n✓ Refresh token active\n✓ Automatic renewal enabled\n✓ Will never expire!\n\nPhotos will sync to:\ndropbox:Camera-Photos/" 17 65
        else
            dialog --title "✓ Configured" --msgbox "DROPBOX CONFIGURED\n\n$account_info\n\n⚠ Legacy token (no refresh)\n⚠ May expire eventually\n\nPhotos will sync to:\ndropbox:Camera-Photos/" 15 65
        fi

        # Create destination folder
        sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null || true

        # Restart service if running
        if systemctl is-active --quiet camera-bridge; then
            dialog --title "Service" --infobox "Restarting Camera Bridge service..." 5 45
            sudo systemctl restart camera-bridge
            sleep 2
        fi

        rm -f "$token_file"
        return 0
    else
        dialog --title "Connection Failed" --msgbox "Failed to connect to Dropbox!\n\nPossible issues:\n• Invalid token\n• Network problems\n• Firewall blocking\n\nTry getting a fresh token with:\nrclone authorize dropbox" 12 60

        # Offer to keep config
        if dialog --title "Keep Config?" --yesno "Keep configuration for retry later?" 7 45; then
            dialog --title "Saved" --msgbox "Configuration saved.\nTry testing from the Dropbox menu." 7 50
        else
            sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
        fi

        rm -f "$token_file"
        return 1
    fi
}

configure_dropbox_manual() {

# ============= OAuth2 FUNCTIONS START =============
# Added for OAuth2 support with refresh tokens

configure_dropbox_oauth2() {
    clear
    dialog --title "Dropbox OAuth2 Setup" --msgbox "DROPBOX OAUTH2 WITH AUTOMATIC RENEWAL\n\nThis sets up Dropbox with refresh tokens.\nTokens will automatically renew - no more expiration!\n\nYou need:\n1. A computer with web browser\n2. Your Dropbox/Business account\n\nPress OK to see instructions." 14 68

    # Show how to get token
    dialog --title "Get OAuth2 Token - Instructions" --msgbox "ON A COMPUTER WITH WEB BROWSER:\n\n1. Open terminal/command prompt\n\n2. Run: rclone authorize dropbox\n\n3. Browser opens → Log in to Dropbox\n\n4. Click 'Allow' to authorize\n\n5. Copy ENTIRE token that appears\n   (everything from { to })\n\nExample token format:\n{\"access_token\":\"...\",\"refresh_token\":\"...\",\"expiry\":\"...\"}\n\nPress OK when you have the token." 20 75

    # Get token input
    local token_file="$TEMP_DIR/oauth_token"
    dialog --title "Enter OAuth2 Token" --inputbox "Paste the COMPLETE token here (including {} brackets):" 10 75 2>"$token_file"

    if [ ! -s "$token_file" ]; then
        dialog --title "Cancelled" --msgbox "No token provided." 7 40
        return 1
    fi

    local token=$(cat "$token_file")

    # Validate token
    if [[ "$token" != *"{"* ]] || [[ "$token" != *"}"* ]]; then
        dialog --title "Invalid Format" --msgbox "Token must include {} brackets!\n\nMake sure to copy EVERYTHING." 8 55
        return 1
    fi

    if [[ "$token" != *"access_token"* ]]; then
        dialog --title "Invalid Token" --msgbox "This doesn't appear to be a valid OAuth2 token.\n\nUse: rclone authorize dropbox" 8 55
        return 1
    fi

    # Check for refresh token
    local has_refresh=0
    if [[ "$token" == *"refresh_token"* ]]; then
        has_refresh=1
        dialog --title "✓ Valid Token" --infobox "✓ OAuth2 token detected\n✓ Refresh token found\n✓ Auto-renewal enabled!\n\nConfiguring..." 8 45
        sleep 2
    else
        dialog --title "⚠ Warning" --msgbox "Token missing refresh_token!\n\nWill expire and need manual renewal.\n\nFor auto-refresh use: rclone authorize dropbox" 9 60
    fi

    # Configure
    dialog --title "Configuring..." --infobox "Setting up Dropbox...\nPlease wait..." 5 40

    # Ensure camerabridge user exists
    if ! id "camerabridge" >/dev/null 2>&1; then
        sudo useradd -r -s /bin/false -d /home/camerabridge camerabridge 2>/dev/null || true
    fi

    # Create config
    sudo mkdir -p /home/camerabridge/.config/rclone
    cat > "$TEMP_DIR/rclone.conf" << EOFCONF
[dropbox]
type = dropbox
token = $token
EOFCONF

    # Install config
    sudo cp "$TEMP_DIR/rclone.conf" /home/camerabridge/.config/rclone/rclone.conf
    sudo chown -R camerabridge:camerabridge /home/camerabridge/.config
    sudo chmod 700 /home/camerabridge/.config/rclone
    sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    # Test connection
    dialog --title "Testing..." --infobox "Testing Dropbox connection...\nPlease wait up to 30 seconds..." 5 50

    if timeout 45 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Success!
        local info=$(sudo -u camerabridge rclone about dropbox: 2>/dev/null | grep -E "(Used:|Free:|Total:)" | head -3)

        if [ $has_refresh -eq 1 ]; then
            dialog --title "✓ SUCCESS!" --msgbox "DROPBOX OAUTH2 CONFIGURED!\n\n$info\n\n✓ OAuth2 with refresh token\n✓ Automatic token renewal\n✓ Never expires!\n\nPhotos sync to: dropbox:Camera-Photos/" 16 65
        else
            dialog --title "✓ Configured" --msgbox "DROPBOX CONFIGURED\n\n$info\n\n⚠ No refresh token - may expire\n\nPhotos sync to: dropbox:Camera-Photos/" 14 65
        fi

        # Create photos folder
        sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null || true

        # Restart service
        if systemctl is-active --quiet camera-bridge; then
            sudo systemctl restart camera-bridge
        fi
        return 0
    else
        dialog --title "Failed" --msgbox "Could not connect to Dropbox!\n\nCheck:\n• Token is valid\n• Internet connection\n• Try fresh token" 10 55
        return 1
    fi
}

# Override the original configure_dropbox function
configure_dropbox_original() {
    # This saves the original function
    configure_dropbox_manual
}

# New configure_dropbox with OAuth2 option
configure_dropbox() {
    local choice=""

    # Check current config
    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        if grep -q "refresh_token" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
            dialog --title "Status" --msgbox "✓ Dropbox configured with OAuth2\n✓ Auto-refresh enabled\n\nSelect 'Reconfigure' to change." 9 50
        else
            dialog --title "Status" --msgbox "⚠ Dropbox configured with legacy token\n⚠ May expire\n\nConsider OAuth2 reconfiguration." 9 50
        fi
    fi

    dialog --title "Dropbox Configuration" --menu "Choose method:" 14 65 4 \
        1 "OAuth2 Setup (Recommended)" \
        2 "Legacy Token (Old Method)" \
        3 "Reconfigure" \
        4 "Back" 2>"$TEMP_DIR/dropbox_choice"

    choice=$(cat "$TEMP_DIR/dropbox_choice" 2>/dev/null)

    case $choice in
        1)
            configure_dropbox_oauth2
            ;;
        2)
            configure_dropbox_original
            ;;
        3)
            if dialog --title "Reconfigure?" --yesno "Replace existing configuration?" 7 45; then
                sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
                configure_dropbox_oauth2
            fi
            ;;
        *)
            return
            ;;
    esac
}

# ============= OAuth2 FUNCTIONS END =============


# ============= OAuth2 FUNCTIONS START =============
# Added for OAuth2 support with refresh tokens

configure_dropbox_oauth2() {
    clear
    dialog --title "Dropbox OAuth2 Setup" --msgbox "DROPBOX OAUTH2 WITH AUTOMATIC RENEWAL\n\nThis sets up Dropbox with refresh tokens.\nTokens will automatically renew - no more expiration!\n\nYou need:\n1. A computer with web browser\n2. Your Dropbox/Business account\n\nPress OK to see instructions." 14 68

    # Show how to get token
    dialog --title "Get OAuth2 Token - Instructions" --msgbox "ON A COMPUTER WITH WEB BROWSER:\n\n1. Open terminal/command prompt\n\n2. Run: rclone authorize dropbox\n\n3. Browser opens → Log in to Dropbox\n\n4. Click 'Allow' to authorize\n\n5. Copy ENTIRE token that appears\n   (everything from { to })\n\nExample token format:\n{\"access_token\":\"...\",\"refresh_token\":\"...\",\"expiry\":\"...\"}\n\nPress OK when you have the token." 20 75

    # Get token input
    local token_file="$TEMP_DIR/oauth_token"
    dialog --title "Enter OAuth2 Token" --inputbox "Paste the COMPLETE token here (including {} brackets):" 10 75 2>"$token_file"

    if [ ! -s "$token_file" ]; then
        dialog --title "Cancelled" --msgbox "No token provided." 7 40
        return 1
    fi

    local token=$(cat "$token_file")

    # Validate token
    if [[ "$token" != *"{"* ]] || [[ "$token" != *"}"* ]]; then
        dialog --title "Invalid Format" --msgbox "Token must include {} brackets!\n\nMake sure to copy EVERYTHING." 8 55
        return 1
    fi

    if [[ "$token" != *"access_token"* ]]; then
        dialog --title "Invalid Token" --msgbox "This doesn't appear to be a valid OAuth2 token.\n\nUse: rclone authorize dropbox" 8 55
        return 1
    fi

    # Check for refresh token
    local has_refresh=0
    if [[ "$token" == *"refresh_token"* ]]; then
        has_refresh=1
        dialog --title "✓ Valid Token" --infobox "✓ OAuth2 token detected\n✓ Refresh token found\n✓ Auto-renewal enabled!\n\nConfiguring..." 8 45
        sleep 2
    else
        dialog --title "⚠ Warning" --msgbox "Token missing refresh_token!\n\nWill expire and need manual renewal.\n\nFor auto-refresh use: rclone authorize dropbox" 9 60
    fi

    # Configure
    dialog --title "Configuring..." --infobox "Setting up Dropbox...\nPlease wait..." 5 40

    # Ensure camerabridge user exists
    if ! id "camerabridge" >/dev/null 2>&1; then
        sudo useradd -r -s /bin/false -d /home/camerabridge camerabridge 2>/dev/null || true
    fi

    # Create config
    sudo mkdir -p /home/camerabridge/.config/rclone
    cat > "$TEMP_DIR/rclone.conf" << EOFCONF
[dropbox]
type = dropbox
token = $token
EOFCONF

    # Install config
    sudo cp "$TEMP_DIR/rclone.conf" /home/camerabridge/.config/rclone/rclone.conf
    sudo chown -R camerabridge:camerabridge /home/camerabridge/.config
    sudo chmod 700 /home/camerabridge/.config/rclone
    sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    # Test connection
    dialog --title "Testing..." --infobox "Testing Dropbox connection...\nPlease wait up to 30 seconds..." 5 50

    if timeout 45 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Success!
        local info=$(sudo -u camerabridge rclone about dropbox: 2>/dev/null | grep -E "(Used:|Free:|Total:)" | head -3)

        if [ $has_refresh -eq 1 ]; then
            dialog --title "✓ SUCCESS!" --msgbox "DROPBOX OAUTH2 CONFIGURED!\n\n$info\n\n✓ OAuth2 with refresh token\n✓ Automatic token renewal\n✓ Never expires!\n\nPhotos sync to: dropbox:Camera-Photos/" 16 65
        else
            dialog --title "✓ Configured" --msgbox "DROPBOX CONFIGURED\n\n$info\n\n⚠ No refresh token - may expire\n\nPhotos sync to: dropbox:Camera-Photos/" 14 65
        fi

        # Create photos folder
        sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null || true

        # Restart service
        if systemctl is-active --quiet camera-bridge; then
            sudo systemctl restart camera-bridge
        fi
        return 0
    else
        dialog --title "Failed" --msgbox "Could not connect to Dropbox!\n\nCheck:\n• Token is valid\n• Internet connection\n• Try fresh token" 10 55
        return 1
    fi
}

# Override the original configure_dropbox function
configure_dropbox_original() {
    # This saves the original function
    configure_dropbox_manual
}

# New configure_dropbox with OAuth2 option
configure_dropbox() {
    local choice=""

    # Check current config
    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        if grep -q "refresh_token" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
            dialog --title "Status" --msgbox "✓ Dropbox configured with OAuth2\n✓ Auto-refresh enabled\n\nSelect 'Reconfigure' to change." 9 50
        else
            dialog --title "Status" --msgbox "⚠ Dropbox configured with legacy token\n⚠ May expire\n\nConsider OAuth2 reconfiguration." 9 50
        fi
    fi

    dialog --title "Dropbox Configuration" --menu "Choose method:" 14 65 4 \
        1 "OAuth2 Setup (Recommended)" \
        2 "Legacy Token (Old Method)" \
        3 "Reconfigure" \
        4 "Back" 2>"$TEMP_DIR/dropbox_choice"

    choice=$(cat "$TEMP_DIR/dropbox_choice" 2>/dev/null)

    case $choice in
        1)
            configure_dropbox_oauth2
            ;;
        2)
            configure_dropbox_original
            ;;
        3)
            if dialog --title "Reconfigure?" --yesno "Replace existing configuration?" 7 45; then
                sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
                configure_dropbox_oauth2
            fi
            ;;
        *)
            return
            ;;
    esac
}

# ============= OAuth2 FUNCTIONS END =============

    # Token input with validation
    local token=""
    local attempt=0
    local max_attempts=3

    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))

        if [ $attempt -gt 1 ]; then
            dialog --title "Token Input (Attempt $attempt/$max_attempts)" --inputbox "Previous token was invalid.\n\nPlease enter your Dropbox access token:\n\n• Should start with 'sl.' for scoped tokens\n• Must be 84+ characters long\n• No spaces or line breaks" 12 70 2>"$TEMP_DIR/dropbox_token"
        else
            dialog --title "Dropbox Access Token" --inputbox "Enter your Dropbox access token:\n\n• Starts with 'sl.' for new scoped tokens\n• Should be 84+ characters long\n• Copy exactly as shown in Dropbox app console\n• No spaces or line breaks\n\nToken:" 12 70 2>"$TEMP_DIR/dropbox_token"
        fi

        if [ $? -ne 0 ]; then
            rm -f "$TEMP_DIR/dropbox_token"
            return
        fi

        token=$(cat "$TEMP_DIR/dropbox_token" | tr -d ' \t\n\r')

        # Validate token format
        if [ -z "$token" ]; then
            dialog --title "Empty Token" --msgbox "Token cannot be empty.\n\nPlease try again." 8 40
            continue
        fi

        if [ ${#token} -lt 40 ]; then
            dialog --title "Token Too Short" --msgbox "Token appears too short (${#token} characters).\n\nDropbox tokens should be at least 40 characters.\n\nPlease verify you copied the complete token." 10 60
            continue
        fi

        if echo "$token" | grep -q '[[:space:]]'; then
            dialog --title "Invalid Characters" --msgbox "Token contains spaces or newlines.\n\nPlease ensure you copy only the token string." 8 50
            continue
        fi

        # Token seems valid, break out of loop
        break
    done

    if [ $attempt -ge $max_attempts ]; then
        dialog --title "Setup Failed" --msgbox "Maximum attempts reached.\n\nPlease check your token and try again later." 8 50
        rm -f "$TEMP_DIR/dropbox_token"
        return
    fi

    # Configure with the token
    configure_dropbox_with_token "$token"
    rm -f "$TEMP_DIR/dropbox_token"
}

configure_dropbox_qr() {
    # Check if qrencode is available
    if ! command -v qrencode >/dev/null 2>&1; then
        dialog --title "Installing QR Code Support..." --infobox "Installing qrencode package...\nThis may take a moment." 6 50

        if ! sudo apt update >/dev/null 2>&1 || ! sudo apt install -y qrencode >/dev/null 2>&1; then
            dialog --title "Installation Failed" --msgbox "Failed to install QR code support.\n\nPlease install manually:\nsudo apt install qrencode\n\nFalling back to manual token entry." 10 60
            configure_dropbox_manual
            return
        fi
    fi

    # Get system IP address
    local system_ip=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)

    if [ -z "$system_ip" ]; then
        dialog --title "Network Error" --msgbox "Could not determine system IP address.\n\nEnsure you're connected to WiFi or use manual token entry." 10 60
        configure_dropbox_manual
        return
    fi

    # Check if nginx is running and start if needed
    if ! systemctl is-active --quiet nginx; then
        dialog --title "Starting Web Server..." --infobox "Starting web server for QR code entry..." 5 50
        sudo systemctl start nginx 2>/dev/null || true
        sleep 2
    fi

    # Create QR code URL
    local qr_url="http://${system_ip}/token-entry.php?qr=1"

    # Generate QR code
    local qr_code=""
    if qr_code=$(qrencode -t ANSIUTF8 "$qr_url" 2>/dev/null); then
        # Show QR code with instructions
        local qr_message="📱 DROPBOX TOKEN ENTRY VIA QR CODE

IMPORTANT: Your phone/device must be connected to the same WiFi network!

$qr_code

Or visit manually: $qr_url

Instructions:
1. Get your Dropbox token ready (from developers.dropbox.com)
2. Scan QR code above with your phone camera
3. Paste the token in the web form
4. Press Save Token
5. Return here and press OK to continue

Press OK when you've submitted the token..."

        dialog --title "QR Code Token Entry" --msgbox "$qr_message" 30 90
    else
        # Fallback if QR generation fails
        dialog --title "QR Code Generation Failed" --msgbox "Could not generate QR code.\n\nVisit this URL instead:\n$qr_url\n\nOr use manual token entry." 12 70
        configure_dropbox_manual
        return
    fi

    # Wait for token file and process it
    dialog --title "Waiting for Token..." --infobox "Waiting for token submission via web interface...\n\nPress Ctrl+C to cancel and use manual entry." 7 60

    local token_file="/tmp/camera-bridge-token-entry.txt"
    local status_file="/tmp/camera-bridge-token-status.txt"
    local wait_count=0
    local max_wait=120  # 2 minutes

    # Clean up any old files
    sudo rm -f "$token_file" "$status_file" 2>/dev/null

    while [ $wait_count -lt $max_wait ]; do
        if [ -f "$status_file" ] && [ "$(cat "$status_file" 2>/dev/null)" = "success" ]; then
            # Token was submitted successfully
            if [ -f "$token_file" ]; then
                local submitted_token=$(cat "$token_file" | tr -d ' \t\n\r')

                if [ -n "$submitted_token" ] && [ ${#submitted_token} -ge 40 ]; then
                    dialog --title "Token Received" --msgbox "✅ Token received successfully via QR code!\n\nLength: ${#submitted_token} characters\n\nProcessing configuration..." 10 60

                    # Configure with the submitted token
                    configure_dropbox_with_token "$submitted_token"

                    # Cleanup
                    sudo rm -f "$token_file" "$status_file" 2>/dev/null
                    return
                else
                    dialog --title "Invalid Token" --msgbox "Received token appears invalid.\n\nLength: ${#submitted_token} characters\n\nTrying manual entry instead." 10 60
                    sudo rm -f "$token_file" "$status_file" 2>/dev/null
                    configure_dropbox_manual
                    return
                fi
            fi
        fi

        sleep 1
        wait_count=$((wait_count + 1))
    done

    # Timeout - offer manual entry
    dialog --title "Timeout" --msgbox "No token was submitted within 2 minutes.\n\nWould you like to try manual entry instead?" 10 60
    configure_dropbox_manual

    # Cleanup
    sudo rm -f "$token_file" "$status_file" 2>/dev/null
}

configure_dropbox_with_token() {
    local token="$1"

    # Show progress
    dialog --title "Configuring..." --infobox "Setting up Dropbox configuration...\nThis may take a moment." 6 50

    # Create user and directories if needed
    if ! id "camerabridge" >/dev/null 2>&1; then
        dialog --title "Creating User..." --infobox "Creating camerabridge user..." 5 40
        sudo useradd -r -s /bin/false -d /home/camerabridge camerabridge 2>/dev/null || true
    fi

    # Create rclone config directory
    sudo mkdir -p /home/camerabridge/.config/rclone 2>/dev/null

    # Create rclone configuration
    cat > "$TEMP_DIR/rclone.conf" << EOF
[dropbox]
type = dropbox
token = {"access_token":"$token","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
EOF

    # Install configuration
    sudo cp "$TEMP_DIR/rclone.conf" /home/camerabridge/.config/rclone/rclone.conf
    sudo chown -R camerabridge:camerabridge /home/camerabridge/.config 2>/dev/null || true
    sudo chmod 700 /home/camerabridge/.config/rclone
    sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    # Test connection
    dialog --title "Testing Connection..." --infobox "Testing Dropbox connection...\nThis may take 10-30 seconds." 6 50

    if timeout 45 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Get account info for confirmation
        local account_info=""
        if account_info=$(timeout 30 sudo -u camerabridge rclone about dropbox: 2>/dev/null | head -3); then
            dialog --title "Configuration Successful" --msgbox "✓ Dropbox configured successfully!\n\nConnection Details:\n$account_info\n\nThe Camera Bridge will now automatically sync photos to:\ndropbox:Camera-Photos/\n\nYou can test sync using 'Manual Sync Now'." 16 70
        else
            dialog --title "Configuration Successful" --msgbox "✓ Dropbox configured successfully!\n\n• Connection verified\n• Authentication working\n• Ready for photo sync\n\nPhotos will sync to: dropbox:Camera-Photos/\n\nYou can test sync using 'Manual Sync Now'." 14 60
        fi
    else
        dialog --title "Configuration Failed" --msgbox "✗ Failed to connect to Dropbox.\n\nPossible issues:\n• Invalid or expired token\n• Network connectivity problems\n• Dropbox API rate limiting\n• Token permissions insufficient\n\nSuggestions:\n• Verify token is copied correctly\n• Check internet connection\n• Ensure app has proper permissions\n• Try again in a few minutes" 16 70

        # Offer to keep config for retry
        if dialog --title "Keep Configuration?" --yesno "Do you want to keep the configuration for retry later?\n\nChoose 'Yes' to keep settings\nChoose 'No' to remove configuration" 10 60; then
            dialog --title "Configuration Saved" --msgbox "Configuration saved for later testing.\n\nUse 'Test Dropbox Connection' to verify later." 8 50
        else
            sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
            dialog --title "Configuration Removed" --msgbox "Dropbox configuration has been removed." 8 40
        fi
    fi

    # Cleanup
    rm -f "$TEMP_DIR/rclone.conf"
}

test_dropbox() {
    dialog --title "Testing Connection..." --infobox "Testing Dropbox connection...\nThis may take up to 30 seconds." 6 50

    # Check if rclone is installed
    if ! command -v rclone >/dev/null 2>&1; then
        dialog --title "Test Failed" --msgbox "✗ rclone is not installed\n\nPlease install rclone first:\nsudo apt install rclone" 10 50
        return
    fi

    # Check if config exists
    if [ ! -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        dialog --title "Test Failed" --msgbox "✗ No Dropbox configuration found\n\nPlease configure Dropbox first using:\n'Configure Dropbox Token'" 10 50
        return
    fi

    # Test basic connectivity
    local test_output=""
    local connection_result=0

    if test_output=$(timeout 45 sudo -u camerabridge rclone lsd dropbox: 2>&1); then
        # Connection successful, get detailed info
        local account_info=""
        local space_info=""
        local test_folder=""

        # Get account information
        if account_info=$(timeout 30 sudo -u camerabridge rclone about dropbox: 2>/dev/null); then
            space_info=$(echo "$account_info" | grep -E "(Total|Used|Free)" | head -3)
        fi

        # Test write permissions by creating a test folder
        local test_result="Write permissions: "
        if timeout 30 sudo -u camerabridge rclone mkdir dropbox:Camera-Photos-Test 2>/dev/null && \
           timeout 30 sudo -u camerabridge rclone rmdir dropbox:Camera-Photos-Test 2>/dev/null; then
            test_result="${test_result}OK ✓"
        else
            test_result="${test_result}Limited ⚠"
        fi

        # Show success dialog with details
        local success_msg="✓ Dropbox Connection: SUCCESSFUL\n\n"
        if [ -n "$space_info" ]; then
            success_msg="${success_msg}Storage Information:\n$space_info\n\n"
        fi
        success_msg="${success_msg}$test_result\n\nYour Camera Bridge can now sync photos to Dropbox!"

        dialog --title "Connection Test Results" --msgbox "$success_msg" 16 70
    else
        # Connection failed, provide detailed diagnosis
        local error_msg="✗ Dropbox Connection: FAILED\n\n"

        # Analyze the error
        if echo "$test_output" | grep -qi "unauthorized\|invalid.*token\|token.*expired"; then
            error_msg="${error_msg}Issue: Authentication Failed\n• Token may be invalid or expired\n• App permissions may be insufficient\n\nSolution:\n• Regenerate token in Dropbox app console\n• Ensure all required permissions are enabled\n• Reconfigure using 'Configure Dropbox Token'"
        elif echo "$test_output" | grep -qi "network\|connection\|timeout"; then
            error_msg="${error_msg}Issue: Network Connectivity\n• Cannot reach Dropbox servers\n• Internet connection may be down\n\nSolution:\n• Check internet connection\n• Try again in a few minutes\n• Check firewall settings"
        elif echo "$test_output" | grep -qi "rate.*limit\|too.*many.*requests"; then
            error_msg="${error_msg}Issue: Rate Limiting\n• Too many requests to Dropbox API\n\nSolution:\n• Wait 10-15 minutes and try again\n• Dropbox API has request limits"
        else
            error_msg="${error_msg}Issue: Unknown Error\n\nError details:\n$(echo "$test_output" | head -3)\n\nSolution:\n• Check configuration\n• Try reconfiguring Dropbox token\n• Verify internet connection"
        fi

        dialog --title "Connection Test Results" --msgbox "$error_msg" 18 70
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

view_sync_logs() {
    dialog --title "Sync Log Viewer" --menu "Select log to view:" 15 60 6 \
        1 "Recent Sync Activity (last 50 lines)" \
        2 "Camera Bridge Service Log" \
        3 "Today's Sync Events" \
        4 "Error Logs Only" \
        5 "Full Sync History" \
        6 "Back to Dropbox Menu" 2>"$TEMP_DIR/log_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/log_choice")
    case $choice in
        1)
            # Recent sync activity
            local recent_logs=""
            if [ -f "/var/log/camera-bridge/service.log" ]; then
                recent_logs=$(tail -50 /var/log/camera-bridge/service.log | grep -E "(sync|dropbox|rclone)" -i || echo "No recent sync activity found")
            else
                recent_logs="Service log file not found at /var/log/camera-bridge/service.log"
            fi
            echo "$recent_logs" > "$TEMP_DIR/recent_sync.log"
            dialog --title "Recent Sync Activity" --textbox "$TEMP_DIR/recent_sync.log" 20 90
            ;;
        2)
            # Full service log
            if [ -f "/var/log/camera-bridge/service.log" ]; then
                dialog --title "Camera Bridge Service Log" --textbox /var/log/camera-bridge/service.log 22 90
            else
                dialog --title "Log Not Found" --msgbox "Service log not found at:\n/var/log/camera-bridge/service.log\n\nThe service may not be running or logging is not configured." 10 60
            fi
            ;;
        3)
            # Today's events
            local today_logs=""
            local today_date=$(date '+%Y-%m-%d')
            if [ -f "/var/log/camera-bridge/service.log" ]; then
                today_logs=$(grep "$today_date" /var/log/camera-bridge/service.log | grep -E "(sync|dropbox)" -i || echo "No sync events found for today ($today_date)")
            else
                today_logs="Service log file not found"
            fi
            echo "$today_logs" > "$TEMP_DIR/today_sync.log"
            dialog --title "Today's Sync Events ($today_date)" --textbox "$TEMP_DIR/today_sync.log" 20 90
            ;;
        4)
            # Error logs only
            local error_logs=""
            if [ -f "/var/log/camera-bridge/service.log" ]; then
                error_logs=$(grep -E "(ERROR|FAILED|failed|error)" /var/log/camera-bridge/service.log | tail -50 || echo "No errors found in recent logs")
            else
                error_logs="Service log file not found"
            fi
            echo "$error_logs" > "$TEMP_DIR/error_sync.log"
            dialog --title "Error Logs" --textbox "$TEMP_DIR/error_sync.log" 20 90
            ;;
        5)
            # Full history (systemd journal)
            journalctl -u camera-bridge --no-pager > "$TEMP_DIR/full_history.log" 2>/dev/null || echo "Unable to retrieve systemd journal logs" > "$TEMP_DIR/full_history.log"
            dialog --title "Full Sync History (systemd journal)" --textbox "$TEMP_DIR/full_history.log" 22 90
            ;;
        6)
            return
            ;;
    esac

    # Cleanup and return to log menu
    rm -f "$TEMP_DIR/recent_sync.log" "$TEMP_DIR/today_sync.log" "$TEMP_DIR/error_sync.log" "$TEMP_DIR/full_history.log"
    view_sync_logs
}

dropbox_settings() {
    while true; do
        # Get current settings info
        local config_status="Not configured"
        local config_path="/home/camerabridge/.config/rclone/rclone.conf"
        local sync_folder="Camera-Photos"

        if [ -f "$config_path" ]; then
            config_status="Configured"
        fi

        dialog --title "Dropbox Settings" --menu "Current Status: $config_status\nSync Folder: dropbox:$sync_folder\n\nChoose an option:" 15 70 8 \
            1 "View Current Configuration" \
            2 "Change Sync Folder Name" \
            3 "Reset Configuration" \
            4 "Export Configuration Backup" \
            5 "Import Configuration Backup" \
            6 "Advanced rclone Settings" \
            7 "Remove Dropbox Setup" \
            8 "Back to Dropbox Menu" 2>"$TEMP_DIR/settings_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/settings_choice")
        case $choice in
            1)
                # View current config
                if [ -f "$config_path" ]; then
                    local config_info="CURRENT DROPBOX CONFIGURATION\n===============================\n\n"
                    config_info="${config_info}Config File: $config_path\n"
                    config_info="${config_info}User: camerabridge\n"
                    config_info="${config_info}Permissions: $(ls -la $config_path 2>/dev/null | awk '{print $1}' || echo 'Unknown')\n\n"

                    if sudo -u camerabridge rclone config show dropbox 2>/dev/null | grep -q "type = dropbox"; then
                        config_info="${config_info}Status: Valid configuration found\n"
                        config_info="${config_info}Type: Dropbox\n\n"

                        # Test connection status
                        if timeout 15 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
                            config_info="${config_info}Connection: ✓ Active\n"
                        else
                            config_info="${config_info}Connection: ✗ Failed\n"
                        fi
                    else
                        config_info="${config_info}Status: Configuration file exists but invalid format\n"
                    fi

                    dialog --title "Configuration Details" --msgbox "$config_info" 18 70
                else
                    dialog --title "No Configuration" --msgbox "No Dropbox configuration found.\n\nUse 'Configure Dropbox Token' to set up Dropbox sync." 8 50
                fi
                ;;
            2)
                # Change sync folder
                dialog --title "Change Sync Folder" --inputbox "Enter new folder name for Dropbox sync:\n\nCurrent: Camera-Photos\nNew folder will be: dropbox:[your-input]\n\nFolder name:" 12 60 "Camera-Photos" 2>"$TEMP_DIR/new_folder"

                if [ $? -eq 0 ]; then
                    new_folder=$(cat "$TEMP_DIR/new_folder" | tr -d '/' | tr ' ' '-')
                    if [ -n "$new_folder" ]; then
                        dialog --title "Folder Change" --msgbox "Note: This setting is not yet implemented.\n\nFor now, photos sync to: dropbox:Camera-Photos\n\nTo change the folder, you would need to modify the camera bridge service configuration." 12 60
                    fi
                fi
                rm -f "$TEMP_DIR/new_folder"
                ;;
            3)
                # Reset configuration
                if dialog --title "Reset Configuration" --yesno "This will completely remove your Dropbox configuration.\n\nYou will need to:\n• Get a new access token\n• Reconfigure from scratch\n\nAre you sure?" 12 60; then
                    sudo rm -f "$config_path" 2>/dev/null
                    dialog --title "Configuration Reset" --msgbox "Dropbox configuration has been reset.\n\nUse 'Configure Dropbox Token' to set up again." 8 50
                fi
                ;;
            4)
                # Export backup
                if [ -f "$config_path" ]; then
                    local backup_file="/tmp/dropbox-config-backup-$(date +%Y%m%d_%H%M%S).conf"
                    if sudo cp "$config_path" "$backup_file" 2>/dev/null && sudo chmod 644 "$backup_file"; then
                        dialog --title "Backup Created" --msgbox "Configuration backed up to:\n$backup_file\n\nYou can copy this file to restore the configuration later." 10 60
                    else
                        dialog --title "Backup Failed" --msgbox "Failed to create backup.\n\nCheck permissions and disk space." 8 50
                    fi
                else
                    dialog --title "No Configuration" --msgbox "No configuration to backup.\n\nConfigure Dropbox first." 8 40
                fi
                ;;
            5)
                # Import backup
                dialog --title "Import Backup" --inputbox "Enter full path to backup file:" 10 60 "/tmp/" 2>"$TEMP_DIR/backup_path"
                if [ $? -eq 0 ]; then
                    backup_path=$(cat "$TEMP_DIR/backup_path")
                    if [ -f "$backup_path" ]; then
                        if dialog --title "Confirm Import" --yesno "This will replace your current configuration.\n\nImport from: $backup_path\n\nContinue?" 10 60; then
                            sudo cp "$backup_path" "$config_path" 2>/dev/null && \
                            sudo chown camerabridge:camerabridge "$config_path" 2>/dev/null && \
                            sudo chmod 600 "$config_path"
                            dialog --title "Import Complete" --msgbox "Configuration imported successfully.\n\nUse 'Test Dropbox Connection' to verify." 8 50
                        fi
                    else
                        dialog --title "File Not Found" --msgbox "Backup file not found:\n$backup_path" 8 50
                    fi
                fi
                rm -f "$TEMP_DIR/backup_path"
                ;;
            6)
                # Advanced settings
                dialog --title "Advanced Settings" --msgbox "ADVANCED RCLONE SETTINGS\n\nFor advanced configuration, you can:\n\n1. Edit config directly:\n   sudo nano /home/camerabridge/.config/rclone/rclone.conf\n\n2. Use rclone config:\n   sudo -u camerabridge rclone config\n\n3. View all options:\n   rclone config help dropbox\n\nWarning: Advanced changes may break sync functionality." 16 80
                ;;
            7)
                # Remove setup
                if dialog --title "Remove Dropbox Setup" --yesno "This will:\n• Remove all Dropbox configuration\n• Stop automatic syncing\n• Keep existing photos in Dropbox\n\nRemove Dropbox setup?" 12 60; then
                    sudo rm -rf /home/camerabridge/.config/rclone 2>/dev/null
                    dialog --title "Dropbox Removed" --msgbox "Dropbox setup has been completely removed.\n\nAutomatic syncing is now disabled.\nExisting photos in Dropbox are unaffected." 10 60
                    return
                fi
                ;;
            8)
                return
                ;;
        esac
    done
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

    # SMB/Share information
    local smb_info=""
    if [ "$smb_status" = "Running" ]; then
        smb_info="• SMB Share: //$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)/photos
• SMB User: camera
• SMB Password: camera123
• Share Path: /srv/samba/camera-share"
    else
        smb_info="• SMB Server: Not running"
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

SMB File Sharing:
$smb_info

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

manage_smb_service() {
    local smb_status="Unknown"
    if systemctl is-active --quiet smbd 2>/dev/null; then
        smb_status="Running"
    else
        smb_status="Stopped"
    fi

    local nmb_status="Unknown"
    if systemctl is-active --quiet nmbd 2>/dev/null; then
        nmb_status="Running"
    else
        nmb_status="Stopped"
    fi

    dialog --title "SMB/Samba Service ($smb_status)" --menu "SMB Status: $smb_status | NetBIOS: $nmb_status\n\nChoose action:" $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
        1 "Start SMB Services" \
        2 "Stop SMB Services" \
        3 "Restart SMB Services" \
        4 "View SMB Status" \
        5 "Show SMB Connection Info" \
        6 "View SMB Logs" \
        7 "Test SMB Share" \
        8 "Reset SMB Password" \
        9 "Back" 2>"$TEMP_DIR/smb_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    choice=$(cat "$TEMP_DIR/smb_choice")
    case $choice in
        1)
            dialog --title "Starting Services..." --infobox "Starting SMB/Samba services..." 5 40
            sudo systemctl start smbd nmbd 2>/dev/null
            sleep 2
            if systemctl is-active --quiet smbd && systemctl is-active --quiet nmbd; then
                dialog --title "Success" --msgbox "SMB services started successfully." 8 40
            else
                dialog --title "Warning" --msgbox "SMB services may not have started correctly.\nCheck service status for details." 8 50
            fi
            ;;
        2)
            dialog --title "Stopping Services..." --infobox "Stopping SMB/Samba services..." 5 40
            sudo systemctl stop smbd nmbd 2>/dev/null
            sleep 2
            dialog --title "Services Stopped" --msgbox "SMB services have been stopped." 8 40
            ;;
        3)
            dialog --title "Restarting Services..." --infobox "Restarting SMB/Samba services..." 5 40
            sudo systemctl restart smbd nmbd 2>/dev/null
            sleep 3
            dialog --title "Services Restarted" --msgbox "SMB services have been restarted." 8 40
            ;;
        4)
            local detailed_status="SMB SERVICE STATUS\n==================\n\n"
            detailed_status="${detailed_status}SMB Daemon (smbd):\n$(systemctl status smbd --no-pager -l 2>/dev/null | head -8)\n\n"
            detailed_status="${detailed_status}NetBIOS Daemon (nmbd):\n$(systemctl status nmbd --no-pager -l 2>/dev/null | head -8)"
            dialog --title "SMB Service Status" --msgbox "$detailed_status" 20 90
            ;;
        5)
            local server_ip=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)
            local connection_info="SMB CONNECTION INFORMATION\n==========================\n\n"
            connection_info="${connection_info}Server IP: $server_ip\n"
            connection_info="${connection_info}Share Name: photos\n"
            connection_info="${connection_info}Share Path: \\\\\\\\$server_ip\\\\photos\n\n"
            connection_info="${connection_info}Authentication:\n"
            connection_info="${connection_info}• Username: camera\n"
            connection_info="${connection_info}• Password: camera123\n\n"
            connection_info="${connection_info}Connection Examples:\n"
            connection_info="${connection_info}• Windows: \\\\\\\\$server_ip\\\\photos\n"
            connection_info="${connection_info}• macOS: smb://$server_ip/photos\n"
            connection_info="${connection_info}• Linux: smb://$server_ip/photos"
            dialog --title "SMB Connection Info" --msgbox "$connection_info" 18 70
            ;;
        6)
            if [ -f "/var/log/samba/log.smbd" ]; then
                dialog --title "SMB Logs" --textbox /var/log/samba/log.smbd 22 90
            else
                dialog --title "No Logs" --msgbox "SMB log file not found at /var/log/samba/log.smbd" 8 50
            fi
            ;;
        7)
            dialog --title "Testing..." --infobox "Testing SMB share accessibility..." 5 50
            if smbclient -L localhost -U camera%camera123 >/dev/null 2>&1; then
                dialog --title "Test Success" --msgbox "✓ SMB share is accessible\n\nThe 'photos' share can be accessed with:\n• Username: camera\n• Password: camera123" 10 50
            else
                dialog --title "Test Failed" --msgbox "✗ SMB share test failed\n\nPossible issues:\n• SMB services not running\n• Authentication problems\n• Network configuration issues" 10 60
            fi
            ;;
        8)
            dialog --title "Reset SMB Password" --inputbox "Enter new password for SMB user 'camera':" 10 50 2>"$TEMP_DIR/new_smb_password"
            if [ $? -eq 0 ]; then
                new_password=$(cat "$TEMP_DIR/new_smb_password")
                if [ -n "$new_password" ]; then
                    if echo -e "$new_password\\n$new_password" | sudo smbpasswd -a -s camera 2>/dev/null; then
                        dialog --title "Password Updated" --msgbox "SMB password for user 'camera' has been updated successfully." 8 50
                    else
                        dialog --title "Update Failed" --msgbox "Failed to update SMB password.\nCheck system logs for details." 8 50
                    fi
                fi
            fi
            rm -f "$TEMP_DIR/new_smb_password"
            ;;
        9)
            return
            ;;
    esac

    manage_smb_service
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
# File Management Configuration
PHOTO_DIR="/srv/samba/camera-share"
USB_MOUNT_BASE="/media"
TEMP_SELECTION_FILE="/tmp/camera-bridge-selected-files"
MAX_FILES_PER_PAGE=100

file_management() {
    while true; do
        # Get quick stats
        local file_count=0
        local total_size="0B"
        if [ -d "$PHOTO_DIR" ]; then
            file_count=$(find "$PHOTO_DIR" -type f 2>/dev/null | wc -l)
            total_size=$(du -sh "$PHOTO_DIR" 2>/dev/null | cut -f1 || echo "0B")
        fi

        local status_text="Storage: $file_count files ($total_size)"

        dialog --title "File Management" --menu "$status_text\n\nChoose an option:" $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
            1 "📁 Terminal File Browser" \
            2 "🖼️  GUI File Browser" \
            3 "💾 Quick USB Copy" \
            4 "🔍 File Statistics" \
            5 "🗑️  File Cleanup" \
            6 "📂 Open in Shell" \
            7 "💿 USB Management" \
            8 "Back to Main Menu" 2>"$TEMP_DIR/file_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/file_choice")
        case $choice in
            1) terminal_file_browser ;;
            2) gui_file_browser ;;
            3) quick_usb_copy ;;
            4) file_statistics ;;
            5) file_cleanup ;;
            6) open_in_shell ;;
            7) usb_management ;;
            8) return ;;
            *) ;;
        esac
    done
}

# USB Detection and Mounting Functions
detect_usb_devices() {
    local usb_devices=""
    local device_count=0

    # Find all removable block devices
    for device in /sys/block/sd*; do
        if [ -f "$device/removable" ] && [ "$(cat "$device/removable")" = "1" ]; then
            local dev_name=$(basename "$device")
            local dev_path="/dev/$dev_name"

            # Get device info
            local model=$(cat "$device/device/model" 2>/dev/null | xargs || echo "USB Drive")
            local size=$(lsblk -no SIZE "$dev_path" 2>/dev/null | head -1 || echo "Unknown")

            # Check for partitions
            for part in "$device"/"$dev_name"*; do
                if [ -d "$part" ] && [[ "$(basename "$part")" != "$dev_name" ]]; then
                    local part_name=$(basename "$part")
                    local part_path="/dev/$part_name"
                    local mount_point=$(lsblk -no MOUNTPOINT "$part_path" 2>/dev/null)
                    local fs_type=$(lsblk -no FSTYPE "$part_path" 2>/dev/null)

                    if [ -z "$mount_point" ]; then
                        mount_point="<not mounted>"
                    fi

                    # Get free space if mounted
                    local free_space="N/A"
                    if [ "$mount_point" != "<not mounted>" ] && [ -d "$mount_point" ]; then
                        free_space=$(df -h "$mount_point" 2>/dev/null | awk 'NR==2{print $4}')
                    fi

                    device_count=$((device_count + 1))
                    usb_devices="${usb_devices}${device_count}|$part_path|$model|$size|$mount_point|$free_space|$fs_type\n"
                fi
            done
        fi
    done

    if [ -z "$usb_devices" ]; then
        echo "NONE"
    else
        echo -e "$usb_devices"
    fi
}

auto_mount_usb() {
    local device="$1"
    local device_name=$(basename "$device")

    # Check if already mounted
    local existing_mount=$(lsblk -no MOUNTPOINT "$device" 2>/dev/null)
    if [ -n "$existing_mount" ]; then
        echo "$existing_mount"
        return 0
    fi

    # Create mount point
    local mount_point="$USB_MOUNT_BASE/usb_${device_name}"
    sudo mkdir -p "$mount_point" 2>/dev/null

    # Try to mount
    if sudo mount "$device" "$mount_point" 2>/dev/null; then
        echo "$mount_point"
        return 0
    else
        sudo rmdir "$mount_point" 2>/dev/null
        return 1
    fi
}

# Terminal File Browser with Date Filtering
terminal_file_browser() {
    if [ ! -d "$PHOTO_DIR" ]; then
        dialog --title "Error" --msgbox "Photo directory not found:\n$PHOTO_DIR" 8 60
        return
    fi

    # Step 1: Date filter selection
    dialog --title "Date Filter" --menu "How do you want to filter files?" 18 60 10 \
        1 "All Files" \
        2 "Today" \
        3 "Yesterday" \
        4 "Last 7 Days" \
        5 "Last 30 Days" \
        6 "This Month" \
        7 "Last Month" \
        8 "Custom Date Range" \
        9 "Cancel" 2>"$TEMP_DIR/date_filter_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    local date_choice=$(cat "$TEMP_DIR/date_filter_choice")
    if [ "$date_choice" = "9" ]; then
        return
    fi

    # Build find command based on date filter
    local find_cmd="find \"$PHOTO_DIR\" -type f"
    local date_desc=""

    case $date_choice in
        1)
            date_desc="All Files"
            ;;
        2)
            find_cmd="$find_cmd -mtime 0"
            date_desc="Today"
            ;;
        3)
            find_cmd="$find_cmd -mtime 1"
            date_desc="Yesterday"
            ;;
        4)
            find_cmd="$find_cmd -mtime -7"
            date_desc="Last 7 Days"
            ;;
        5)
            find_cmd="$find_cmd -mtime -30"
            date_desc="Last 30 Days"
            ;;
        6)
            local month_start=$(date +%Y-%m-01)
            find_cmd="$find_cmd -newermt \"$month_start\""
            date_desc="This Month"
            ;;
        7)
            local last_month_start=$(date -d "last month" +%Y-%m-01)
            local this_month_start=$(date +%Y-%m-01)
            find_cmd="$find_cmd -newermt \"$last_month_start\" ! -newermt \"$this_month_start\""
            date_desc="Last Month"
            ;;
        8)
            # Custom date range - use calendar
            dialog --title "Custom Date Range" --msgbox "Custom date range picker coming soon!\n\nFor now, using Last 30 Days." 8 50
            find_cmd="$find_cmd -mtime -30"
            date_desc="Last 30 Days"
            ;;
    esac

    # Execute find and get files
    dialog --title "Scanning..." --infobox "Scanning for files...\n\nFilter: $date_desc\n\nPlease wait..." 7 50

    local files=$(eval "$find_cmd 2>/dev/null | sort -r")
    local file_count=$(echo "$files" | grep -c '^' 2>/dev/null || echo "0")

    if [ -z "$files" ] || [ "$file_count" -eq 0 ]; then
        dialog --title "No Files Found" --msgbox "No files match the selected date filter:\n\n$date_desc" 8 50
        return
    fi

    # Step 2: File selection with multi-select
    show_file_selector "$files" "$date_desc" "$file_count"
}

show_file_selector() {
    local files="$1"
    local date_desc="$2"
    local file_count="$3"

    # Store files in array for easier access
    echo "$files" > "$TEMP_DIR/files_array"

    # Build checklist options
    rm -f "$TEMP_DIR/file_list_options"
    local index=1

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            local filename=$(basename "$file")
            local filesize=$(du -h "$file" 2>/dev/null | cut -f1)
            local filedate=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)

            if [ $index -le $MAX_FILES_PER_PAGE ]; then
                echo "$index \"$filename\" \"$filesize $filedate\" off" >> "$TEMP_DIR/file_list_options"
            fi
            index=$((index + 1))
        fi
    done < "$TEMP_DIR/files_array"

    if [ $file_count -gt $MAX_FILES_PER_PAGE ]; then
        local showing_text="Showing first $MAX_FILES_PER_PAGE of $file_count files"
    else
        local showing_text="$file_count files found"
    fi

    if [ ! -s "$TEMP_DIR/file_list_options" ]; then
        dialog --title "Error" --msgbox "No valid files found to display." 6 50
        return
    fi

    # Show checklist for file selection
    eval "dialog --title \"Select Files ($date_desc)\" --checklist \"$showing_text\nUse SPACE to select, ENTER to confirm\" 20 78 12 $(cat "$TEMP_DIR/file_list_options") 2>\"$TEMP_DIR/selected_files\""

    local dialog_result=$?

    if [ $dialog_result -ne 0 ]; then
        return
    fi

    # Get selected file indices
    local selected_indices=$(cat "$TEMP_DIR/selected_files" 2>/dev/null | tr -d '"')

    if [ -z "$selected_indices" ]; then
        dialog --title "No Selection" --msgbox "No files were selected." 6 40
        return
    fi

    # Build list of selected files
    rm -f "$TEMP_SELECTION_FILE"
    for idx in $selected_indices; do
        sed -n "${idx}p" "$TEMP_DIR/files_array" >> "$TEMP_SELECTION_FILE"
    done

    local selected_count=$(wc -l < "$TEMP_SELECTION_FILE" 2>/dev/null || echo "0")

    if [ "$selected_count" -eq 0 ]; then
        dialog --title "Error" --msgbox "Failed to process selected files." 6 50
        return
    fi

    local selected_size=$(du -ch $(cat "$TEMP_SELECTION_FILE") 2>/dev/null | tail -1 | cut -f1 || echo "unknown")

    # Step 3: Choose action for selected files
    dialog --title "File Actions" --menu "Selected: $selected_count files ($selected_size)\n\nWhat would you like to do?" 12 60 4 \
        1 "Copy to USB" \
        2 "View File List" \
        3 "Delete Selected" \
        4 "Cancel" 2>"$TEMP_DIR/file_action"

    if [ $? -ne 0 ]; then
        return
    fi

    local action=$(cat "$TEMP_DIR/file_action" 2>/dev/null)

    case $action in
        1) copy_selected_to_usb "$selected_count" "$selected_size" ;;
        2) view_selected_files ;;
        3) delete_selected_files "$selected_count" ;;
        4) return ;;
    esac
}

copy_selected_to_usb() {
    local file_count="$1"
    local total_size="$2"

    # Detect USB devices
    dialog --title "USB Detection" --infobox "Detecting USB devices...\n\nPlease wait..." 6 50
    sleep 1

    local usb_list=$(detect_usb_devices)

    if [ "$usb_list" = "NONE" ]; then
        dialog --title "No USB Devices" --msgbox "No USB devices detected.\n\nPlease:\n• Insert a USB drive\n• Wait a few seconds\n• Try again" 10 50
        return
    fi

    # Build USB selection menu
    local usb_menu_options=""
    local usb_count=0

    echo -e "$usb_list" | while IFS='|' read -r index device model size mount free fs; do
        if [ -n "$device" ]; then
            usb_count=$((usb_count + 1))
            local status="Not mounted"
            if [ "$mount" != "<not mounted>" ]; then
                status="Mounted: $mount (Free: $free)"
            fi
            echo "$index \"$model ($size)\" \"$status\""
        fi
    done > "$TEMP_DIR/usb_menu_options"

    eval "dialog --title \"Select USB Device\" --menu \"Copy $file_count files ($total_size) to USB\n\nChoose destination:\" 15 70 8 $(cat "$TEMP_DIR/usb_menu_options") 2>\"$TEMP_DIR/usb_choice\""

    if [ $? -ne 0 ]; then
        return
    fi

    local usb_index=$(cat "$TEMP_DIR/usb_choice")

    # Get selected USB device details
    local usb_info=$(echo -e "$usb_list" | grep "^$usb_index|")
    local usb_device=$(echo "$usb_info" | cut -d'|' -f2)
    local usb_mount=$(echo "$usb_info" | cut -d'|' -f5)

    # Mount if needed
    if [ "$usb_mount" = "<not mounted>" ]; then
        dialog --title "Mounting USB" --infobox "Mounting USB device...\n\n$usb_device" 6 50
        usb_mount=$(auto_mount_usb "$usb_device")
        if [ $? -ne 0 ]; then
            dialog --title "Mount Failed" --msgbox "Failed to mount USB device:\n$usb_device\n\nPlease check:\n• USB is not write-protected\n• Filesystem is supported\n• Device is not damaged" 12 60
            return
        fi
    fi

    # Verify mount and space
    if [ ! -d "$usb_mount" ]; then
        dialog --title "Error" --msgbox "USB mount point not accessible:\n$usb_mount" 8 60
        return
    fi

    # Copy files with progress
    copy_files_with_progress "$usb_mount" "$file_count" "$total_size"
}

copy_files_with_progress() {
    local destination="$1"
    local file_count="$2"
    local total_size="$3"

    # Create destination directory
    local dest_dir="$destination/CameraBridge-$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$dest_dir" 2>/dev/null

    if [ ! -d "$dest_dir" ]; then
        dialog --title "Error" --msgbox "Failed to create destination directory:\n$dest_dir" 8 60
        return
    fi

    # Show progress during copy
    (
        local copied=0
        local total=$(wc -l < "$TEMP_SELECTION_FILE")

        while IFS= read -r file; do
            if [ -f "$file" ]; then
                # Calculate progress percentage
                local percent=$((copied * 100 / total))
                echo "XXX"
                echo "$percent"
                echo "Copying: $(basename "$file")\n\nFile $((copied + 1)) of $total"
                echo "XXX"

                # Copy file
                sudo cp "$file" "$dest_dir/" 2>/dev/null

                copied=$((copied + 1))
            fi
        done < "$TEMP_SELECTION_FILE"

        echo "XXX"
        echo "100"
        echo "Copy complete!\n\nVerifying files..."
        echo "XXX"
        sleep 2

    ) | dialog --title "Copying to USB" --gauge "Preparing to copy $file_count files..." 10 70 0

    # Verify copy
    local copied_count=$(find "$dest_dir" -type f 2>/dev/null | wc -l)

    if [ "$copied_count" -eq "$file_count" ]; then
        dialog --title "Copy Successful" --msgbox "✓ Successfully copied $file_count files!\n\nDestination:\n$dest_dir\n\nYou can safely remove the USB drive after clicking OK." 12 70
    else
        dialog --title "Copy Incomplete" --msgbox "⚠️ Copy completed with issues.\n\nExpected: $file_count files\nCopied: $copied_count files\n\nSome files may not have been copied.\nPlease check the destination directory." 12 70
    fi

    # Cleanup
    rm -f "$TEMP_SELECTION_FILE"
}

view_selected_files() {
    if [ ! -f "$TEMP_SELECTION_FILE" ]; then
        dialog --title "Error" --msgbox "No files selected" 6 40
        return
    fi

    local file_list=$(cat "$TEMP_SELECTION_FILE" | sed 's|.*/||' | nl -w2 -s'. ')
    local file_count=$(wc -l < "$TEMP_SELECTION_FILE")

    dialog --title "Selected Files ($file_count)" --msgbox "$file_list" 20 70
}

delete_selected_files() {
    local file_count="$1"

    if ! dialog --title "Confirm Deletion" --yesno "⚠️  WARNING: Delete $file_count files?\n\nThis action CANNOT be undone!\n\nFiles will be permanently deleted from:\n$PHOTO_DIR\n\nAre you absolutely sure?" 12 60; then
        return
    fi

    # Double confirmation
    if ! dialog --title "Final Confirmation" --yesno "Last chance to cancel!\n\nDelete $file_count files permanently?" 8 50; then
        return
    fi

    # Delete files with progress
    (
        local deleted=0
        local total=$(wc -l < "$TEMP_SELECTION_FILE")

        while IFS= read -r file; do
            if [ -f "$file" ]; then
                local percent=$((deleted * 100 / total))
                echo "XXX"
                echo "$percent"
                echo "Deleting: $(basename "$file")"
                echo "XXX"

                sudo rm -f "$file" 2>/dev/null
                deleted=$((deleted + 1))
            fi
        done < "$TEMP_SELECTION_FILE"

        echo "100"
    ) | dialog --title "Deleting Files" --gauge "Deleting $file_count files..." 8 70 0

    dialog --title "Deletion Complete" --msgbox "✓ Deleted $file_count files from storage." 6 50

    rm -f "$TEMP_SELECTION_FILE"
}

# GUI File Browser
gui_file_browser() {
    # Check if GUI is available
    if [ -z "$DISPLAY" ]; then
        dialog --title "GUI Not Available" --yesno "GUI file browser requires X11.\n\nOptions:\n• Install Thunar file manager (~25MB)\n• Use terminal file browser instead\n\nWould you like to install Thunar?" 12 60

        if [ $? -eq 0 ]; then
            install_gui_browser
        else
            terminal_file_browser
        fi
        return
    fi

    # Check if Thunar is installed
    if ! command -v thunar >/dev/null 2>&1; then
        dialog --title "Thunar Not Installed" --yesno "Thunar file manager is not installed.\n\nInstall now? (~25MB download)" 8 50

        if [ $? -eq 0 ]; then
            install_gui_browser
        else
            terminal_file_browser
        fi
        return
    fi

    # Launch Thunar
    dialog --title "Launching GUI" --infobox "Starting Thunar file browser...\n\n$PHOTO_DIR" 6 50
    thunar "$PHOTO_DIR" &
    sleep 2

    dialog --title "GUI Browser Launched" --msgbox "Thunar file browser is now running.\n\nTo copy files to USB:\n1. Insert USB drive\n2. It will appear in left sidebar\n3. Drag and drop files to USB\n\nPress Alt+Tab to switch windows." 12 60
}

install_gui_browser() {
    dialog --title "Installing" --infobox "Installing Thunar and X11...\n\nThis may take a few minutes.\n\nPlease wait..." 8 50

    # Install minimal X11 and Thunar
    if sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y xorg thunar >/dev/null 2>&1; then
        dialog --title "Installation Complete" --msgbox "✓ Thunar installed successfully!\n\nYou can now use the GUI file browser.\n\nNote: You may need to configure X11\nfor your display if not already set up." 10 60

        # Try to launch if DISPLAY is set
        if [ -n "$DISPLAY" ]; then
            gui_file_browser
        fi
    else
        dialog --title "Installation Failed" --msgbox "❌ Failed to install Thunar.\n\nPossible reasons:\n• No internet connection\n• Insufficient disk space\n• Package repository issues\n\nUsing terminal file browser instead." 12 60
        terminal_file_browser
    fi
}

# Quick USB Copy
quick_usb_copy() {
    if [ ! -d "$PHOTO_DIR" ]; then
        dialog --title "Error" --msgbox "Photo directory not found:\n$PHOTO_DIR" 8 60
        return
    fi

    # Quick date selection for common scenarios
    dialog --title "Quick USB Copy" --menu "Select files to copy:" 14 60 6 \
        1 "Today's Photos" \
        2 "Last 7 Days" \
        3 "This Month" \
        4 "All Photos" \
        5 "Custom Selection" \
        6 "Cancel" 2>"$TEMP_DIR/quick_copy_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    local choice=$(cat "$TEMP_DIR/quick_copy_choice")

    case $choice in
        6) return ;;
        5) terminal_file_browser; return ;;
    esac

    # Build find command
    local find_cmd="find \"$PHOTO_DIR\" -type f"
    local desc=""

    case $choice in
        1)
            find_cmd="$find_cmd -mtime 0"
            desc="Today's Photos"
            ;;
        2)
            find_cmd="$find_cmd -mtime -7"
            desc="Last 7 Days"
            ;;
        3)
            local month_start=$(date +%Y-%m-01)
            find_cmd="$find_cmd -newermt \"$month_start\""
            desc="This Month"
            ;;
        4)
            desc="All Photos"
            ;;
    esac

    # Get files
    dialog --title "Scanning..." --infobox "Finding files...\n\n$desc" 6 50
    local files=$(eval "$find_cmd 2>/dev/null")
    local file_count=$(echo "$files" | grep -c '^' 2>/dev/null || echo "0")

    if [ -z "$files" ] || [ "$file_count" -eq 0 ]; then
        dialog --title "No Files" --msgbox "No files found for:\n$desc" 8 50
        return
    fi

    local total_size=$(echo "$files" | xargs du -ch 2>/dev/null | tail -1 | cut -f1)

    # Confirm
    if ! dialog --title "Confirm Quick Copy" --yesno "Copy $file_count files ($total_size) to USB?\n\nFiles: $desc\n\nProceed?" 10 60; then
        return
    fi

    # Save to temp file
    echo "$files" > "$TEMP_SELECTION_FILE"

    # Copy to USB
    copy_selected_to_usb "$file_count" "$total_size"
}

# File Statistics
file_statistics() {
    if [ ! -d "$PHOTO_DIR" ]; then
        dialog --title "Error" --msgbox "Photo directory not found:\n$PHOTO_DIR" 8 60
        return
    fi

    dialog --title "Calculating..." --infobox "Analyzing photo storage...\n\nThis may take a moment..." 6 50

    # Calculate stats
    local total_files=$(find "$PHOTO_DIR" -type f 2>/dev/null | wc -l)
    local total_size=$(du -sh "$PHOTO_DIR" 2>/dev/null | cut -f1)

    local today_files=$(find "$PHOTO_DIR" -type f -mtime 0 2>/dev/null | wc -l)
    local today_size=$(find "$PHOTO_DIR" -type f -mtime 0 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | cut -f1 || echo "0")

    local yesterday_files=$(find "$PHOTO_DIR" -type f -mtime 1 2>/dev/null | wc -l)
    local yesterday_size=$(find "$PHOTO_DIR" -type f -mtime 1 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | cut -f1 || echo "0")

    local week_files=$(find "$PHOTO_DIR" -type f -mtime -7 2>/dev/null | wc -l)
    local week_size=$(find "$PHOTO_DIR" -type f -mtime -7 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | cut -f1 || echo "0")

    local older_files=$((total_files - week_files))

    # Get oldest and newest file dates
    local oldest_file=$(find "$PHOTO_DIR" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f1 | cut -d'+' -f1)
    local newest_file=$(find "$PHOTO_DIR" -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -1 | cut -d' ' -f1 | cut -d'+' -f1)

    # Disk usage
    local disk_total=$(df -h "$PHOTO_DIR" 2>/dev/null | awk 'NR==2{print $2}')
    local disk_used=$(df -h "$PHOTO_DIR" 2>/dev/null | awk 'NR==2{print $3}')
    local disk_free=$(df -h "$PHOTO_DIR" 2>/dev/null | awk 'NR==2{print $4}')
    local disk_percent=$(df -h "$PHOTO_DIR" 2>/dev/null | awk 'NR==2{print $5}')

    local stats_text="PHOTO STORAGE STATISTICS
========================

Storage Path: $PHOTO_DIR

Total Files: $total_files
Total Size: $total_size

Files by Date:
  • Today:        $today_files files ($today_size)
  • Yesterday:    $yesterday_files files ($yesterday_size)
  • Last 7 Days:  $week_files files ($week_size)
  • Older:        $older_files files

Date Range:
  • Oldest: $oldest_file
  • Newest: $newest_file

Disk Usage:
  • Total: $disk_total
  • Used:  $disk_used ($disk_percent)
  • Free:  $disk_free

Average File Size: $(echo "scale=2; $total_size / $total_files" | bc 2>/dev/null || echo "N/A") MB"

    dialog --title "Photo Statistics" --msgbox "$stats_text" 24 70
}

# File Cleanup
file_cleanup() {
    dialog --title "File Cleanup" --menu "Choose cleanup option:" 14 60 6 \
        1 "Delete Files Older than 30 Days" \
        2 "Delete Files Older than 60 Days" \
        3 "Delete Files Older than 90 Days" \
        4 "Archive to USB (then delete)" \
        5 "Custom Cleanup" \
        6 "Cancel" 2>"$TEMP_DIR/cleanup_choice"

    if [ $? -ne 0 ]; then
        return
    fi

    local choice=$(cat "$TEMP_DIR/cleanup_choice")

    case $choice in
        1) cleanup_old_files 30 ;;
        2) cleanup_old_files 60 ;;
        3) cleanup_old_files 90 ;;
        4) archive_and_cleanup ;;
        5) terminal_file_browser ;;
        6) return ;;
    esac
}

cleanup_old_files() {
    local days="$1"

    if [ ! -d "$PHOTO_DIR" ]; then
        dialog --title "Error" --msgbox "Photo directory not found:\n$PHOTO_DIR" 8 60
        return
    fi

    # Find old files
    dialog --title "Scanning..." --infobox "Finding files older than $days days..." 6 50
    local old_files=$(find "$PHOTO_DIR" -type f -mtime +$days 2>/dev/null)
    local file_count=$(echo "$old_files" | grep -c '^' 2>/dev/null || echo "0")

    if [ -z "$old_files" ] || [ "$file_count" -eq 0 ]; then
        dialog --title "No Files" --msgbox "No files older than $days days found." 8 50
        return
    fi

    local total_size=$(echo "$old_files" | xargs du -ch 2>/dev/null | tail -1 | cut -f1)

    # Confirm deletion
    if ! dialog --title "Confirm Cleanup" --yesno "⚠️  DELETE $file_count files older than $days days?\n\nTotal size: $total_size\n\nThis action CANNOT be undone!\n\nContinue?" 12 60; then
        return
    fi

    # Save to temp file and delete
    echo "$old_files" > "$TEMP_SELECTION_FILE"
    delete_selected_files "$file_count"
}

archive_and_cleanup() {
    dialog --title "Archive & Cleanup" --msgbox "Archive and cleanup feature:\n\n1. Select files to archive\n2. Copy to USB drive\n3. Delete from local storage after successful copy\n\nThis helps free up space while preserving files on USB backup.\n\nUse 'Terminal File Browser' to select files,\nthen choose 'Copy to USB' option." 14 70

    terminal_file_browser
}

# Open in Shell
open_in_shell() {
    clear
    echo "==================================="
    echo "Camera Bridge - Photo Directory"
    echo "==================================="
    echo ""
    echo "Location: $PHOTO_DIR"
    echo ""
    echo "You are now in a shell session."
    echo "Type 'exit' to return to the menu."
    echo ""

    cd "$PHOTO_DIR" 2>/dev/null || cd /
    bash
}

# USB Management
usb_management() {
    while true; do
        dialog --title "USB Management" --menu "Choose an option:" 14 60 7 \
            1 "Detect USB Devices" \
            2 "Mount USB Device" \
            3 "Unmount USB Device" \
            4 "Format USB Device" \
            5 "Check USB Health" \
            6 "Eject USB Safely" \
            7 "Back to File Management" 2>"$TEMP_DIR/usb_mgmt_choice"

        if [ $? -ne 0 ]; then
            return
        fi

        choice=$(cat "$TEMP_DIR/usb_mgmt_choice")
        case $choice in
            1) show_usb_devices ;;
            2) mount_usb_device ;;
            3) unmount_usb_device ;;
            4) format_usb_device ;;
            5) check_usb_health ;;
            6) eject_usb_safely ;;
            7) return ;;
        esac
    done
}

show_usb_devices() {
    dialog --title "Scanning..." --infobox "Detecting USB devices...\n\nPlease wait..." 6 50
    sleep 1

    local usb_list=$(detect_usb_devices)

    if [ "$usb_list" = "NONE" ]; then
        dialog --title "No USB Devices" --msgbox "No USB devices detected.\n\nPlease insert a USB drive and try again." 8 50
        return
    fi

    # Format USB list for display
    local usb_info=""
    echo -e "$usb_list" | while IFS='|' read -r index device model size mount free fs; do
        if [ -n "$device" ]; then
            usb_info="${usb_info}Device: $device\n"
            usb_info="${usb_info}Model: $model\n"
            usb_info="${usb_info}Size: $size\n"
            usb_info="${usb_info}Filesystem: $fs\n"
            usb_info="${usb_info}Mount: $mount\n"
            if [ "$mount" != "<not mounted>" ]; then
                usb_info="${usb_info}Free Space: $free\n"
            fi
            usb_info="${usb_info}\n"
            echo -e "$usb_info"
        fi
    done > "$TEMP_DIR/usb_info_display"

    dialog --title "USB Devices Detected" --msgbox "$(cat "$TEMP_DIR/usb_info_display")" 20 70
}

mount_usb_device() {
    dialog --title "Mount USB" --msgbox "USB mounting feature:\n\nUSB devices are automatically mounted\nwhen you select them for file operations.\n\nIf you need to manually mount:\n1. Detect USB devices first\n2. Note the device path (/dev/sdX)\n3. Use 'Open in Shell' and run:\n   sudo mount /dev/sdX1 /media/usb" 14 60
}

unmount_usb_device() {
    dialog --title "Unmount USB" --msgbox "USB unmounting feature:\n\nTo safely unmount a USB device:\n\n1. Use 'Open in Shell'\n2. Run: sudo umount /media/usb_*\n3. Or use 'Eject USB Safely' option\n\nAlways unmount before removing\nto prevent data corruption!" 12 60
}

format_usb_device() {
    dialog --title "Format USB" --msgbox "⚠️  USB formatting is not yet implemented\nin this menu system.\n\nTo format a USB drive:\n\n1. Use 'Open in Shell'\n2. Identify device: lsblk\n3. Format: sudo mkfs.ext4 /dev/sdX1\n   or: sudo mkfs.vfat /dev/sdX1\n\n⚠️  WARNING: Formatting erases all data!" 14 60
}

check_usb_health() {
    dialog --title "USB Health Check" --msgbox "USB health checking:\n\nBasic checks available:\n• Device detection: Working\n• Mount status: Available\n• Free space: Displayed\n\nFor detailed diagnostics:\n1. Use 'Open in Shell'\n2. Run: sudo smartctl -a /dev/sdX\n\n(Requires smartmontools package)" 14 60
}

eject_usb_safely() {
    local usb_list=$(detect_usb_devices)

    if [ "$usb_list" = "NONE" ]; then
        dialog --title "No USB Devices" --msgbox "No USB devices detected." 6 40
        return
    fi

    dialog --title "Eject USB" --msgbox "Safe USB ejection:\n\nBefore removing your USB drive:\n\n1. Close all file operations\n2. Use 'Unmount USB Device'\n3. Wait for confirmation\n4. Physically remove the drive\n\nThis prevents data loss and corruption." 12 60
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

$(local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1); iwconfig "$wifi_iface" 2>/dev/null || echo "Interface not available")

$(local wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1); ip addr show "$wifi_iface" 2>/dev/null || echo "No IP information available")

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