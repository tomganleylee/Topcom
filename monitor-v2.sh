#!/bin/bash

# Enhanced Camera Bridge Monitor with better detection

SMB_SHARE="/srv/samba/camera-share"
DROPBOX_DEST="dropbox:Camera-Photos"
LOG_FILE="/var/log/camera-bridge/monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "Camera Bridge Monitor V2 starting..."

# Initial sync
log_message "Performing initial sync of existing files..."
rclone copy "$SMB_SHARE" "$DROPBOX_DEST" \
    --include "*.{jpg,jpeg,png,gif,bmp,JPG,JPEG,PNG,GIF,BMP}" \
    --verbose 2>&1 | while read line; do
        if [[ "$line" == *"Copied"* ]] || [[ "$line" == *"Transferred"* ]]; then
            log_message "$line"
        fi
    done

log_message "Initial sync done. Monitoring for changes..."

# Monitor with broader event detection
inotifywait -m -r -e create,modify,close_write,moved_to "$SMB_SHARE" --format '%w%f|%e' |
while IFS='|' read filepath event; do
    # Skip recycle bin
    if [[ "$filepath" == *".recycle"* ]]; then
        continue
    fi

    # Check if it's an image
    if [[ "$filepath" =~ \.(jpg|jpeg|png|gif|bmp|JPG|JPEG|PNG|GIF|BMP)$ ]]; then
        filename=$(basename "$filepath")
        log_message "Detected: $filename (event: $event)"

        # Wait for file to stabilize
        sleep 3

        # Upload to Dropbox
        log_message "Uploading $filename to Dropbox..."
        if rclone copy "$filepath" "$DROPBOX_DEST/" --verbose 2>&1; then
            log_message "✓ Successfully uploaded: $filename"
        else
            log_message "✗ Failed to upload: $filename"
        fi
    fi
done