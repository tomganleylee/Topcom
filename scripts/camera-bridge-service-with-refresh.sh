#!/bin/bash

# Enhanced Camera Bridge Service Script with Token Refresh
# Monitors SMB share for photos and syncs to Dropbox with automatic token refresh

# Configuration
LOG_FILE="/var/log/camera-bridge/service.log"
SMB_SHARE="/srv/samba/camera-share"
DROPBOX_DEST="dropbox:Camera-Photos"
PID_FILE="/var/run/camera-bridge.pid"
QUEUE_FILE="/var/log/camera-bridge/sync-queue"
TOKEN_MANAGER="/opt/camera-bridge/scripts/dropbox-token-manager.sh"

# Fallback to local script if not installed
if [ ! -x "$TOKEN_MANAGER" ]; then
    TOKEN_MANAGER="$(dirname "$0")/dropbox-token-manager.sh"
fi

# Token refresh settings
LAST_TOKEN_REFRESH=0
TOKEN_REFRESH_INTERVAL=$((3 * 3600))  # 3 hours

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "$(dirname "$QUEUE_FILE")" 2>/dev/null

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR: This service must be run as root"
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    ping -c 1 -W 2 api.dropboxapi.com >/dev/null 2>&1 || \
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1
}

# Refresh Dropbox token if needed
refresh_token_if_needed() {
    local current_time=$(date +%s)
    local time_since_refresh=$((current_time - LAST_TOKEN_REFRESH))

    # Check if token manager exists
    if [ ! -x "$TOKEN_MANAGER" ]; then
        log_message "WARN: Token manager not found, skipping refresh"
        return 1
    fi

    # Refresh on startup or every 3 hours
    if [ $LAST_TOKEN_REFRESH -eq 0 ] || [ $time_since_refresh -ge $TOKEN_REFRESH_INTERVAL ]; then
        log_message "INFO: Checking Dropbox token status..."

        # Run token refresh
        if "$TOKEN_MANAGER" auto >> "$LOG_FILE" 2>&1; then
            LAST_TOKEN_REFRESH=$current_time
            log_message "INFO: Token refresh check completed successfully"
            return 0
        else
            log_message "ERROR: Token refresh failed - sync may not work"
            return 1
        fi
    fi

    return 0
}

# Process queued files when coming back online
process_queue() {
    if [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ]; then
        return 0
    fi

    log_message "INFO: Processing queued files..."

    # First, refresh token since we may have been offline
    refresh_token_if_needed

    local processed=0
    local failed=0

    # Process each queued file
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if sync_to_dropbox "$file"; then
                ((processed++))
            else
                ((failed++))
                # Re-queue failed files
                echo "$file" >> "${QUEUE_FILE}.tmp"
            fi
        fi
    done < "$QUEUE_FILE"

    # Replace queue with failed items
    if [ -f "${QUEUE_FILE}.tmp" ]; then
        mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
    else
        > "$QUEUE_FILE"  # Clear queue
    fi

    log_message "INFO: Queue processing complete. Processed: $processed, Failed: $failed"
}

# Sync file to Dropbox
sync_to_dropbox() {
    local file="$1"
    local relative_path="${file#$SMB_SHARE/}"
    local dest_dir="$DROPBOX_DEST/$(dirname "$relative_path")"

    log_message "INFO: Syncing $relative_path to Dropbox..."

    # Create destination directory if needed
    if ! sudo -u camerabridge rclone mkdir "$dest_dir" 2>/dev/null; then
        log_message "WARN: Could not create directory $dest_dir"
    fi

    # Copy file to Dropbox
    if sudo -u camerabridge rclone copy "$file" "$dest_dir" \
        --timeout 30s \
        --low-level-retries 3 \
        --retries 3 \
        --stats 0 2>&1 | tee -a "$LOG_FILE"; then
        log_message "SUCCESS: $relative_path synced to Dropbox"
        return 0
    else
        log_message "ERROR: Failed to sync $relative_path"

        # Check if it's a token issue
        if ! "$TOKEN_MANAGER" validate >/dev/null 2>&1; then
            log_message "ERROR: Token validation failed, attempting refresh..."
            LAST_TOKEN_REFRESH=0  # Force refresh
            refresh_token_if_needed
        fi

        return 1
    fi
}

