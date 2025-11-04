#!/bin/bash

# Camera Bridge Monitor Service with Scanner Support
SMB_SHARE="/srv/samba/camera-share"
SCANNER_DIR="/srv/samba/camera-share/scans"
DROPBOX_PHOTOS="dropbox:Camera-Photos"
DROPBOX_SCANS="dropbox:Scanned-Documents"
LOG_FILE="/var/log/camera-bridge/monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "Camera Bridge Monitor starting (with scanner support)..."

# Check Dropbox config
if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
    log_message "ERROR: Dropbox not configured"
    exit 1
fi

# Test Dropbox connection
if rclone lsd dropbox: > /dev/null 2>&1; then
    log_message "Dropbox connection: OK"
else
    log_message "ERROR: Cannot connect to Dropbox"
    exit 1
fi

# Create Dropbox folders
rclone mkdir "$DROPBOX_PHOTOS" 2>/dev/null
rclone mkdir "$DROPBOX_SCANS" 2>/dev/null

# Initial sync for camera photos
log_message "Performing initial sync for camera photos..."
rclone copy "$SMB_SHARE" "$DROPBOX_PHOTOS" \
    --include "*.{jpg,jpeg,png,gif,bmp,JPG,JPEG,PNG,GIF,BMP}" \
    --verbose 2>&1 | while read line; do
        if [[ "$line" == *"Copied"* ]] || [[ "$line" == *"Transferred"* ]]; then
            log_message "$line"
        fi
    done

# Initial sync for scanner documents (if scanner dir exists)
if [ -d "$SCANNER_DIR" ]; then
    log_message "Performing initial sync for scanned documents..."
    rclone copy "$SCANNER_DIR" "$DROPBOX_SCANS" \
        --include "*.{jpg,jpeg,png,pdf,tiff,tif,JPG,JPEG,PNG,PDF,TIFF,TIF}" \
        --verbose 2>&1 | while read line; do
            if [[ "$line" == *"Copied"* ]] || [[ "$line" == *"Transferred"* ]]; then
                log_message "$line"
            fi
        done
fi

log_message "Monitoring for new files..."

# Build inotifywait command to monitor both directories
WATCH_DIRS="$SMB_SHARE"
if [ -d "$SCANNER_DIR" ]; then
    WATCH_DIRS="$WATCH_DIRS $SCANNER_DIR"
    log_message "Monitoring camera share and scanner directory"
else
    log_message "Monitoring camera share only (scanner dir not found)"
fi

# Monitor for changes in both directories
inotifywait -m -r -e create,modify,close_write,moved_to $WATCH_DIRS --format '%w%f|%e' |
while IFS='|' read filepath event; do
    # Skip recycle bin
    if [[ "$filepath" == *".recycle"* ]]; then
        continue
    fi

    # Determine destination based on source directory
    if [[ "$filepath" == "$SCANNER_DIR"* ]]; then
        # Scanner file - check for document formats
        if [[ "$filepath" =~ \.(jpg|jpeg|png|pdf|tiff|tif|JPG|JPEG|PNG|PDF|TIFF|TIF)$ ]]; then
            filename=$(basename "$filepath")
            log_message "[SCANNER] Detected: $filename (event: $event)"

            # Wait for file to stabilize
            sleep 3

            # Upload to Dropbox Scanned-Documents folder
            if rclone copy "$filepath" "$DROPBOX_SCANS/" --verbose 2>&1; then
                log_message "[SCANNER] ✓ Uploaded: $filename"
            else
                log_message "[SCANNER] ✗ Failed: $filename"
            fi
        fi
    else
        # Camera file - check for image formats
        if [[ "$filepath" =~ \.(jpg|jpeg|png|gif|bmp|JPG|JPEG|PNG|GIF|BMP)$ ]]; then
            filename=$(basename "$filepath")
            log_message "[CAMERA] Detected: $filename (event: $event)"

            # Wait for file to stabilize
            sleep 3

            # Upload to Dropbox Camera-Photos folder
            if rclone copy "$filepath" "$DROPBOX_PHOTOS/" --verbose 2>&1; then
                log_message "[CAMERA] ✓ Uploaded: $filename"
            else
                log_message "[CAMERA] ✗ Failed: $filename"
            fi
        fi
    fi
done
