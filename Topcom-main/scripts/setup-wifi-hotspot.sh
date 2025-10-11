#!/bin/bash

# WiFi Hotspot Setup Script for TP-Link AC600 (RTL8821AU)
# Sets up USB WiFi adapter as hotspot bridged with ethernet
# Cameras can connect via WiFi or ethernet on same network (192.168.10.0/24)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WiFi Hotspot Setup - TP-Link AC600${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ========================================
# STEP 1: Check Hardware
# ========================================
log "Checking for TP-Link AC600 USB adapter..."

if ! lsusb | grep -q "2357:011f"; then
    error "TP-Link AC600 (2357:011f) not detected!"
    echo "Please connect the USB WiFi adapter and try again."
    exit 1
fi

log "TP-Link AC600 detected: $(lsusb | grep 2357:011f)"

# ========================================
# STEP 2: Check/Install RTL8821AU Driver
# ========================================
log "Checking RTL8821AU driver..."

if ! modinfo 8821au &>/dev/null; then
    warn "RTL8821AU driver not installed. Installing now..."

    # Install prerequisites
    log "Installing prerequisites..."
    apt update
    apt install -y build-essential dkms git iw bc

    # Clone and install driver
    log "Downloading RTL8821AU driver from morrownr/8821au-20210708..."
    cd /tmp
    rm -rf 8821au-20210708
    git clone https://github.com/morrownr/8821au-20210708.git
    cd 8821au-20210708

    log "Installing driver (this may take a few minutes)..."
    ./install-driver.sh || {
        error "Driver installation failed!"
        echo "Please check the error messages above and try installing manually:"
        echo "  cd /tmp/8821au-20210708"
        echo "  sudo ./install-driver.sh"
        exit 1
    }

    log "Driver installed successfully!"
    log "Reloading driver module..."
    modprobe -r 8821au 2>/dev/null || true
    modprobe 8821au
else
    log "RTL8821AU driver already installed"
fi

# Verify driver loaded
if ! lsmod | grep -q 8821au; then
    error "Driver module not loaded!"
    echo "Try loading manually: sudo modprobe 8821au"
    exit 1
fi

log "Driver module loaded successfully"

# ========================================
# STEP 3: Detect WiFi Interfaces
# ========================================
log "Detecting WiFi interfaces..."

# Get all wireless interfaces
WIFI_INTERFACES=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' || echo "")

if [ -z "$WIFI_INTERFACES" ]; then
    error "No wireless interfaces found!"
    exit 1
fi

log "Found wireless interfaces:"
for iface in $WIFI_INTERFACES; do
    info "  - $iface"
done

# Detect USB WiFi interface (usually wlx* or wlan1)
USB_WIFI=""
INTERNAL_WIFI=""

for iface in $WIFI_INTERFACES; do
    # Check if it's USB (by checking if it's the AC600)
    if [[ "$iface" == wlx* ]]; then
        USB_WIFI="$iface"
    elif [ -z "$INTERNAL_WIFI" ]; then
        INTERNAL_WIFI="$iface"
    fi
done

# If still no USB_WIFI and we have multiple interfaces, assume second one is USB
if [ -z "$USB_WIFI" ] && [ $(echo "$WIFI_INTERFACES" | wc -w) -gt 1 ]; then
    USB_WIFI=$(echo "$WIFI_INTERFACES" | awk '{print $2}')
fi

if [ -z "$USB_WIFI" ]; then
    error "Could not detect USB WiFi interface!"
    echo "Available interfaces: $WIFI_INTERFACES"
    echo ""
    read -p "Enter USB WiFi interface name (e.g., wlx00e04c123456 or wlan1): " USB_WIFI
    if [ -z "$USB_WIFI" ]; then
        error "No interface specified"
        exit 1
    fi
fi

log "USB WiFi interface: $USB_WIFI"
if [ -n "$INTERNAL_WIFI" ]; then
    log "Internal WiFi interface: $INTERNAL_WIFI (will be used for internet)"
fi

# Verify USB WiFi supports AP mode
log "Checking if $USB_WIFI supports AP mode..."
if ! iw list 2>/dev/null | grep -q "AP"; then
    warn "Could not verify AP mode support, proceeding anyway..."
