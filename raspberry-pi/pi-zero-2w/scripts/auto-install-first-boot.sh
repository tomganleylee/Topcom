#!/bin/bash

# Camera Bridge Auto-Installation Script for First Boot
# This script runs automatically on first boot to install Camera Bridge

set -e

LOG_FILE="/var/log/camera-bridge-auto-install.log"
INSTALL_FLAG="/opt/camera-bridge-auto-installed"
CAMERA_BRIDGE_SOURCE="/boot/camera-bridge"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to show status on console
show_status() {
    echo "================================================"
    echo "Camera Bridge Auto-Installation"
    echo "================================================"
    echo "$1"
    echo "================================================"
}

# Check if already installed
if [ -f "$INSTALL_FLAG" ]; then
    log_message "Camera Bridge already installed, skipping auto-installation"
    exit 0
fi

log_message "Starting Camera Bridge auto-installation"
show_status "Installing Camera Bridge..."

# Wait for system to be ready
sleep 30

# Ensure we have network connectivity for any package downloads
log_message "Waiting for network connectivity..."
for i in {1..60}; do
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_message "Network connectivity confirmed"
        break
    fi
    if [ $i -eq 60 ]; then
        log_message "Warning: No internet connectivity, proceeding with offline installation"
    fi
    sleep 5
done

# Copy Camera Bridge files from boot partition to permanent location
if [ -d "$CAMERA_BRIDGE_SOURCE" ]; then
    log_message "Copying Camera Bridge files from boot partition..."

    # Create target directory
    sudo mkdir -p /opt/camera-bridge-source

    # Copy all files
    sudo cp -r "$CAMERA_BRIDGE_SOURCE"/* /opt/camera-bridge-source/
    sudo chmod +x /opt/camera-bridge-source/scripts/*.sh
    sudo chmod +x /opt/camera-bridge-source/raspberry-pi/pi-zero-2w/scripts/*.sh

    log_message "Camera Bridge files copied successfully"
else
    log_message "ERROR: Camera Bridge source files not found in $CAMERA_BRIDGE_SOURCE"
    show_status "ERROR: Installation files not found!"
    exit 1
fi

# Change to the source directory
cd /opt/camera-bridge-source

# Run the Pi Zero 2W installation script
log_message "Running Pi Zero 2W installation script..."
show_status "Installing Camera Bridge components..."

if sudo ./raspberry-pi/pi-zero-2w/scripts/install-pi-zero-2w.sh; then
    log_message "Pi Zero 2W installation completed successfully"
    show_status "Installation completed successfully!"
else
    log_message "ERROR: Pi Zero 2W installation failed"
    show_status "ERROR: Installation failed! Check logs."
    exit 1
fi

# Enable auto-start for seamless experience
log_message "Enabling seamless boot experience..."
if sudo ./scripts/setup-auto-login.sh enable; then
    log_message "Auto-login enabled successfully"
else
    log_message "Warning: Could not enable auto-login"
fi

if sudo ./scripts/setup-boot-splash.sh enable; then
    log_message "Boot splash enabled successfully"
else
    log_message "Warning: Could not enable boot splash"
fi

# Set up the auto-start script
log_message "Setting up auto-start script..."
sudo cp ./scripts/camera-bridge-autostart.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/camera-bridge-autostart.sh

# Create systemd service for auto-start
sudo tee /etc/systemd/system/camera-bridge-autostart.service > /dev/null << EOF
[Unit]
Description=Camera Bridge Auto-Start
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/camera-bridge-autostart.sh
User=camerabridge
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable camera-bridge-autostart.service

# Clean up boot partition files (optional, save space)
log_message "Cleaning up temporary files..."
sudo rm -rf "$CAMERA_BRIDGE_SOURCE" 2>/dev/null || true

# Mark installation as complete
sudo touch "$INSTALL_FLAG"
log_message "Camera Bridge auto-installation completed successfully"

# Final status message
show_status "Camera Bridge installed! Rebooting in 10 seconds..."
echo ""
echo "After reboot, the system will:"
echo "- Start Camera Bridge services"
echo "- Create WiFi hotspot: CameraBridge-Setup"
echo "- Provide web interface at: http://192.168.4.1"
echo ""
echo "No display or keyboard needed!"

# Wait and reboot
sleep 10
log_message "Rebooting system to complete setup"
sudo reboot