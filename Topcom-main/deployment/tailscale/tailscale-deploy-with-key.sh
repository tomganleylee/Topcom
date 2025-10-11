#!/bin/bash

# Tailscale Deployment with Pre-Authentication Key
# Use this script for deploying to new machines

set -e

# Configuration
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"  # Set via environment or edit below
# TAILSCALE_AUTH_KEY="tskey-auth-XXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXX"

echo "=== Tailscale Automated Deployment Script ==="
echo

# Check for auth key
if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    echo "ERROR: No auth key provided!"
    echo
    echo "Usage:"
    echo "  TAILSCALE_AUTH_KEY='tskey-auth-XXX' sudo ./tailscale-deploy-with-key.sh"
    echo
    echo "Or edit this script and set TAILSCALE_AUTH_KEY variable"
    echo
    echo "To get an auth key:"
    echo "  1. Go to https://login.tailscale.com/admin/settings/keys"
    echo "  2. Click 'Generate auth key'"
    echo "  3. Recommended settings:"
    echo "     - Reusable: Yes (for multiple deployments)"
    echo "     - Ephemeral: No (for permanent machines)"
    echo "     - Expiration: Maximum available"
    echo "     - Tags: Add appropriate tags for ACL control"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./tailscale-deploy-with-key.sh"
    exit 1
fi

# Step 1: Install Tailscale
echo "Step 1: Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "Tailscale already installed"
fi

# Step 2: Connect with auth key
echo "Step 2: Connecting to Tailscale network..."
tailscale up \
    --authkey="$TAILSCALE_AUTH_KEY" \
    --accept-routes=false \
    --accept-dns=false \
    --advertise-routes= \
    --ssh \
    --hostname="$(hostname)"

# Step 3: Install keepalive service
echo "Step 3: Installing keepalive service..."

# Create keepalive script
cat > /usr/local/bin/tailscale-keepalive.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/tailscale-keepalive.log"
CHECK_INTERVAL=300

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_tailscale() {
    if ! systemctl is-active --quiet tailscaled; then
        log_message "WARNING: tailscaled service is not running. Starting..."
        systemctl start tailscaled
        sleep 10
    fi

    if ! tailscale status &>/dev/null; then
        log_message "WARNING: Tailscale is not connected. Attempting to reconnect..."
        tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh
        sleep 10
    fi

    TS_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TS_IP" ]; then
        log_message "Tailscale connected: $TS_IP"
        return 0
    else
        log_message "ERROR: Unable to get Tailscale IP"
        return 1
    fi
}

log_message "Tailscale Keepalive Started"
check_tailscale

while true; do
    sleep "$CHECK_INTERVAL"
    check_tailscale
done
EOF

chmod +x /usr/local/bin/tailscale-keepalive.sh

# Create systemd service
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

[Install]
WantedBy=multi-user.target
EOF

# Enable services
systemctl daemon-reload
systemctl enable tailscaled
systemctl enable tailscale-keepalive
systemctl start tailscale-keepalive

# Step 4: Add cron backup
echo "Step 4: Adding cron backup..."
cat > /etc/cron.d/tailscale-check << 'EOF'
*/10 * * * * root /usr/bin/tailscale status >/dev/null 2>&1 || /usr/bin/tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh >/dev/null 2>&1
EOF

# Step 5: Save configuration
echo "Step 5: Saving deployment configuration..."
cat > /opt/tailscale-deployment.conf << EOF
# Tailscale Deployment Configuration
# Deployed: $(date)
# Hostname: $(hostname)
# Tailscale IP: $(tailscale ip -4)
# Auth Key Used: ${TAILSCALE_AUTH_KEY:0:20}...
# Options: --accept-routes=false --accept-dns=false --ssh
EOF

echo
echo "=== Deployment Complete ==="
echo
echo "Tailscale Status:"
tailscale status
echo
echo "Machine IP: $(tailscale ip -4)"
echo "Hostname: $(hostname)"
echo
echo "Services Status:"
systemctl is-active tailscaled && echo "✓ tailscaled: active" || echo "✗ tailscaled: inactive"
systemctl is-active tailscale-keepalive && echo "✓ keepalive: active" || echo "✗ keepalive: inactive"
echo
echo "SSH Access: ssh $(whoami)@$(tailscale ip -4)"
echo
echo "Monitoring:"
echo "  journalctl -u tailscale-keepalive -f"
echo "  tail -f /var/log/tailscale-keepalive.log"