fi

# ========================================
# STEP 4: Configure NetworkManager
# ========================================
log "Configuring NetworkManager to ignore USB WiFi..."

mkdir -p /etc/NetworkManager/conf.d

cat > /etc/NetworkManager/conf.d/unmanaged-wifi.conf << EOF
# Unmanage USB WiFi adapter for hotspot use
[keyfile]
unmanaged-devices=interface-name:wlx*;interface-name:wlan1;interface-name:$USB_WIFI
EOF

log "Restarting NetworkManager..."
systemctl restart NetworkManager
sleep 3

# ========================================
# STEP 5: Detect Ethernet Interface
# ========================================
log "Detecting ethernet interface..."

ETH_INTERFACE=$(ip link show | grep -E "^[0-9]+: e" | cut -d: -f2 | tr -d ' ' | head -1)

if [ -z "$ETH_INTERFACE" ]; then
    ETH_INTERFACE="eth0"  # fallback
fi

log "Ethernet interface: $ETH_INTERFACE"

# ========================================
# STEP 6: Create Bridge Configuration
# ========================================
log "Creating bridge configuration..."

# Check if using netplan or traditional networking
if [ -d "/etc/netplan" ]; then
    log "Using netplan for network configuration..."

    cat > /etc/netplan/99-camera-bridge.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $ETH_INTERFACE:
      dhcp4: no
      dhcp6: no
  bridges:
    br0:
      interfaces: [$ETH_INTERFACE]
      addresses: [192.168.10.1/24]
      dhcp4: no
      dhcp6: no
      parameters:
        stp: false
        forward-delay: 0
EOF

    log "Applying netplan configuration..."
    netplan apply
else
    log "Using systemd-networkd for network configuration..."

    # Create network file for ethernet
    cat > /etc/systemd/network/10-$ETH_INTERFACE.network << EOF
[Match]
Name=$ETH_INTERFACE

[Network]
Bridge=br0
EOF

    # Create network file for bridge
    cat > /etc/systemd/network/20-br0.netdev << EOF
[NetDev]
Name=br0
Kind=bridge

[Bridge]
STP=false
ForwardDelaySec=0
EOF

    cat > /etc/systemd/network/20-br0.network << EOF
[Match]
Name=br0

[Network]
Address=192.168.10.1/24
DHCPServer=no

[Link]
RequiredForOnline=no
EOF

    systemctl restart systemd-networkd
fi

sleep 5

# Verify bridge exists
if ! ip link show br0 &>/dev/null; then
    error "Bridge br0 was not created!"
    echo "Check network configuration and try again."
    exit 1
fi

log "Bridge br0 created successfully"

# ========================================
# STEP 7: Configure hostapd
# ========================================
log "Configuring hostapd for WiFi access point..."

cat > /etc/hostapd/hostapd.conf << EOF
# Interface and driver configuration
interface=$USB_WIFI
driver=nl80211
bridge=br0

# Network identification
ssid=Camera-Bridge
country_code=US

# WiFi mode and channel
hw_mode=g
channel=6
ieee80211n=1
ieee80211d=1
ieee80211h=0

# QoS and performance
wmm_enabled=1
beacon_int=100
dtim_period=2

# Security configuration
wpa=2
wpa_passphrase=camera123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
auth_algs=1
macaddr_acl=0

# Connection limits
max_num_sta=10
rts_threshold=2347
fragm_threshold=2346

# Logging
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2

# Other settings
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
EOF

log "hostapd configured for $USB_WIFI"

# Enable hostapd service
systemctl unmask hostapd 2>/dev/null || true
systemctl enable hostapd

# ========================================
# STEP 8: Update dnsmasq Configuration
# ========================================
log "Updating dnsmasq for bridge interface..."

cat > /etc/dnsmasq.d/camera-bridge.conf << EOF
# Camera Bridge DHCP Configuration
# Serves both ethernet and WiFi via bridge

# Bridge interface (includes ethernet + WiFi AP)
interface=br0
bind-dynamic

# Don't listen on these interfaces
except-interface=lo

