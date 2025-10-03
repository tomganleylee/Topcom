#!/bin/bash

# Simple Camera Bridge Monitor Script
# Watches for new photos and syncs to Dropbox

LOG_FILE="/var/log/camera-bridge/simple-sync.log"
SMB_SHARE="/srv/samba/camera-share"
DROPBOX_DEST="dropbox:Camera-Photos"

# Create log directory if needed
mkdir -p /var/log/camera-bridge

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "Camera Bridge Simple Monitor starting..."

# Check if Dropbox is configured
if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
    log_message "ERROR: Dropbox not configured at $HOME/.config/rclone/rclone.conf"
    exit 1
fi

# Test Dropbox connection
if rclone lsd dropbox: > /dev/null 2>&1; then
    log_message "Dropbox connection: OK"
else
    log_message "ERROR: Cannot connect to Dropbox"
    exit 1
fi

# Create Dropbox folder if needed
rclone mkdir "$DROPBOX_DEST" 2>/dev/null

# Initial sync of existing files
log_message "Performing initial sync..."
rclone copy "$SMB_SHARE" "$DROPBOX_DEST" \
    --include "*.{jpg,jpeg,png,gif,bmp,tiff,raw,cr2,nef,arw,dng,JPG,JPEG,PNG,GIF,BMP,TIFF,RAW,CR2,NEF,ARW,DNG}" \
    --no-traverse \
    2>&1 | while read line; do
        if [[ "$line" == *"Transferred:"* ]]; then
            log_message "Initial sync: $line"
        fi
    done

log_message "Initial sync complete. Starting file monitor..."

# Monitor for new files
inotifywait -m -r -e create,moved_to,close_write "$SMB_SHARE" --format '%w%f %e' 2>/dev/null |
while read filepath event; do
    # Extract just the file path (remove event)
    file="${filepath% *}"

    # Check if it's an image file
    if [[ "$file" =~ \.(jpg|jpeg|png|gif|bmp|tiff|raw|cr2|nef|arw|dng|JPG|JPEG|PNG|GIF|BMP|TIFF|RAW|CR2|NEF|ARW|DNG)$ ]]; then
        log_message "New photo detected: $(basename "$file")"

        # Wait a moment for file to be fully written
        sleep 2

        # Sync to Dropbox
        if rclone copy "$file" "$DROPBOX_DEST" 2>&1; then
            log_message "Successfully synced: $(basename "$file") to Dropbox"
        else
            log_message "ERROR: Failed to sync $(basename "$file")"
        fi
    fi
done