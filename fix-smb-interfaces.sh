#!/bin/bash

# Fix SMB interface configuration

echo "Fixing SMB interface configuration..."

# Get actual network interfaces
INTERFACES="lo"
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$"); do
    if ip addr show $iface | grep -q "inet "; then
        INTERFACES="$INTERFACES $iface"
    fi
done

# Also add network ranges
if ip addr show | grep -q "192.168."; then
    INTERFACES="$INTERFACES 192.168.0.0/16"
fi

echo "Detected interfaces: $INTERFACES"

# Create fixed smb.conf
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d-%H%M%S)
sudo sed -i "s/interfaces = .*/interfaces = $INTERFACES/" /etc/samba/smb.conf

echo "Updated SMB configuration with correct interfaces"

# Kill stuck nmbd if exists
echo "Stopping stuck nmbd process..."
sudo systemctl stop nmbd
sudo pkill -9 nmbd 2>/dev/null || true

# Restart SMB services
echo "Restarting SMB services..."
sudo systemctl restart smbd
sudo systemctl restart nmbd

# Check status
sleep 2
if systemctl is-active --quiet nmbd; then
    echo "✓ nmbd is now running"
else
    echo "✗ nmbd failed to start. Trying without interface binding..."
    # Comment out interface binding as fallback
    sudo sed -i 's/^   bind interfaces only = yes/   # bind interfaces only = yes/' /etc/samba/smb.conf
    sudo systemctl restart nmbd
    sleep 2
    if systemctl is-active --quiet nmbd; then
        echo "✓ nmbd is now running (without interface binding)"
    else
        echo "✗ nmbd still not running. Check: sudo journalctl -u nmbd"
    fi
fi

echo ""
echo "SMB services status:"
systemctl is-active smbd && echo "✓ smbd: running" || echo "✗ smbd: not running"
systemctl is-active nmbd && echo "✓ nmbd: running" || echo "✗ nmbd: not running"