# DHCP range for cameras
dhcp-range=interface:br0,192.168.10.10,192.168.10.50,255.255.255.0,24h

# Gateway and DNS
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4

# Enable DHCP logging
log-dhcp
EOF

log "Restarting dnsmasq..."
systemctl restart dnsmasq

# ========================================
# STEP 9: Configure NAT and Forwarding
# ========================================
log "Configuring NAT and IP forwarding..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1

# Detect internet interface (internal WiFi or ethernet)
INTERNET_IFACE=""
if [ -n "$INTERNAL_WIFI" ]; then
    INTERNET_IFACE="$INTERNAL_WIFI"
    log "Using internal WiFi ($INTERNAL_WIFI) for internet"
else
    # Check for other network interface with default route
    INTERNET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    log "Using $INTERNET_IFACE for internet"
fi

if [ -z "$INTERNET_IFACE" ]; then
    warn "No internet interface detected. NAT may not work."
    INTERNET_IFACE="wlp0s20f3"  # fallback
fi

# Clear existing NAT rules for this interface
iptables -t nat -D POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE 2>/dev/null || true

# Setup NAT
iptables -t nat -A POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE
iptables -A FORWARD -i br0 -o "$INTERNET_IFACE" -j ACCEPT
iptables -A FORWARD -i "$INTERNET_IFACE" -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

log "NAT configured for internet access via $INTERNET_IFACE"

# ========================================
# STEP 10: Test hostapd Configuration
# ========================================
log "Testing hostapd configuration..."

# Bring interface down/up to reset
ip link set "$USB_WIFI" down
sleep 1
ip link set "$USB_WIFI" up
sleep 2

# Test hostapd config
if hostapd -t /etc/hostapd/hostapd.conf; then
    log "hostapd configuration is valid"
else
    error "hostapd configuration test failed!"
    echo "Check /etc/hostapd/hostapd.conf for errors"
    exit 1
fi

# ========================================
# FINAL STATUS
# ========================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WiFi Hotspot Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Network Configuration:"
echo "  Bridge: br0 (192.168.10.1/24)"
echo "  Ethernet: $ETH_INTERFACE (bridged)"
echo "  WiFi AP: $USB_WIFI (bridged)"
echo "  Internet: $INTERNET_IFACE"
echo ""
echo "WiFi Access Point:"
echo "  SSID: Camera-Bridge"
echo "  Password: camera123"
echo "  Channel: 6 (2.4GHz)"
echo "  Security: WPA2"
echo ""
echo "DHCP Range: 192.168.10.10 - 192.168.10.50"
echo ""
echo "Next Steps:"
echo "  1. Start hostapd: sudo systemctl start hostapd"
echo "  2. Check status: sudo systemctl status hostapd"
echo "  3. View logs: sudo journalctl -u hostapd -f"
echo "  4. Test: Connect phone to 'Camera-Bridge' WiFi"
echo "  5. Verify: Phone should get 192.168.10.x IP"
echo ""
echo "Troubleshooting:"
echo "  - Test manually: sudo hostapd -d /etc/hostapd/hostapd.conf"
echo "  - Check interface: iw dev $USB_WIFI info"
echo "  - View dnsmasq: sudo journalctl -u dnsmasq -f"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} If hotspot doesn't start, reboot and try again:"
echo "  sudo reboot"
echo ""
echo -e "${GREEN}========================================${NC}"

# Offer to start hostapd now
echo ""
read -p "Start hostapd now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting hostapd..."
    systemctl start hostapd
    sleep 3

    if systemctl is-active --quiet hostapd; then
        log "✓ hostapd is running!"
        echo ""
        info "WiFi hotspot 'Camera-Bridge' should now be visible"
        info "Connect with password: camera123"
    else
        warn "hostapd failed to start"
        echo "Check logs: sudo journalctl -u hostapd -xe"
        echo "Try manual start: sudo hostapd -d /etc/hostapd/hostapd.conf"
    fi
else
    info "Skipping hostapd start. Start manually with:"
    info "  sudo systemctl start hostapd"
fi

echo ""
log "Setup complete!"
