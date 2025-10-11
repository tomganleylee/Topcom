#!/bin/bash

echo "Fixing camera-bridge service..."

# Fix the service command
sudo sed -i 's/ExecStart=.*camera-bridge-service.sh.*/ExecStart=\/opt\/camera-bridge\/scripts\/camera-bridge-service.sh start/' /etc/systemd/system/camera-bridge.service

# Also change Type back to forking since the script expects to fork
sudo sed -i 's/Type=simple/Type=forking/' /etc/systemd/system/camera-bridge.service

# Fix the PIDFile path
sudo sed -i 's|/var/run/camera-bridge.pid|/run/camera-bridge.pid|' /etc/systemd/system/camera-bridge.service

# Reload systemd
sudo systemctl daemon-reload

# Stop any failed attempts
sudo systemctl stop camera-bridge
sudo pkill -f camera-bridge-service.sh 2>/dev/null

# Start the service
sudo systemctl start camera-bridge

echo "Service fixed and started!"
echo ""
echo "Check status:"
sudo systemctl status camera-bridge --no-pager | head -15