#!/bin/bash

# Test the show WiFi status functionality
echo "=== Testing show_wifi_status Function ==="

# Simulate the status gathering logic from terminal-ui.sh

# Find WiFi manager script
wifi_script=""
if [ -x "/opt/camera-bridge/scripts/wifi-manager.sh" ]; then
    wifi_script="/opt/camera-bridge/scripts/wifi-manager.sh"
elif [ -x "$HOME/camera-bridge/scripts/wifi-manager.sh" ]; then
    wifi_script="$HOME/camera-bridge/scripts/wifi-manager.sh"
fi

echo "WiFi script found: ${wifi_script:-No}"

# Get interface details
wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
echo "WiFi interface: $wifi_iface"

if [ -n "$wifi_iface" ] && command -v iwconfig >/dev/null 2>&1; then
    interface_status=$(iwconfig "$wifi_iface" 2>/dev/null | grep -E "(ESSID|Frequency|Access Point|Bit Rate|Signal level)" | head -5)
    echo "Interface status:"
    echo "$interface_status" | sed 's/^/  /'
fi

# Get hotspot status
hotspot_status="Stopped"
if systemctl is-active --quiet hostapd 2>/dev/null; then
    hotspot_status="Running (CameraBridge-Setup)"
fi
echo "Hotspot status: $hotspot_status"

echo ""
echo "This would be displayed in the terminal UI dialog!"