# Monitor SMB share for new files
monitor_files() {
    log_message "Starting file monitor for $SMB_SHARE"

    # Ensure directory exists
    if [ ! -d "$SMB_SHARE" ]; then
        log_message "ERROR: SMB share directory does not exist: $SMB_SHARE"
        return 1
    fi

    # Main monitoring loop
    inotifywait -m -r -e create,moved_to "$SMB_SHARE" --format '%w%f %e' 2>/dev/null |
    while read file event; do
        # Only process image and PDF files
        if [[ "$file" =~ \.(jpg|jpeg|png|tiff|raw|dng|cr2|nef|orf|arw|pdf|JPG|JPEG|PNG|TIFF|RAW|DNG|CR2|NEF|ORF|ARW|PDF)$ ]]; then
            log_message "New file detected: $file (event: $event)"

            # Wait for file to be fully written
            sleep 3

            # Verify file is complete
            if ! lsof "$file" >/dev/null 2>&1; then
                # Check token refresh interval
                refresh_token_if_needed

                # Sync to Dropbox if connected
                if check_internet; then
                    # Process any queued files first
                    if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
                        log_message "INFO: Processing queue before new file..."
                        process_queue
                    fi

                    # Sync the new file
                    sync_to_dropbox "$file"
                else
                    log_message "No internet connection, file queued: $file"
                    echo "$file" >> "$QUEUE_FILE"
                fi
            else
                log_message "File still being written: $file"
            fi
        fi
    done
}

# Handle periodic tasks
periodic_tasks() {
    while true; do
        sleep 300  # Check every 5 minutes

        # Refresh token if needed
        refresh_token_if_needed

        # Process queue if online
        if check_internet && [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
            log_message "INFO: Internet available, processing queue..."
            process_queue
        fi

        # Clean up old logs (keep last 7 days)
        find "$(dirname "$LOG_FILE")" -name "*.log" -mtime +7 -delete 2>/dev/null
    done
}

# Service control functions
start_service() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        log_message "Service already running with PID $(cat "$PID_FILE")"
        exit 1
    fi

    log_message "Starting Camera Bridge Service with token refresh..."

    # Initial token refresh on startup
    log_message "INFO: Performing startup token refresh check..."
    refresh_token_if_needed

    # Start monitoring in background
    monitor_files &
    MONITOR_PID=$!

    # Start periodic tasks in background
    periodic_tasks &
    PERIODIC_PID=$!

    # Save PIDs
    echo "$MONITOR_PID $PERIODIC_PID" > "$PID_FILE"

    log_message "Service started with PIDs: Monitor=$MONITOR_PID, Periodic=$PERIODIC_PID"

    # Wait for either process to exit
    wait $MONITOR_PID $PERIODIC_PID
}

stop_service() {
    if [ ! -f "$PID_FILE" ]; then
        log_message "Service not running (no PID file)"
        exit 0
    fi

    log_message "Stopping Camera Bridge Service..."

    # Kill all PIDs
    for pid in $(cat "$PID_FILE"); do
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            log_message "Stopped process $pid"
        fi
    done

    # Kill any inotifywait processes
    pkill -f "inotifywait.*$SMB_SHARE" 2>/dev/null

    rm -f "$PID_FILE"
    log_message "Service stopped"
}

status_service() {
    echo "Camera Bridge Service Status"
    echo "============================"

    if [ -f "$PID_FILE" ]; then
        local running=true
        for pid in $(cat "$PID_FILE"); do
            if ! kill -0 $pid 2>/dev/null; then
                running=false
                break
            fi
        done

        if $running; then
            echo "Status: RUNNING"
            echo "PIDs: $(cat "$PID_FILE")"
        else
            echo "Status: STOPPED (stale PID file)"
        fi
    else
        echo "Status: STOPPED"
    fi

    # Check token status
    if [ -x "$TOKEN_MANAGER" ]; then
        echo ""
        echo "Token Status:"
        "$TOKEN_MANAGER" status 2>/dev/null | tail -n +2
    fi

    # Check queue
    if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
        echo ""
        echo "Queued files: $(wc -l < "$QUEUE_FILE")"
    fi

    # Recent activity
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Recent activity:"
        tail -5 "$LOG_FILE"
    fi
}

# Main script logic
check_root

case "${1:-start}" in
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
        status_service
        ;;
    test-dropbox)
        log_message "Testing Dropbox connection and token..."
        if "$TOKEN_MANAGER" validate; then
            echo "✓ Dropbox connection successful"
            exit 0
        else
            echo "✗ Dropbox connection failed"
            exit 1
        fi
        ;;
    refresh-token)
        log_message "Manual token refresh requested"
        "$TOKEN_MANAGER" refresh
        exit $?
        ;;
    sync-now)
        log_message "Manual sync triggered"
        if check_internet; then
            process_queue
            find "$SMB_SHARE" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -mmin -1440 |
            while read file; do
                sync_to_dropbox "$file"
            done
        else
            echo "No internet connection"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|test-dropbox|refresh-token|sync-now}"
        exit 1
        ;;
esac