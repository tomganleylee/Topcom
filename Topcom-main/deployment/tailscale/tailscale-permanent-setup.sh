#!/bin/bash

# Tailscale Permanent Connection Setup
# This script ensures Tailscale stays connected indefinitely

set -e

echo "=== Tailscale Permanent Connection Setup ==="
echo "This script will configure Tailscale to stay connected permanently"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo: sudo ./tailscale-permanent-setup.sh"
    exit 1
fi

# Step 1: Disable key expiry
echo "Step 1: Disabling key expiry..."
echo "IMPORTANT: You need to disable key expiry in the Tailscale admin console:"
echo "  1. Go to https://login.tailscale.com/admin/machines"
echo "  2. Find this machine (topcon)"
echo "  3. Click on the '...' menu"
echo "  4. Select 'Disable key expiry'"
echo
echo "Press Enter after you've disabled key expiry in the admin console..."
read

# Step 2: Set Tailscale to start on boot
echo "Step 2: Ensuring Tailscale starts on boot..."
systemctl enable tailscaled
systemctl start tailscaled

# Step 3: Create a systemd service for keeping Tailscale up
echo "Step 3: Creating Tailscale keepalive service..."
cat > /etc/systemd/system/tailscale-keepalive.service << 'EOF'
[Unit]
Description=Tailscale Connection Keepalive
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/tailscale-keepalive.sh
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Step 4: Create the keepalive script
echo "Step 4: Creating keepalive script..."
cat > /usr/local/bin/tailscale-keepalive.sh << 'EOF'
#!/bin/bash

# Tailscale Keepalive Script
# Ensures Tailscale stays connected

LOG_FILE="/var/log/tailscale-keepalive.log"
CHECK_INTERVAL=300  # Check every 5 minutes

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_tailscale() {
    # Check if Tailscale is running
    if ! systemctl is-active --quiet tailscaled; then
        log_message "WARNING: tailscaled service is not running. Starting..."
        systemctl start tailscaled
        sleep 10
    fi

    # Check if Tailscale is connected
    if ! tailscale status &>/dev/null; then
        log_message "WARNING: Tailscale is not connected. Attempting to reconnect..."
        tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh
        sleep 10
    fi

    # Get Tailscale IP to verify connection
    TS_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TS_IP" ]; then
        log_message "Tailscale is connected with IP: $TS_IP"
        return 0
    else
        log_message "ERROR: Unable to get Tailscale IP. Connection may be down."
        return 1
    fi
}

log_message "Tailscale Keepalive Service Started"

# Initial check
check_tailscale

# Main loop
while true; do
    sleep "$CHECK_INTERVAL"
    check_tailscale
done
EOF

chmod +x /usr/local/bin/tailscale-keepalive.sh

# Step 5: Create a network recovery script
echo "Step 5: Creating network recovery script..."
cat > /usr/local/bin/tailscale-recover.sh << 'EOF'
#!/bin/bash

# Tailscale Recovery Script
# Use this if Tailscale disconnects and won't reconnect

echo "=== Tailscale Recovery Script ==="
echo "Attempting to recover Tailscale connection..."

# Stop services
systemctl stop tailscale-keepalive
systemctl stop tailscaled

# Clean up any stale state
rm -f /var/lib/tailscale/*.state

# Restart services
systemctl start tailscaled
sleep 5

# Reconnect with safe options
tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh

# Restart keepalive
systemctl start tailscale-keepalive

echo "Recovery complete. Checking status..."
tailscale status
EOF

chmod +x /usr/local/bin/tailscale-recover.sh

# Step 6: Enable and start the keepalive service
echo "Step 6: Enabling keepalive service..."
systemctl daemon-reload
systemctl enable tailscale-keepalive.service
systemctl start tailscale-keepalive.service

# Step 7: Create a cron job as backup
echo "Step 7: Adding cron backup check..."
cat > /etc/cron.d/tailscale-check << 'EOF'
# Check Tailscale connection every 10 minutes
*/10 * * * * root /usr/bin/tailscale status >/dev/null 2>&1 || /usr/bin/tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh >/dev/null 2>&1
EOF

# Step 8: Configure unattended upgrades to not break Tailscale
echo "Step 8: Configuring unattended upgrades..."
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    # Ensure Tailscale packages are not automatically removed
    grep -q "tailscale" /etc/apt/apt.conf.d/50unattended-upgrades || \
    echo 'Unattended-Upgrade::Package-Blacklist {
    "tailscale";
    "tailscaled";
};' >> /etc/apt/apt.conf.d/50unattended-upgrades
fi

echo
echo "=== Setup Complete ==="
echo
echo "Tailscale is now configured for permanent connection with:"
echo "  ✓ Auto-start on boot"
echo "  ✓ Keepalive service checking every 5 minutes"
echo "  ✓ Cron backup check every 10 minutes"
echo "  ✓ Recovery script at /usr/local/bin/tailscale-recover.sh"
echo
echo "IMPORTANT MANUAL STEPS:"
echo "========================"
echo "1. Disable key expiry in Tailscale admin console:"
echo "   https://login.tailscale.com/admin/machines"
echo "   Find 'topcon' → Click '...' → 'Disable key expiry'"
echo
echo "2. For future deployments, create a pre-auth key:"
echo "   https://login.tailscale.com/admin/settings/keys"
echo "   - Click 'Generate auth key'"
echo "   - Check 'Reusable' and 'Ephemeral' options"
echo "   - Set expiration to maximum (90 days) or use API for longer"
echo "   - Save the key for deployment"
echo
echo "3. Monitor the connection:"
echo "   journalctl -u tailscale-keepalive -f"
echo "   tail -f /var/log/tailscale-keepalive.log"
echo
echo "Service Status:"
systemctl status tailscale-keepalive --no-pager
echo
echo "Current Tailscale Status:"
tailscale status
EOF