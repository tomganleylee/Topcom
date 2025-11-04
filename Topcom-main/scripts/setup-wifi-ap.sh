#!/bin/bash

# WiFi Access Point Bridge Setup Script
# Automatically detects USB WiFi adapter and creates bridge with ethernet

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Must run as root"
    exit 1
fi

# Configuration
ETHERNET_IFACE="eno1"
BRIDGE_IFACE="br0"
BRIDGE_IP="192.168.10.1"
BRIDGE_NETMASK="255.255.255.0"
UPLINK_IFACE="wlp1s0"  # Internet connection
HOSTAPD_CONF="/etc/hostapd/camera-bridge-ap.conf"

# Function to detect USB WiFi interface
detect_usb_wifi() {
    # Look for wireless interfaces that are NOT the built-in one
    for iface in /sys/class/net/*; do
        iface_name=$(basename "$iface")

        # Skip loopback, ethernet, tailscale, and built-in wifi
        if [[ "$iface_name" == "lo" || "$iface_name" == "eno"* || "$iface_name" == "eth"* || "$iface_name" == "tailscale"* || "$iface_name" == "wlp1s0" ]]; then
            continue
        fi

        # Check if it's a wireless interface
        if [ -d "$iface/wireless" ] || [ -d "$iface/phy80211" ]; then
            echo "$iface_name"
            return 0
        fi
    done

    return 1
}

# Function to check if interface supports AP mode
check_ap_mode() {
    local iface="$1"
    if iw list 2>/dev/null | grep -A 10 "Supported interface modes" | grep -q "AP"; then
        return 0
    fi
    return 1
}

# Start WiFi AP
start_ap() {
    log "Starting Camera Bridge WiFi Access Point"

    # Detect USB WiFi interface
    log "Detecting USB WiFi adapter..."
    USB_WIFI=$(detect_usb_wifi)

    if [ -z "$USB_WIFI" ]; then
        error "USB WiFi adapter not detected!"
        error "Please ensure:"
        error "  1. USB WiFi adapter is plugged in"
        error "  2. Driver is loaded (lsmod | grep 8812)"
        error "  3. Interface appears in 'ip link show'"
        exit 1
    fi

    log "USB WiFi interface detected: $USB_WIFI"

    # Update hostapd config with actual interface name
    sed -i "s/^interface=.*/interface=$USB_WIFI/" "$HOSTAPD_CONF"

    # Check if bridge already exists
    if ip link show "$BRIDGE_IFACE" >/dev/null 2>&1; then
        log "Bridge $BRIDGE_IFACE already exists"
    else
        log "Creating bridge $BRIDGE_IFACE..."

        # Create bridge
        brctl addbr "$BRIDGE_IFACE"

        # Configure bridge IP
        ip addr add "$BRIDGE_IP/$BRIDGE_NETMASK" dev "$BRIDGE_IFACE"
        ip link set "$BRIDGE_IFACE" up

        log "Bridge created: $BRIDGE_IFACE at $BRIDGE_IP"
    fi

    # Check if ethernet is already in bridge
    if brctl show "$BRIDGE_IFACE" 2>/dev/null | grep -q "$ETHERNET_IFACE"; then
        log "Ethernet $ETHERNET_IFACE already in bridge"
    else
        log "Adding ethernet interface to bridge..."

        # Remove IP from ethernet if present
        ip addr flush dev "$ETHERNET_IFACE" 2>/dev/null || true

        # Add ethernet to bridge
        ip link set "$ETHERNET_IFACE" down
        brctl addif "$BRIDGE_IFACE" "$ETHERNET_IFACE"
        ip link set "$ETHERNET_IFACE" up

        log "Ethernet $ETHERNET_IFACE added to bridge"
    fi

    # Prepare USB WiFi interface
    log "Preparing WiFi interface $USB_WIFI..."

    # Stop any existing hostapd
    systemctl stop hostapd 2>/dev/null || true
    killall hostapd 2>/dev/null || true
    sleep 2

    # Ensure interface is up
    ip link set "$USB_WIFI" down 2>/dev/null || true
    ip addr flush dev "$USB_WIFI" 2>/dev/null || true
    ip link set "$USB_WIFI" up

    # Update hostapd default config
    if ! grep -q "DAEMON_CONF=\"$HOSTAPD_CONF\"" /etc/default/hostapd 2>/dev/null; then
        echo "DAEMON_CONF=\"$HOSTAPD_CONF\"" >> /etc/default/hostapd
    fi

    # Start hostapd
    log "Starting hostapd..."
    systemctl unmask hostapd 2>/dev/null || true
    systemctl enable hostapd
    systemctl restart hostapd

    sleep 3

    # Check if hostapd started successfully
    if systemctl is-active --quiet hostapd; then
        log "✓ Hostapd started successfully"

        # WiFi interface will be added to bridge automatically by hostapd
        log "WiFi AP should now be broadcasting: CameraBridge-Photos"
    else
        error "Failed to start hostapd"
        journalctl -u hostapd -n 20 --no-pager
        exit 1
    fi

    # Restart dnsmasq to serve DHCP on bridge
    log "Restarting DHCP server..."
    systemctl restart dnsmasq

    # Configure NAT for internet access
    configure_nat

    log "✓ WiFi Access Point setup complete!"
    log ""
    log "Network Information:"
    log "  SSID: CameraBridge-Photos"
    log "  Password: YourSecurePassword123!"
    log "  Bridge IP: $BRIDGE_IP"
    log "  SMB Share: \\\\$BRIDGE_IP\\photos"
    log "  Username: camera"
    log "  Password: camera123"
}

