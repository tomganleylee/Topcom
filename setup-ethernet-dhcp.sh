#!/bin/bash

echo "📡 Setting up Ethernet DHCP Server for Camera Bridge"
echo "===================================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Ethernet interface
ETH_INTERFACE="eno1"

echo "1. Bringing up ethernet interface..."
ip link set $ETH_INTERFACE up

echo "2. Assigning static IP to ethernet..."
ip addr flush dev $ETH_INTERFACE
ip addr add 192.168.10.1/24 dev $ETH_INTERFACE

echo "3. Configuring dnsmasq for ethernet DHCP..."
# Add ethernet DHCP configuration
cat >> /etc/dnsmasq.conf << 'EOF'

# Camera Bridge Ethernet DHCP
interface=eno1
bind-interfaces
dhcp-range=192.168.10.10,192.168.10.50,255.255.255.0,24h
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF

echo "4. Restarting dnsmasq..."
systemctl restart dnsmasq

echo "5. Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
# Make it permanent
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo "6. Setting up NAT (so laptop can access internet)..."
iptables -t nat -A POSTROUTING -o wlp1s0 -j MASQUERADE
iptables -A FORWARD -i $ETH_INTERFACE -o wlp1s0 -j ACCEPT
iptables -A FORWARD -i wlp1s0 -o $ETH_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

echo "7. Checking status..."
echo ""
echo "Ethernet Interface Status:"
ip addr show $ETH_INTERFACE | grep inet
echo ""
echo "DHCP Server Status:"
systemctl is-active dnsmasq && echo "✓ DHCP server running" || echo "✗ DHCP server failed"
echo ""
echo "✅ ETHERNET DHCP SETUP COMPLETE!"
echo ""
echo "Your laptop should now:"
echo "1. Get IP address: 192.168.10.x"
echo "2. Access Camera Bridge SMB: \\\\192.168.10.1\\photos"
echo "3. Have internet access through this machine"
echo ""
echo "SMB Credentials: camera / camera123"