#!/bin/bash

echo "🔄 Syncing all photos to Dropbox NOW"
echo "===================================="

# Sync all image files
echo "Syncing files from /srv/samba/camera-share to Dropbox..."
sudo -u camerabridge rclone copy /srv/samba/camera-share/ dropbox:Camera-Photos/ \
    --include "*.{jpg,jpeg,png,gif,bmp,JPG,JPEG,PNG,GIF,BMP}" \
    --progress \
    --verbose

echo ""
echo "✅ Sync complete!"
echo ""
echo "Checking Dropbox contents:"
sudo -u camerabridge rclone ls dropbox:Camera-Photos/ | head -10