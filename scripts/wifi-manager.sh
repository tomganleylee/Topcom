#!/bin/bash

# WiFi Management Script for Camera Bridge
# Handles WiFi connections, access point mode, and network management

# Configuration
WIFI_INTERFACE="wlan0"
AP_SSID="CameraBridge-Setup"
AP_PASSWORD="setup123"
CONFIG_FILE="/etc/wpa_supplicant/wpa_supplicant.conf"
HOSTAPD_CONFIG="/etc/hostapd/hostapd.conf"
LOG_FILE="/var/log/camera-bridge/wifi.log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_message "INFO: $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_message "WARN: $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR: $1"
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
    log_message "DEBUG: $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if WiFi interface exists
check_wifi_interface() {
    if ! ip link show "$WIFI_INTERFACE" >/dev/null 2>&1; then
        error "WiFi interface $WIFI_INTERFACE not found"
        return 1
    fi
    return 0
}

# Start Access Point mode
start_ap_mode() {
    check_root

    if ! check_wifi_interface; then
        return 1
    fi

    info "Starting Access Point mode on $WIFI_INTERFACE"

    # Kill any existing wpa_supplicant processes
    pkill wpa_supplicant 2>/dev/null || true
    sleep 2

    # Stop conflicting services
    systemctl stop wpa_supplicant 2>/dev/null || true
    systemctl stop NetworkManager 2>/dev/null || true
    systemctl stop dhcpcd 2>/dev/null || true

    # Bring interface down and up
    ip link set "$WIFI_INTERFACE" down
    sleep 1
    ip link set "$WIFI_INTERFACE" up

    # Configure static IP for AP
    ip addr flush dev "$WIFI_INTERFACE"
    ip addr add 192.168.4.1/24 dev "$WIFI_INTERFACE"

    # Update hostapd configuration
    cat > "$HOSTAPD_CONFIG" << EOF
interface=$WIFI_INTERFACE
driver=nl80211
ssid=$AP_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

    # Start services
    systemctl start hostapd
    systemctl start dnsmasq

    # Wait for services to start
    sleep 3

    # Check if AP is running
    if systemctl is-active --quiet hostapd && systemctl is-active --quiet dnsmasq; then
        info "Access Point '$AP_SSID' is now active"
        info "Connect to '$AP_SSID' (password: $AP_PASSWORD) and visit http://192.168.4.1"
        return 0
    else
        error "Failed to start Access Point"
        return 1
    fi
}

# Stop Access Point mode
stop_ap_mode() {
    check_root

    info "Stopping Access Point mode"

    # Stop AP services
    systemctl stop hostapd 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true

    # Flush interface
    ip addr flush dev "$WIFI_INTERFACE" 2>/dev/null || true

    # Restart normal networking
    systemctl start NetworkManager 2>/dev/null || systemctl start wpa_supplicant 2>/dev/null || true
    systemctl start dhcpcd 2>/dev/null || true

    info "Access Point stopped"
}

# Connect to WiFi network
connect_wifi() {
    local ssid="$1"
    local password="$2"

    check_root

    if [ -z "$ssid" ]; then
        error "SSID is required"
        return 1
    fi

    if [ -z "$password" ]; then
        error "Password is required"
        return 1
    fi

    info "Connecting to WiFi network: $ssid"

    # Stop AP mode first if it's running
    if systemctl is-active --quiet hostapd; then
        stop_ap_mode
        sleep 2
    fi

    # Generate PSK for better security
    local psk
    if command -v wpa_passphrase >/dev/null 2>&1; then
        psk=$(wpa_passphrase "$ssid" "$password" | grep -E "^\s*psk=" | cut -d= -f2)
    fi

    # Create wpa_supplicant configuration
    cat > /tmp/wpa_supplicant.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$ssid"
$(if [ -n "$psk" ]; then
    echo "    psk=$psk"
else
    echo "    psk=\"$password\""
fi)
    key_mgmt=WPA-PSK
    priority=1
}
EOF

    # Backup existing configuration
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Apply new configuration
    cp /tmp/wpa_supplicant.conf "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    rm /tmp/wpa_supplicant.conf

    # Kill existing wpa_supplicant
    pkill wpa_supplicant 2>/dev/null || true
    sleep 2

    # Restart networking services
    if command -v NetworkManager >/dev/null 2>&1; then
        systemctl restart NetworkManager
    else
        # Start wpa_supplicant manually
        wpa_supplicant -B -i "$WIFI_INTERFACE" -c "$CONFIG_FILE"
        dhclient "$WIFI_INTERFACE" 2>/dev/null || dhcpcd "$WIFI_INTERFACE" 2>/dev/null || true
    fi

    # Wait for connection
    info "Waiting for connection..."
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        sleep 2
        attempts=$((attempts + 1))

        if get_connection_status >/dev/null 2>&1; then
            local connected_ssid=$(get_connection_status 2>/dev/null | grep "SSID:" | cut -d: -f2 | xargs)
            if [ "$connected_ssid" = "$ssid" ]; then
                info "Successfully connected to: $ssid"
                info "IP Address: $(get_ip_address)"
                return 0
            fi
        fi

        if [ $((attempts % 5)) -eq 0 ]; then
            debug "Still trying to connect... ($attempts/$max_attempts)"
        fi
    done

    error "Failed to connect to $ssid after $max_attempts attempts"
    return 1
}

