#!/bin/bash

# Tailscale Safe Installation Script
# This script installs Tailscale with minimal network impact

set -e

echo "=== Tailscale Safe Installation Script ==="
echo "This script will install Tailscale without affecting your existing network configuration"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo: sudo ./install-tailscale-safe.sh"
    exit 1
fi

# Step 1: Add Tailscale's package signing key and repository
echo "Step 1: Adding Tailscale repository..."
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

# Step 2: Install Tailscale
echo "Step 2: Installing Tailscale package..."
apt-get update
apt-get install -y tailscale

# Step 3: Configure Tailscale to not interfere with existing routes
echo "Step 3: Configuring Tailscale for minimal network impact..."

# Create a configuration file for Tailscale with safe defaults
cat > /etc/default/tailscaled << EOF
# Tailscale daemon configuration
# These settings ensure Tailscale doesn't interfere with existing network

# Disable subnet routing by default
FLAGS=""

# Optional: You can add flags here if needed
# FLAGS="--no-logs-no-support"
EOF

echo
echo "=== Installation Complete ==="
echo
echo "Next steps to connect Tailscale (run these manually):"
echo
echo "1. Start Tailscale with specific options to avoid network conflicts:"
echo "   sudo tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh"
echo
echo "   Options explained:"
echo "   --accept-routes=false  : Don't accept subnet routes from other nodes"
echo "   --accept-dns=false     : Don't override system DNS settings"
echo "   --advertise-routes=    : Don't advertise any local routes"
echo "   --ssh                  : Enable Tailscale SSH"
echo
echo "2. After authentication, you can check your Tailscale IP:"
echo "   tailscale ip -4"
echo
echo "3. To enable SSH access through Tailscale only:"
echo "   sudo tailscale set --ssh"
echo
echo "4. Your SSH access will be available at:"
echo "   ssh user@[tailscale-hostname]"
echo "   or"
echo "   ssh user@[tailscale-ip]"
echo
echo "=== Important Notes ==="
echo "- Tailscale creates a separate network interface (tailscale0)"
echo "- It uses 100.x.x.x IP range which shouldn't conflict with your 192.168.x.x networks"
echo "- Your existing routes on eno1 (192.168.10.0/24) and wlp1s0 (192.168.3.0/24) remain untouched"
echo "- SSH through Tailscale uses Tailscale's authentication, no SSH keys needed initially"
echo
echo "To check Tailscale status without affecting network:"
echo "   tailscale status"
echo
echo "To stop Tailscale if needed:"
echo "   sudo tailscale down"
echo "   sudo systemctl stop tailscaled"