#!/bin/bash

echo "🔧 Fixing Ethernet DHCP Configuration"
echo "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# 1. Clean up dnsmasq config
echo "1. Cleaning up dnsmasq configuration..."
# Remove duplicate entries
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup.$(date +%Y%m%d-%H%M%S)
# Remove any duplicate camera-bridge entries
sed -i '/Camera Bridge Ethernet DHCP/,+5d' /etc/dnsmasq.conf
sed -i '/Camera Bridge AP Configuration/,+2d' /etc/dnsmasq.conf

# 2. Create clean dnsmasq config for both interfaces
echo "2. Creating clean dnsmasq configuration..."
cat > /etc/dnsmasq.d/camera-bridge.conf << 'EOF'
# Camera Bridge DHCP Configuration

# Ethernet interface
interface=eno1
dhcp-range=interface:eno1,192.168.10.10,192.168.10.50,255.255.255.0,24h

# WiFi AP interface (if needed later)
#interface=wlp1s0
#dhcp-range=interface:wlp1s0,192.168.4.2,192.168.4.20,255.255.255.0,24h

# General options
bind-dynamic
except-interface=lo
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF

# 3. Ensure ethernet has IP
echo "3. Setting ethernet IP..."
ip addr flush dev eno1
ip addr add 192.168.10.1/24 dev eno1
ip link set eno1 up

# 4. Create iptables directory if needed
echo "4. Setting up NAT/firewall..."
mkdir -p /etc/iptables

# Clear existing NAT rules and add new ones
iptables -t nat -F
iptables -t nat -A POSTROUTING -o wlp1s0 -j MASQUERADE
iptables -A FORWARD -i eno1 -o wlp1s0 -j ACCEPT
iptables -A FORWARD -i wlp1s0 -o eno1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save rules
if command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

# 5. Enable IP forwarding
echo "5. Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# 6. Restart dnsmasq
echo "6. Restarting dnsmasq..."
systemctl restart dnsmasq

# 7. Check status
echo ""
echo "========================================"
echo "Status Check:"
echo ""

# Check ethernet
echo "Ethernet Interface (eno1):"
ip addr show eno1 | grep inet | grep -v inet6 | awk '{print "  IP: " $2}'
ip link show eno1 | grep -q "state UP" && echo "  Status: UP ✓" || echo "  Status: DOWN ✗"

echo ""
echo "DHCP Server:"
if systemctl is-active --quiet dnsmasq; then
    echo "  Status: Running ✓"
    echo "  DHCP Range: 192.168.10.10-50"
else
    echo "  Status: Failed ✗"
    echo "  Check: sudo journalctl -u dnsmasq -n 20"
fi

echo ""
echo "IP Forwarding:"
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
    echo "  Status: Enabled ✓"
else
    echo "  Status: Disabled ✗"
fi

echo ""
echo "========================================"
echo "🎯 NEXT STEPS:"
echo ""
echo "1. Unplug and replug your laptop's ethernet cable"
echo "2. Your laptop should get IP: 192.168.10.x"
echo "3. Access SMB share: \\\\192.168.10.1\\photos"
echo "   Credentials: camera / camera123"
echo ""
echo "If DHCP still fails, you can set static IP on laptop:"
echo "  IP: 192.168.10.20"
echo "  Netmask: 255.255.255.0"
echo "  Gateway: 192.168.10.1"
echo "  DNS: 8.8.8.8"