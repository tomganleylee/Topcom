#!/bin/bash

# Test script for Dropbox functionality
echo "=== Testing Dropbox Functionality ==="

# Test 1: Check rclone availability
echo "1. rclone availability:"
if command -v rclone >/dev/null 2>&1; then
    echo "   ✓ rclone found: $(rclone version | head -1)"
else
    echo "   ✗ rclone not found"
fi

# Test 2: Check camerabridge user
echo "2. camerabridge user:"
if id "camerabridge" >/dev/null 2>&1; then
    echo "   ✓ camerabridge user exists"
    echo "   Home: $(getent passwd camerabridge | cut -d: -f6)"
else
    echo "   ✗ camerabridge user not found"
fi

# Test 3: Check config directory
echo "3. Configuration directory:"
config_dir="/home/camerabridge/.config/rclone"
if [ -d "$config_dir" ]; then
    echo "   ✓ Config directory exists: $config_dir"
    echo "   Permissions: $(ls -ld $config_dir 2>/dev/null | awk '{print $1}')"
else
    echo "   ✗ Config directory not found: $config_dir"
fi

# Test 4: Check existing config
echo "4. Dropbox configuration:"
config_file="$config_dir/rclone.conf"
if [ -f "$config_file" ]; then
    echo "   ✓ Config file exists: $config_file"
    echo "   Permissions: $(ls -la $config_file 2>/dev/null | awk '{print $1}')"
    if grep -q "\[dropbox\]" "$config_file" 2>/dev/null; then
        echo "   ✓ Dropbox section found in config"
    else
        echo "   ✗ No dropbox section in config"
    fi
else
    echo "   ✗ Config file not found: $config_file"
fi

# Test 5: Test connection (if configured)
echo "5. Connection test:"
if [ -f "$config_file" ] && grep -q "\[dropbox\]" "$config_file" 2>/dev/null; then
    echo "   Testing connection..."
    if timeout 15 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        echo "   ✓ Connection successful"
    else
        echo "   ✗ Connection failed (may need valid token)"
    fi
else
    echo "   - Skipped (no configuration)"
fi

# Test 6: Dialog availability
echo "6. Dialog tool:"
if command -v dialog >/dev/null 2>&1; then
    echo "   ✓ dialog available"
else
    echo "   ✗ dialog not available"
fi

# Test 7: Camera share directory
echo "7. Camera share directory:"
share_dir="/srv/samba/camera-share"
if [ -d "$share_dir" ]; then
    echo "   ✓ Share directory exists: $share_dir"
    echo "   Files: $(find $share_dir -type f 2>/dev/null | wc -l) files"
else
    echo "   ✗ Share directory not found: $share_dir"
fi

echo ""
echo "=== Test Summary ==="
echo "The Dropbox functionality is ready for configuration."
echo "Use the terminal UI to:"
echo "• Configure Dropbox Token"
echo "• Test Dropbox Connection"
echo "• View Sync Logs"
echo "• Manage Settings"