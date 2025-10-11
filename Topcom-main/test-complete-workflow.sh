#!/bin/bash

# Complete Camera Bridge Workflow Test
echo "=== CAMERA BRIDGE COMPLETE WORKFLOW TEST ==="
echo ""

# Test 1: DHCP Server Configuration
echo "1. DHCP SERVER CONFIGURATION"
echo "================================"

if [ -f "/etc/dnsmasq.conf" ] && grep -q "192.168.4" /etc/dnsmasq.conf; then
    echo "   ✓ dnsmasq configured for WiFi AP (192.168.4.x range)"
else
    echo "   ✗ dnsmasq not configured for WiFi AP"
fi

if systemctl is-enabled dnsmasq >/dev/null 2>&1; then
    echo "   ✓ dnsmasq service enabled"
else
    echo "   ⚠ dnsmasq service not enabled"
fi

echo ""

# Test 2: Network Interface and IP Display
echo "2. NETWORK INTERFACE AND IP DISPLAY"
echo "===================================="

# Check WiFi interface detection
wifi_iface=$(ip link show | grep -E "wl|wlan" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
if [ -n "$wifi_iface" ]; then
    echo "   ✓ WiFi interface detected: $wifi_iface"

    # Check if connected to WiFi
    if current_ssid=$(iwgetid -r 2>/dev/null) && [ -n "$current_ssid" ]; then
        echo "   ✓ Connected to WiFi: $current_ssid"

        # Get IP address
        if ip_addr=$(ip addr show "$wifi_iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1); then
            echo "   ✓ WiFi IP address: $ip_addr"
        else
            echo "   ✗ No IP address assigned"
        fi
    else
        echo "   ⚠ Not connected to WiFi (will use AP mode)"
    fi
else
    echo "   ✗ No WiFi interface found"
fi

# Check ethernet interface
eth_iface=$(ip link show | grep -E "^[0-9]+: e" | awk -F': ' '{print $2}' | head -1)
if [ -n "$eth_iface" ]; then
    echo "   ✓ Ethernet interface: $eth_iface"
    eth_ip=$(ip addr show "$eth_iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
    if [ -n "$eth_ip" ]; then
        echo "   ✓ Ethernet IP: $eth_ip"
    else
        echo "   ⚠ Ethernet not connected"
    fi
fi

echo ""

# Test 3: SMB/Samba Configuration and Authentication
echo "3. SMB/SAMBA CONFIGURATION"
echo "=========================="

# Check SMB configuration file
if [ -f "/etc/samba/smb.conf" ]; then
    echo "   ✓ SMB configuration file exists"

    # Check for photos share
    if grep -q "\[photos\]" /etc/samba/smb.conf; then
        echo "   ✓ 'photos' share configured"

        # Check share path
        share_path=$(grep -A 10 "\[photos\]" /etc/samba/smb.conf | grep "path =" | awk '{print $3}')
        if [ -d "$share_path" ]; then
            echo "   ✓ Share directory exists: $share_path"
            echo "   ✓ Permissions: $(ls -ld $share_path | awk '{print $1}')"
        else
            echo "   ✗ Share directory missing: $share_path"
        fi

        # Check valid users
        if grep -A 10 "\[photos\]" /etc/samba/smb.conf | grep -q "valid users.*camera"; then
            echo "   ✓ SMB user 'camera' configured"
        else
            echo "   ✗ SMB user 'camera' not configured"
        fi
    else
        echo "   ✗ 'photos' share not found in smb.conf"
    fi
else
    echo "   ✗ SMB configuration file not found"
fi

# Check SMB services
if systemctl is-active --quiet smbd; then
    echo "   ✓ smbd service running"
else
    echo "   ✗ smbd service not running"
fi

if systemctl is-active --quiet nmbd; then
    echo "   ✓ nmbd service running"
else
    echo "   ✗ nmbd service not running"
fi

# Check SMB user exists
if pdbedit -L 2>/dev/null | grep -q "camera:"; then
    echo "   ✓ SMB user 'camera' exists"
    echo "   ℹ SMB Credentials: camera / camera123"
else
    echo "   ✗ SMB user 'camera' not found"
fi

# Test SMB connection
if command -v smbclient >/dev/null 2>&1; then
    if smbclient -L localhost -U camera%camera123 >/dev/null 2>&1; then
        echo "   ✓ SMB connection test successful"
    else
        echo "   ✗ SMB connection test failed"
    fi
else
    echo "   ⚠ smbclient not available for testing"
fi

echo ""

# Test 4: File Monitoring and rclone Sync Integration
echo "4. FILE MONITORING AND SYNC INTEGRATION"
echo "========================================"

# Check inotify-tools
if command -v inotifywait >/dev/null 2>&1; then
    echo "   ✓ inotifywait available for file monitoring"
else
    echo "   ✗ inotifywait not installed"
fi

# Check rclone
if command -v rclone >/dev/null 2>&1; then
    echo "   ✓ rclone available: $(rclone version | head -1)"
else
    echo "   ✗ rclone not installed"
fi

# Check camerabridge user
if id "camerabridge" >/dev/null 2>&1; then
    echo "   ✓ camerabridge user exists"

    # Check rclone config
    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        echo "   ✓ rclone configuration exists"

        if grep -q "\[dropbox\]" /home/camerabridge/.config/rclone/rclone.conf; then
            echo "   ✓ Dropbox configuration found"

            # Test Dropbox connection
            if timeout 15 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
                echo "   ✓ Dropbox connection successful"
            else
                echo "   ✗ Dropbox connection failed (may need valid token)"
            fi
        else
            echo "   ✗ No Dropbox configuration in rclone.conf"
        fi
    else
        echo "   ✗ rclone configuration not found"
    fi
else
    echo "   ✗ camerabridge user not found"
fi

# Check camera bridge service
if [ -f "/opt/camera-bridge/scripts/camera-bridge-service.sh" ]; then
    echo "   ✓ Camera bridge service script exists"
elif [ -f "$HOME/camera-bridge/scripts/camera-bridge-service.sh" ]; then
    echo "   ✓ Camera bridge service script exists (development)"
else
    echo "   ✗ Camera bridge service script not found"
fi

# Check systemd service
if systemctl list-unit-files | grep -q "camera-bridge.service"; then
    echo "   ✓ camera-bridge systemd service configured"

    if systemctl is-active --quiet camera-bridge; then
        echo "   ✓ camera-bridge service running"
    else
        echo "   ⚠ camera-bridge service not running"
    fi

    if systemctl is-enabled --quiet camera-bridge; then
        echo "   ✓ camera-bridge service enabled"
    else
        echo "   ⚠ camera-bridge service not enabled"
    fi
else
    echo "   ⚠ camera-bridge systemd service not installed"
fi

echo ""

# Test 5: Complete Workflow Summary
echo "5. COMPLETE WORKFLOW VALIDATION"
echo "================================"

echo ""
echo "WORKFLOW SUMMARY:"
echo "1. Laptop connects to Camera Bridge device (ethernet/WiFi)"

# Check if we can provide DHCP
if systemctl is-active --quiet dnsmasq 2>/dev/null && grep -q "192.168.4" /etc/dnsmasq.conf 2>/dev/null; then
    echo "   ✓ Device can provide DHCP (192.168.4.2-192.168.4.20)"
else
    echo "   ⚠ DHCP not active (check WiFi AP mode)"
fi

echo ""
echo "2. Laptop gets IP address and connects to SMB share"

# Get the server IP for SMB connection
server_ip=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ -n "$server_ip" ]; then
    echo "   ✓ Server IP available: $server_ip"
    echo "   ✓ SMB Share Path: //$server_ip/photos"
    echo "   ✓ SMB Credentials: camera / camera123"
else
    echo "   ✗ No server IP available"
fi

echo ""
echo "3. Files dropped into SMB share are monitored and synced"

# Check monitoring capability
if command -v inotifywait >/dev/null 2>&1 && [ -d "/srv/samba/camera-share" ]; then
    echo "   ✓ File monitoring ready (inotifywait + share directory)"
else
    echo "   ✗ File monitoring not ready"
fi

# Check sync capability
if command -v rclone >/dev/null 2>&1 && [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
    echo "   ✓ Sync capability ready (rclone + configuration)"

    if grep -q "\[dropbox\]" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
        echo "   ✓ Dropbox sync configured"
    else
        echo "   ⚠ Dropbox sync needs configuration"
    fi
else
    echo "   ✗ Sync capability not ready"
fi

echo ""
echo "=== WORKFLOW TEST COMPLETE ==="
echo ""

# Final summary
errors=0
warnings=0

# Count issues for summary
echo "FINAL ASSESSMENT:"

# Critical components check
if ! systemctl is-active --quiet smbd 2>/dev/null; then
    echo "❌ CRITICAL: SMB server not running"
    errors=$((errors + 1))
fi

if [ ! -d "/srv/samba/camera-share" ]; then
    echo "❌ CRITICAL: SMB share directory missing"
    errors=$((errors + 1))
fi

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "❌ CRITICAL: File monitoring not available"
    errors=$((errors + 1))
fi

if ! command -v rclone >/dev/null 2>&1; then
    echo "❌ CRITICAL: rclone not installed"
    errors=$((errors + 1))
fi

if [ ! -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
    echo "⚠️  WARNING: Dropbox not configured"
    warnings=$((warnings + 1))
fi

if ! systemctl is-active --quiet camera-bridge 2>/dev/null; then
    echo "⚠️  WARNING: Camera bridge service not running"
    warnings=$((warnings + 1))
fi

echo ""
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "🎉 WORKFLOW READY: All components operational!"
elif [ $errors -eq 0 ]; then
    echo "⚠️  MOSTLY READY: $warnings warning(s) - workflow should work"
else
    echo "❌ NOT READY: $errors critical error(s), $warnings warning(s)"
fi

echo ""
echo "To test the complete workflow:"
echo "1. Connect laptop to this device (ethernet or WiFi)"
echo "2. Get IP via DHCP or use static IP"
echo "3. Connect to SMB: //$server_ip/photos"
echo "4. Use credentials: camera / camera123"
echo "5. Drop photo files into the share"
echo "6. Check logs: tail -f /var/log/camera-bridge/service.log"