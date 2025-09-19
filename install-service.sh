#!/bin/bash

echo "📦 Installing Camera Bridge Service"
echo "===================================="

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Stop and disable old service
echo "1. Stopping old service..."
systemctl stop camera-bridge 2>/dev/null
systemctl disable camera-bridge 2>/dev/null

# Copy monitor script
echo "2. Installing monitor script..."
cp /home/tom/camera-bridge/simple-monitor.sh /opt/camera-bridge/scripts/
chmod +x /opt/camera-bridge/scripts/simple-monitor.sh

# Install new service file
echo "3. Installing systemd service..."
cp /home/tom/camera-bridge/camera-bridge-simple.service /etc/systemd/system/
systemctl daemon-reload

# Create log directory
echo "4. Creating log directory..."
mkdir -p /var/log/camera-bridge
chown -R camerabridge:camerabridge /var/log/camera-bridge

# Enable and start service
echo "5. Enabling service for auto-start on boot..."
systemctl enable camera-bridge-simple.service

echo "6. Starting service..."
systemctl start camera-bridge-simple.service

# Wait a moment
sleep 3

# Check status
echo ""
echo "Service Status:"
echo "==============="
if systemctl is-active --quiet camera-bridge-simple; then
    echo "✅ Service is RUNNING"
    echo ""
    echo "Recent logs:"
    journalctl -u camera-bridge-simple --since "1 minute ago" --no-pager | tail -10
else
    echo "❌ Service failed to start"
    echo ""
    echo "Error details:"
    journalctl -u camera-bridge-simple --since "1 minute ago" --no-pager | tail -15
fi

echo ""
echo "===================================="
echo "✅ INSTALLATION COMPLETE"
echo ""
echo "The service will:"
echo "• Start automatically on boot"
echo "• Monitor /srv/samba/camera-share for new photos"
echo "• Sync them to Dropbox:Camera-Photos immediately"
echo "• Restart automatically if it crashes"
echo ""
echo "Useful commands:"
echo "  View logs:    sudo journalctl -u camera-bridge-simple -f"
echo "  Check status: sudo systemctl status camera-bridge-simple"
echo "  Restart:      sudo systemctl restart camera-bridge-simple"
echo "  Stop:         sudo systemctl stop camera-bridge-simple"