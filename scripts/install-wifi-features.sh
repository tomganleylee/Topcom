#!/bin/bash

# Install WiFi Auto-Connect Features
# Sets up the WiFi auto-connect service and ensures proper permissions

echo "Installing Camera Bridge WiFi Auto-Connect Features..."

# Ensure directories exist
mkdir -p /var/log/camera-bridge
mkdir -p /opt/camera-bridge/config

# Set proper permissions
chmod +x /opt/camera-bridge/scripts/wifi-manager.sh
chmod +x /opt/camera-bridge/scripts/wifi-auto-connect.sh
chmod 600 /opt/camera-bridge/config/saved_networks.json 2>/dev/null || true

# Install systemd service
if [ -f "/opt/camera-bridge/config/wifi-auto-connect.service" ]; then
    echo "Installing WiFi auto-connect service..."
    cp /opt/camera-bridge/config/wifi-auto-connect.service /etc/systemd/system/
    systemctl daemon-reload

    # Enable and start the service automatically
    echo "Enabling WiFi auto-connect service..."
    systemctl enable wifi-auto-connect.service

    echo "Starting WiFi auto-connect service..."
    if systemctl start wifi-auto-connect.service; then
        echo "✅ WiFi auto-connect service installed, enabled, and started"
    else
        echo "⚠️  WiFi auto-connect service installed and enabled, but failed to start"
        echo "Check status with: sudo systemctl status wifi-auto-connect"
    fi
else
    echo "Service file not found, skipping service installation"
fi

# Test basic functionality
echo ""
echo "Testing WiFi manager functionality..."
if /opt/camera-bridge/scripts/wifi-manager.sh help >/dev/null 2>&1; then
    echo "✅ WiFi manager is working correctly"
else
    echo "❌ WiFi manager test failed"
fi

# Show saved networks status
echo ""
echo "Current saved networks:"
/opt/camera-bridge/scripts/wifi-manager.sh list-saved 2>/dev/null || echo "No saved networks yet"

echo ""
echo "Installation complete!"
echo ""
echo "New features available:"
echo "• Automatic password saving when connecting to networks"
echo "• Terminal UI: Enhanced 'Saved Networks' and 'Auto-Connect' menus"
echo "• Web UI: Visit http://$(hostname -I | awk '{print $1}')/wifi.php"
echo "• Auto-reconnect service (optional)"
echo ""
echo "Usage:"
echo "• Connect to networks normally - passwords are saved automatically"
echo "• Use 'wifi-manager.sh list-saved' to see saved networks"
echo "• Use 'wifi-manager.sh auto-connect' to connect to available saved networks"
echo "• Use terminal UI for full management features"