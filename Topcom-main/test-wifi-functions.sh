#!/bin/bash

# Test script for WiFi functionality
echo "=== Testing WiFi Functionality ==="

# Test interface detection
WIFI_INTERFACE=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
echo "1. WiFi Interface Detection: $WIFI_INTERFACE"

# Test current connection
if command -v iwgetid >/dev/null 2>&1; then
    CURRENT_SSID=$(iwgetid -r 2>/dev/null)
    if [ -n "$CURRENT_SSID" ]; then
        echo "2. Current Connection: $CURRENT_SSID"
    else
        echo "2. Current Connection: Not connected"
    fi
else
    echo "2. iwgetid not available"
fi

# Test interface status
if command -v iwconfig >/dev/null 2>&1 && [ -n "$WIFI_INTERFACE" ]; then
    echo "3. Interface Status:"
    iwconfig "$WIFI_INTERFACE" 2>/dev/null | grep -E "(ESSID|Signal level|Link Quality)" | sed 's/^/   /'
else
    echo "3. iwconfig not available or no interface"
fi

# Test IP address
if [ -n "$WIFI_INTERFACE" ]; then
    IP_ADDR=$(ip addr show "$WIFI_INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
    echo "4. IP Address: ${IP_ADDR:-No IP assigned}"
else
    echo "4. No WiFi interface detected"
fi

# Test WiFi manager script
if [ -x "scripts/wifi-manager.sh" ]; then
    echo "5. WiFi Manager Script: Found and executable"
else
    echo "5. WiFi Manager Script: Not found or not executable"
fi

# Test dialog availability
if command -v dialog >/dev/null 2>&1; then
    echo "6. Dialog Tool: Available"
else
    echo "6. Dialog Tool: Not available"
fi

echo ""
echo "=== WiFi Test Summary ==="
echo "Interface: $WIFI_INTERFACE"
echo "Connection: ${CURRENT_SSID:-Not connected}"
echo "IP: ${IP_ADDR:-No IP}"
echo ""
echo "WiFi functionality ready for testing in terminal UI!"