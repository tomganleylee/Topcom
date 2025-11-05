#!/bin/bash

# Camera Bridge WiFi Access Point Setup Script
# Configures USB WiFi dongle as an access point for wireless device access

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

log "Camera Bridge WiFi Access Point Setup"
echo "======================================"

# Detect USB WiFi interface
USB_WIFI=$(ip link | grep -E "^[0-9]+: wlx" | cut -d: -f2 | tr -d ' ' | head -1)

if [ -z "$USB_WIFI" ]; then
    warn "No USB WiFi adapter detected (wlx*)"
    warn "Please plug in a compatible USB WiFi dongle"
    warn "Supported chipsets: Atheros AR9271, RTL8812AU, etc."
    exit 1
fi

log "Detected USB WiFi interface: $USB_WIFI"

# WiFi AP Configuration
WIFI_SSID="${WIFI_SSID:-CameraBridge-Setup}"
WIFI_PASSWORD="${WIFI_PASSWORD:-camera123}"
WIFI_NETWORK="192.168.50"
WIFI_IP="${WIFI_NETWORK}.1"

log "WiFi AP Configuration:"
log "  SSID: $WIFI_SSID"
log "  Password: $WIFI_PASSWORD"
log "  Network: ${WIFI_NETWORK}.0/24"
log "  Gateway IP: $WIFI_IP"

# ========================================
# 1. Configure Network Interface
# ========================================
log "Configuring network interface..."

# Create systemd-networkd configuration
cat > /etc/systemd/network/10-camera-bridge-usb-wifi.network << EOF
[Match]
Name=$USB_WIFI

[Link]
RequiredForOnline=no

[Network]
Address=$WIFI_IP/24
ConfigureWithoutCarrier=yes
EOF

log "Created /etc/systemd/network/10-camera-bridge-usb-wifi.network"

# Enable systemd-networkd
systemctl enable systemd-networkd
systemctl restart systemd-networkd

# Wait for interface to come up
sleep 2

# ========================================
# 2. Configure hostapd (Access Point)
# ========================================
log "Configuring hostapd..."

mkdir -p /etc/hostapd

cat > /etc/hostapd/hostapd-camera-bridge.conf << EOF
# Camera Bridge Hotspot Configuration
# USB WiFi Adapter

interface=$USB_WIFI
driver=nl80211
ssid=$WIFI_SSID
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1

# WPA2 Security
wpa=2
wpa_passphrase=$WIFI_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP

# Access Point Settings
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

log "Created /etc/hostapd/hostapd-camera-bridge.conf"

# Configure hostapd service override
mkdir -p /etc/systemd/system/hostapd.service.d

cat > /etc/systemd/system/hostapd.service.d/override.conf << EOF
[Service]
Type=simple
ExecStart=
ExecStart=/usr/sbin/hostapd -d /etc/hostapd/hostapd-camera-bridge.conf
EOF

log "Created hostapd service override"

# ========================================
# 3. Configure dnsmasq (DHCP Server)
# ========================================
log "Configuring dnsmasq for WiFi network..."

mkdir -p /etc/dnsmasq.d

cat > /etc/dnsmasq.d/camera-bridge-wifi.conf << EOF
# Camera Bridge WiFi Hotspot DHCP Configuration
# Only active when USB WiFi adapter is plugged in

# Interface to listen on (USB WiFi adapter)
interface=$USB_WIFI

# DHCP range - separate network from eno1
dhcp-range=${WIFI_NETWORK}.10,${WIFI_NETWORK}.100,255.255.255.0,24h

# Default gateway (this device on WiFi network)
dhcp-option=3,$WIFI_IP

# DNS servers
dhcp-option=6,8.8.8.8,8.8.4.4

# Bind to interface
# bind-dynamic is set in camera-bridge.conf

# Log queries
log-queries
log-dhcp
EOF

log "Created /etc/dnsmasq.d/camera-bridge-wifi.conf"

# ========================================
# 4. Update Samba Configuration
# ========================================
log "Updating Samba configuration..."

# Check if USB WiFi interface is already in smb.conf
if ! grep -q "$USB_WIFI" /etc/samba/smb.conf; then
    # Add USB WiFi interface to interfaces line
    sed -i "s/interfaces = \(.*\)/interfaces = \1 $USB_WIFI/" /etc/samba/smb.conf
    log "Added $USB_WIFI to Samba interfaces"
else
    log "Samba already configured for $USB_WIFI"
fi

# ========================================
# 5. Enable and Start Services
# ========================================
log "Enabling and starting services..."

# Reload systemd
systemctl daemon-reload

# Enable hostapd
systemctl enable hostapd

# Restart dnsmasq
systemctl restart dnsmasq

# Start hostapd
systemctl restart hostapd

# Restart Samba
systemctl restart smbd nmbd

# Wait for services to start
sleep 3

# ========================================
# 6. Verify Setup
# ========================================
log "Verifying setup..."

# Check interface status
if ip addr show "$USB_WIFI" | grep -q "$WIFI_IP"; then
    log "✓ Interface $USB_WIFI has IP $WIFI_IP"
else
    warn "✗ Interface $USB_WIFI does not have IP $WIFI_IP"
fi

# Check hostapd status
if systemctl is-active --quiet hostapd; then
    log "✓ hostapd is running"
else
    warn "✗ hostapd is not running"
fi

# Check dnsmasq status
if systemctl is-active --quiet dnsmasq; then
    log "✓ dnsmasq is running"
else
    warn "✗ dnsmasq is not running"
fi

# Check Samba status
if systemctl is-active --quiet smbd; then
    log "✓ Samba is running"
else
    warn "✗ Samba is not running"
fi

echo ""
log "WiFi Access Point Setup Complete!"
echo ""
echo "Network Configuration:"
echo "  SSID: $WIFI_SSID"
echo "  Password: $WIFI_PASSWORD"
echo "  Gateway: $WIFI_IP"
echo "  Network: ${WIFI_NETWORK}.0/24"
echo ""
echo "Samba Share Access (from WiFi):"
echo "  \\\\$WIFI_IP\\photos"
echo "  Username: camera"
echo "  Password: camera"
echo ""
log "WiFi AP is now broadcasting!"