# Stop WiFi AP
stop_ap() {
    log "Stopping Camera Bridge WiFi Access Point"

    # Stop hostapd
    systemctl stop hostapd 2>/dev/null || true

    # Detect USB WiFi
    USB_WIFI=$(detect_usb_wifi) || USB_WIFI=""

    if [ -n "$USB_WIFI" ]; then
        # Remove WiFi from bridge
        brctl delif "$BRIDGE_IFACE" "$USB_WIFI" 2>/dev/null || true
        ip link set "$USB_WIFI" down 2>/dev/null || true
    fi

    # Remove ethernet from bridge
    brctl delif "$BRIDGE_IFACE" "$ETHERNET_IFACE" 2>/dev/null || true

    # Delete bridge
    ip link set "$BRIDGE_IFACE" down 2>/dev/null || true
    brctl delbr "$BRIDGE_IFACE" 2>/dev/null || true

    # Restore ethernet IP
    ip addr add "$BRIDGE_IP/24" dev "$ETHERNET_IFACE" 2>/dev/null || true
    ip link set "$ETHERNET_IFACE" up

    # Remove NAT rules
    remove_nat

    # Restart dnsmasq on ethernet
    systemctl restart dnsmasq

    log "✓ WiFi AP stopped"
}

# Configure NAT for internet access
configure_nat() {
    log "Configuring NAT for internet access..."

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    # Make IP forwarding persistent
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.d/99-camera-bridge.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-camera-bridge.conf
    fi

    # Check if NAT rules already exist
    if ! iptables -t nat -C POSTROUTING -s 192.168.10.0/24 -o "$UPLINK_IFACE" -j MASQUERADE 2>/dev/null; then
        # Add NAT masquerading
        iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o "$UPLINK_IFACE" -j MASQUERADE
    fi

    # Allow forwarding
    if ! iptables -C FORWARD -i "$BRIDGE_IFACE" -o "$UPLINK_IFACE" -j ACCEPT 2>/dev/null; then
        iptables -A FORWARD -i "$BRIDGE_IFACE" -o "$UPLINK_IFACE" -j ACCEPT
    fi

    if ! iptables -C FORWARD -i "$UPLINK_IFACE" -o "$BRIDGE_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
        iptables -A FORWARD -i "$UPLINK_IFACE" -o "$BRIDGE_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    fi

    # Allow traffic within bridge
    if ! iptables -C FORWARD -i "$BRIDGE_IFACE" -o "$BRIDGE_IFACE" -j ACCEPT 2>/dev/null; then
        iptables -A FORWARD -i "$BRIDGE_IFACE" -o "$BRIDGE_IFACE" -j ACCEPT
    fi

    # Save iptables rules
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save 2>/dev/null || true
    fi

    log "✓ NAT configured"
}

# Remove NAT rules
remove_nat() {
    log "Removing NAT rules..."

    iptables -t nat -D POSTROUTING -s 192.168.10.0/24 -o "$UPLINK_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i "$BRIDGE_IFACE" -o "$UPLINK_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$UPLINK_IFACE" -o "$BRIDGE_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$BRIDGE_IFACE" -o "$BRIDGE_IFACE" -j ACCEPT 2>/dev/null || true

    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save 2>/dev/null || true
    fi
}

# Status check
status() {
    echo "Camera Bridge WiFi AP Status"
    echo "=============================="
    echo ""

    # Check if bridge exists
    if ip link show "$BRIDGE_IFACE" >/dev/null 2>&1; then
        echo "Bridge: ✓ Active ($BRIDGE_IFACE)"
        brctl show "$BRIDGE_IFACE"
    else
        echo "Bridge: ✗ Not active"
    fi

    echo ""

    # Check hostapd
    if systemctl is-active --quiet hostapd; then
        echo "Hostapd: ✓ Running"
        USB_WIFI=$(detect_usb_wifi) || USB_WIFI="unknown"
        echo "  Interface: $USB_WIFI"
        echo "  SSID: CameraBridge-Photos"
    else
        echo "Hostapd: ✗ Not running"
    fi

    echo ""

    # Check connected clients
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        client_count=$(wc -l < /var/lib/misc/dnsmasq.leases)
        echo "Connected clients: $client_count"
        if [ "$client_count" -gt 0 ]; then
            echo ""
            cat /var/lib/misc/dnsmasq.leases
        fi
    fi
}

# Main command handling
case "${1:-start}" in
    start)
        start_ap
        ;;
    stop)
        stop_ap
        ;;
    restart)
        stop_ap
        sleep 2
        start_ap
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
