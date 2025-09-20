#!/bin/bash

# Camera Bridge Service with OAuth2 Support
# Handles both legacy tokens and OAuth2 refresh tokens

LOG_FILE="/var/log/camera-bridge/service.log"
SMB_SHARE="/srv/samba/camera-share"
DROPBOX_DEST="dropbox:Camera-Photos"
PID_FILE="/var/run/camera-bridge.pid"
RCLONE_CONFIG="/home/camerabridge/.config/rclone/rclone.conf"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

check_oauth2_token() {
    # Check if we have OAuth2 with refresh token
    if [ -f "$RCLONE_CONFIG" ]; then
        if grep -q "refresh_token" "$RCLONE_CONFIG" 2>/dev/null; then
            log_message "INFO: OAuth2 refresh token detected - automatic renewal enabled"
            return 0
        else
            log_message "WARN: No refresh token found - using legacy token (may expire)"
            return 1
        fi
    else
        log_message "ERROR: No rclone configuration found"
        return 2
    fi
}

test_dropbox_connection() {
    log_message "Testing Dropbox connection..."

    if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        log_message "SUCCESS: Dropbox connection verified"

        # If OAuth2, test refresh mechanism
        if grep -q "refresh_token" "$RCLONE_CONFIG" 2>/dev/null; then
            # rclone automatically handles refresh - just log it
            log_message "INFO: OAuth2 token refresh handled automatically by rclone"
        fi
        return 0
    else
        log_message "ERROR: Cannot connect to Dropbox"

        # Check if it's a token issue
        local error_msg=$(sudo -u camerabridge rclone lsd dropbox: 2>&1)

        if [[ "$error_msg" == *"expired"* ]] || [[ "$error_msg" == *"invalid"* ]]; then
            log_message "ERROR: Token expired or invalid - reconfiguration needed"

            if ! grep -q "refresh_token" "$RCLONE_CONFIG" 2>/dev/null; then
                log_message "SOLUTION: Run setup-dropbox-oauth2.sh to configure OAuth2 with refresh token"
            fi
        fi
        return 1
    fi
}

sync_to_dropbox() {
    local file="$1"
    local filename=$(basename "$file")
    local relative_path="${file#$SMB_SHARE/}"

    log_message "Syncing: $relative_path"

    # Use rclone copy with automatic retry
    if sudo -u camerabridge rclone copy "$file" "$DROPBOX_DEST" \
        --retries 3 \
        --retries-sleep 5s \
        --low-level-retries 10 \
        --log-level ERROR 2>&1 | tee -a "$LOG_FILE"; then

        log_message "SUCCESS: Synced $filename to Dropbox"
        return 0
    else
        log_message "ERROR: Failed to sync $filename"

        # If OAuth2, rclone should handle refresh automatically
        # If it still fails, there's a different issue
        if ! test_dropbox_connection; then
            log_message "ERROR: Connection lost - will retry on next file"
        fi
        return 1
    fi
}

monitor_files() {
    log_message "Starting file monitor for $SMB_SHARE"

    if [ ! -d "$SMB_SHARE" ]; then
        log_message "ERROR: SMB share directory does not exist: $SMB_SHARE"
        return 1
    fi

    # Initial connection test
    if ! test_dropbox_connection; then
        log_message "WARNING: Starting without Dropbox connection - will retry"
    fi

    inotifywait -m -r -e create,moved_to "$SMB_SHARE" --format '%w%f %e' 2>/dev/null |
    while read file event; do
        # Only process image files
        if [[ "$file" =~ \.(jpg|jpeg|png|tiff|raw|dng|cr2|nef|orf|arw|JPG|JPEG|PNG|TIFF|RAW|DNG|CR2|NEF|ORF|ARW)$ ]]; then
            log_message "New file detected: $file"

            # Wait for file to be fully written
            sleep 3

            # Verify file is complete
            if ! lsof "$file" >/dev/null 2>&1; then
                sync_to_dropbox "$file"
            else
                log_message "File still being written: $file"
            fi
        fi
    done
}

periodic_sync() {
    while true; do
        sleep 3600  # Every hour

        log_message "Running periodic sync check..."

        # Test connection (OAuth2 refresh happens automatically)
        if test_dropbox_connection; then
            # Sync any files that might have been missed
            find "$SMB_SHARE" -type f \
                \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
                   -o -iname "*.raw" -o -iname "*.dng" -o -iname "*.cr2" \
                   -o -iname "*.nef" \) \
                -mmin -60 2>/dev/null | while read -r file; do

                # Check if file exists in Dropbox
                local filename=$(basename "$file")
                if ! sudo -u camerabridge rclone ls "$DROPBOX_DEST/$filename" >/dev/null 2>&1; then
                    log_message "Periodic sync: Found unsynced file: $filename"
                    sync_to_dropbox "$file"
                fi
            done
        else
            log_message "WARNING: Periodic sync skipped - no Dropbox connection"
        fi
    done
}

start_service() {
    log_message "Starting Camera Bridge Service with OAuth2 support..."

    # Check OAuth2 status
    check_oauth2_token

    # Test initial connection
    test_dropbox_connection

    # Start monitoring in background
    monitor_files &
    local monitor_pid=$!

    # Start periodic sync in background
    periodic_sync &
    local periodic_pid=$!

    # Save PIDs
    echo "$monitor_pid $periodic_pid" > "$PID_FILE"

    log_message "Service started with PIDs: Monitor=$monitor_pid, Periodic=$periodic_pid"

    # Wait for either process to exit
    wait $monitor_pid $periodic_pid
}

stop_service() {
    log_message "Stopping Camera Bridge Service..."

    if [ -f "$PID_FILE" ]; then
        read monitor_pid periodic_pid < "$PID_FILE"

        # Kill processes
        kill $monitor_pid $periodic_pid 2>/dev/null

        # Kill inotifywait
        pkill -f "inotifywait.*$SMB_SHARE" 2>/dev/null

        rm -f "$PID_FILE"
        log_message "Service stopped"
    else
        log_message "Service not running (no PID file)"
    fi
}

case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        start_service
        ;;
    status)
        if [ -f "$PID_FILE" ]; then
            read monitor_pid periodic_pid < "$PID_FILE"
            if ps -p $monitor_pid > /dev/null 2>&1; then
                echo "Camera Bridge Service is running (PIDs: $monitor_pid, $periodic_pid)"
                check_oauth2_token
                test_dropbox_connection
            else
                echo "Camera Bridge Service is not running (stale PID file)"
            fi
        else
            echo "Camera Bridge Service is not running"
        fi
        ;;
    test-connection)
        check_oauth2_token
        test_dropbox_connection
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|test-connection}"
        exit 1
        ;;
esac