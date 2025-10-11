#!/bin/bash

echo "🔧 Fixing SMB Network Binding"
echo "=============================="

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

echo "1. Backing up SMB configuration..."
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d-%H%M%S)

echo "2. Updating SMB to listen on all interfaces..."
# Comment out the restrictive interface binding
sed -i 's/^   interfaces = .*/#   interfaces = lo eno1 wlp1s0/' /etc/samba/smb.conf
sed -i 's/^   bind interfaces only = yes/#   bind interfaces only = yes/' /etc/samba/smb.conf

# Or update to include all interfaces
# sed -i 's/interfaces = .*/interfaces = lo eno1 wlp1s0 192.168.10.0\/24 192.168.3.0\/24/' /etc/samba/smb.conf

echo "3. Testing configuration..."
testparm -s /etc/samba/smb.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Configuration valid"
else
    echo "   ✗ Configuration has errors"
    testparm -s /etc/samba/smb.conf 2>&1 | head -20
fi

echo "4. Restarting SMB service..."
systemctl restart smbd

echo "5. Waiting for service to start..."
sleep 3

echo ""
echo "========================================"
echo "SMB Status Check:"
echo ""

# Check what SMB is listening on
echo "SMB Listening Ports:"
netstat -tuln | grep -E ":445|:139" | while read line; do
    echo "  $line"
done

echo ""
echo "SMB Service Status:"
if systemctl is-active --quiet smbd; then
    echo "  ✓ SMB service running"
else
    echo "  ✗ SMB service not running"
fi

echo ""
echo "Test from Camera Bridge machine:"
echo "  smbclient -L 192.168.10.1 -U camera%camera123"
echo ""
echo "========================================"
echo "✅ SMB BINDING FIXED!"
echo ""
echo "Your laptop can now access:"
echo "  \\\\192.168.10.1\\photos"
echo "  Username: camera"
echo "  Password: camera123"
echo ""
echo "Also accessible via WiFi IP:"
echo "  \\\\192.168.3.37\\photos"