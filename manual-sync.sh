#!/bin/bash

echo "📸 Manual Camera Bridge Sync"
echo "============================"

# Check if rclone config exists
if [ ! -f /home/camerabridge/.config/rclone/rclone.conf ]; then
    echo "❌ Dropbox not configured!"
    echo "Run: sudo ./setup-dropbox-token.sh"
    exit 1
fi

echo "✓ Dropbox configuration found"

# Test Dropbox connection
echo "Testing Dropbox connection..."
if sudo -u camerabridge rclone lsd dropbox: > /dev/null 2>&1; then
    echo "✓ Dropbox connection successful"
else
    echo "❌ Cannot connect to Dropbox"
    exit 1
fi

# Create Dropbox folder if needed
echo "Creating Camera-Photos folder on Dropbox..."
sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null

# List files in SMB share
echo ""
echo "Files in SMB share (/srv/samba/camera-share):"
ls -la /srv/samba/camera-share/

# Sync files to Dropbox
echo ""
echo "Syncing files to Dropbox..."
sudo -u camerabridge rclone copy /srv/samba/camera-share/ dropbox:Camera-Photos/ \
    --include "*.{jpg,jpeg,png,JPG,JPEG,PNG,raw,RAW,cr2,CR2,nef,NEF}" \
    --progress \
    --transfers 1

echo ""
echo "✅ Sync complete!"
echo ""
echo "Check your Dropbox Camera-Photos folder for the uploaded files."

# Optional: Start monitoring for new files
echo ""
echo "To monitor for new files continuously, run:"
echo "  sudo inotifywait -m -r -e create,moved_to /srv/samba/camera-share --format '%w%f' |"
echo "  while read file; do"
echo "    sudo -u camerabridge rclone copy \"\$file\" dropbox:Camera-Photos/"
echo "  done"