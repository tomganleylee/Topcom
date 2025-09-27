#!/bin/bash

echo "Fixing camera-bridge service configuration..."

# Stop the current service
sudo systemctl stop camera-bridge 2>/dev/null
sudo pkill -f camera-bridge-service.sh 2>/dev/null

# Fix the service file to use simple type instead of forking
sudo sed -i 's/Type=forking/Type=simple/' /etc/systemd/system/camera-bridge.service
sudo sed -i 's|ExecStart=/opt/camera-bridge/scripts/camera-bridge-service.sh start|ExecStart=/opt/camera-bridge/scripts/camera-bridge-service.sh run|' /etc/systemd/system/camera-bridge.service

# Reload systemd
sudo systemctl daemon-reload

echo "Service configuration fixed."
echo ""
echo "Now start the service:"
echo "  sudo systemctl start camera-bridge"
echo ""
echo "Check status:"
echo "  sudo systemctl status camera-bridge"
echo ""
echo "Monitor logs:"
echo "  sudo journalctl -u camera-bridge -f"