#!/bin/bash

# Fix web UI WiFi detection

echo "Fixing Web UI WiFi Interface Detection..."

# Detect actual WiFi interface
WIFI_INTERFACE=$(ip link | grep -E "^[0-9]+: w" | cut -d: -f2 | tr -d ' ' | head -1)

if [ -z "$WIFI_INTERFACE" ]; then
    echo "No WiFi interface found!"
    exit 1
fi

echo "Detected WiFi interface: $WIFI_INTERFACE"

# Backup and fix the web UI
sudo cp /opt/camera-bridge/web/index.php /opt/camera-bridge/web/index.php.backup

# Replace hardcoded wlan0 with actual interface
sudo sed -i "s/wlan0/$WIFI_INTERFACE/g" /opt/camera-bridge/web/index.php

# Also fix it in the wifi-manager script if needed
if [ -f /opt/camera-bridge/scripts/wifi-manager.sh ]; then
    sudo sed -i "s/wlan0/$WIFI_INTERFACE/g" /opt/camera-bridge/scripts/wifi-manager.sh
fi

echo "✓ Web UI updated to use interface: $WIFI_INTERFACE"

# Check if already connected to network
CURRENT_IP=$(ip addr show $WIFI_INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
if [ -n "$CURRENT_IP" ]; then
    echo "✓ Already connected to network with IP: $CURRENT_IP"
    echo ""
    echo "Since you're already connected, you can:"
    echo "1. Skip WiFi setup in the web interface"
    echo "2. Go directly to Dropbox configuration"
    echo ""
fi

# Test WiFi scanning
echo "Testing WiFi scanning..."
sudo iwlist $WIFI_INTERFACE scan 2>/dev/null | grep -E "ESSID:" | head -5

echo ""
echo "Web UI should now work properly at:"
echo "http://$CURRENT_IP/"
echo ""
echo "Or use the simplified Dropbox setup:"
echo "sudo ./setup-dropbox-token.sh"