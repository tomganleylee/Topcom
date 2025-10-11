#!/bin/bash

# Tailscale SSH-Only Configuration Script
# Run this after installing Tailscale to set it up for SSH access only

echo "=== Tailscale SSH-Only Configuration ==="
echo

# Function to check if Tailscale is installed
check_tailscale() {
    if ! command -v tailscale &> /dev/null; then
        echo "Error: Tailscale is not installed. Please run install-tailscale-safe.sh first."
        exit 1
    fi
}

# Function to check current network state
show_network_before() {
    echo "Current network configuration (before Tailscale):"
    echo "================================================"
    ip -br addr show | grep -v "^lo"
    echo
    echo "Current routes:"
    ip route | head -5
    echo
}

# Main configuration
main() {
    check_tailscale

    echo "This script will configure Tailscale for SSH-only access"
    echo "Your existing network configuration will NOT be modified"
    echo

    show_network_before

    echo "Starting Tailscale with safe options..."
    echo "Running: tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh"
    echo
    echo "IMPORTANT: You'll be prompted to authenticate via a URL"
    echo "After authentication, Tailscale will:"
    echo "  1. Create a new interface (tailscale0) with IP 100.x.x.x"
    echo "  2. NOT modify your existing routes or DNS"
    echo "  3. Enable SSH access through the Tailscale network only"
    echo

    # Start Tailscale with safe options
    if [ "$EUID" -eq 0 ]; then
        tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh
    else
        sudo tailscale up --accept-routes=false --accept-dns=false --advertise-routes= --ssh
    fi

    echo
    echo "=== Configuration Complete ==="
    echo

    # Show the Tailscale IP
    echo "Your Tailscale IP address:"
    tailscale ip -4
    echo

    echo "Your Tailscale hostname:"
    hostname=$(tailscale status --json | grep -o '"Self":{[^}]*"HostName":"[^"]*"' | sed 's/.*"HostName":"\([^"]*\)".*/\1/')
    echo "  $hostname"
    echo

    echo "You can now SSH to this machine using:"
    echo "  ssh $(whoami)@$(tailscale ip -4)"
    echo "  or"
    echo "  ssh $(whoami)@$hostname"
    echo
    echo "From any device on your Tailscale network"
    echo

    # Verify network hasn't been affected
    echo "Verifying your original network is unchanged:"
    echo "============================================="
    ip -br addr show | grep -v "^lo" | grep -v "^tailscale"
    echo
    echo "Main routes (should be unchanged):"
    ip route | grep -v "100\."
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0"
    echo "  Configure Tailscale for SSH-only access without affecting existing network"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  status         Show Tailscale status"
    echo "  down           Safely disconnect Tailscale"
    exit 0
fi

# Handle commands
case "$1" in
    status)
        tailscale status
        echo
        echo "Network interfaces:"
        ip -br addr show
        ;;
    down)
        echo "Disconnecting Tailscale..."
        if [ "$EUID" -eq 0 ]; then
            tailscale down
        else
            sudo tailscale down
        fi
        echo "Tailscale disconnected. Your original network is unaffected."
        ;;
    *)
        main
        ;;
esac