# Get WiFi connection status
get_connection_status() {
    if ! check_wifi_interface; then
        return 1
    fi

    local ssid=$(iwgetid -r 2>/dev/null || echo "Not connected")
    local ip=$(get_ip_address)
    local signal=$(iwconfig "$WIFI_INTERFACE" 2>/dev/null | grep "Signal level" | sed 's/.*Signal level=\([^ ]*\).*/\1/' || echo "Unknown")

    if [ "$ssid" != "Not connected" ]; then
        echo "Status: Connected"
        echo "SSID: $ssid"
        echo "IP Address: $ip"
        echo "Signal Strength: $signal"
        return 0
    else
        echo "Status: Not connected"
        return 1
    fi
}

# Get IP address of WiFi interface
get_ip_address() {
    ip addr show "$WIFI_INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1 || echo "No IP"
}

# Scan for available networks
scan_networks() {
    check_root

    if ! check_wifi_interface; then
        return 1
    fi

    info "Scanning for WiFi networks..."

    # Bring interface up if it's down
    ip link set "$WIFI_INTERFACE" up 2>/dev/null || true

    # Perform scan
    local scan_output
    scan_output=$(iwlist "$WIFI_INTERFACE" scan 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$scan_output" ]; then
        echo "$scan_output" | grep 'ESSID:' | sed 's/.*ESSID:"\(.*\)".*/\1/' | grep -v '^$' | sort | uniq
        return 0
    else
        error "Failed to scan for networks"
        return 1
    fi
}

# Get detailed network information
get_network_info() {
    check_root

    if ! check_wifi_interface; then
        return 1
    fi

    info "Network Interface Information:"
    echo "Interface: $WIFI_INTERFACE"

    if ip link show "$WIFI_INTERFACE" >/dev/null 2>&1; then
        local status=$(ip link show "$WIFI_INTERFACE" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        echo "Link Status: $status"
    fi

    echo ""
    get_connection_status

    echo ""
    info "Available Networks:"
    scan_networks | head -10
}

# Reset network configuration
reset_network() {
    check_root

    warn "Resetting network configuration..."

    # Stop all network services
    stop_ap_mode

    # Kill all network processes
    pkill wpa_supplicant 2>/dev/null || true
    pkill dhclient 2>/dev/null || true
    pkill dhcpcd 2>/dev/null || true

    # Reset interface
    ip link set "$WIFI_INTERFACE" down
    sleep 1
    ip addr flush dev "$WIFI_INTERFACE"
    ip link set "$WIFI_INTERFACE" up

    # Remove configuration files
    rm -f "$CONFIG_FILE.backup.*" 2>/dev/null || true

    info "Network configuration reset complete"
}

# Monitor WiFi connection
monitor_connection() {
    info "Monitoring WiFi connection (Ctrl+C to stop)..."

    while true; do
        echo "$(date '+%H:%M:%S') - $(get_connection_status 2>/dev/null | grep "Status:" | cut -d: -f2 | xargs)"
        sleep 5
    done
}

# Show help
show_help() {
    echo "WiFi Manager for Camera Bridge"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start-ap              Start Access Point mode"
    echo "  stop-ap               Stop Access Point mode"
    echo "  connect <SSID> <PWD>  Connect to WiFi network"
    echo "  disconnect            Disconnect from current network"
    echo "  status                Show connection status"
    echo "  scan                  Scan for available networks"
    echo "  info                  Show detailed network information"
    echo "  reset                 Reset network configuration"
    echo "  monitor               Monitor connection status"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start-ap"
    echo "  $0 connect \"MyWiFi\" \"mypassword\""
    echo "  $0 status"
    echo "  $0 scan"
}

# Main script logic
case "$1" in
    start-ap)
        start_ap_mode
        ;;
    stop-ap)
        stop_ap_mode
        ;;
    connect)
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Usage: $0 connect <SSID> <PASSWORD>"
            exit 1
        fi
        connect_wifi "$2" "$3"
        ;;
    disconnect)
        stop_ap_mode
        pkill wpa_supplicant 2>/dev/null || true
        info "Disconnected from WiFi"
        ;;
    status)
        get_connection_status
        ;;
    scan)
        scan_networks
        ;;
    info)
        get_network_info
        ;;
    reset)
        reset_network
        ;;
    monitor)
        monitor_connection
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac