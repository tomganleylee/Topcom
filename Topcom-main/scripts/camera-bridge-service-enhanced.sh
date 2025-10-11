#!/bin/bash

# Enhanced Camera Bridge Service Script
# Supports both SMB network sharing and USB gadget modes
# Monitors for new photos and syncs them to Dropbox

# Configuration files
CONFIG_FILE="/opt/camera-bridge/config/camera-bridge.conf"
USB_GADGET_CONFIG="/opt/camera-bridge/config/usb-gadget.conf"

# Default configuration
LOG_FILE="/var/log/camera-bridge/service.log"
SMB_SHARE="/srv/samba/camera-share"
USB_MOUNT="/mnt/camera-bridge-usb"
DROPBOX_DEST="dropbox:Camera-Photos"
PID_FILE="/var/run/camera-bridge.pid"

# Operation mode: "smb" or "usb-gadget"
OPERATION_MODE="smb"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "Loaded configuration from $CONFIG_FILE"
    fi

    # Detect operation mode
    if [ -f "/proc/device-tree/model" ] && grep -q "Pi Zero 2" /proc/device-tree/model 2>/dev/null; then
        # Check if USB gadget is configured
        if [ -d "/sys/kernel/config/usb_gadget/camera_bridge_storage" ]; then
            OPERATION_MODE="usb-gadget"
            MONITOR_PATH="$USB_MOUNT"
        else
            OPERATION_MODE="smb"
            MONITOR_PATH="$SMB_SHARE"
        fi
    else
        OPERATION_MODE="smb"
        MONITOR_PATH="$SMB_SHARE"
    fi

    log_message "Operation mode: $OPERATION_MODE"
    log_message "Monitor path: $MONITOR_PATH"
}

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

# Detect Pi Zero 2 W and USB gadget capability
detect_hardware() {
    if [ -f "/proc/device-tree/model" ]; then
        local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
        log_message "Detected hardware: $model"

        if echo "$model" | grep -q "Pi Zero 2"; then
            log_message "Pi Zero 2 W detected - USB gadget mode available"
            return 0
        fi
    fi
    return 1
}

# Monitor files based on operation mode
monitor_files() {
    log_message "Starting file monitor for $MONITOR_PATH (mode: $OPERATION_MODE)"

    # Ensure directory exists
    if [ ! -d "$MONITOR_PATH" ]; then
        log_message "ERROR: Monitor directory does not exist: $MONITOR_PATH"

        # Try to create or mount based on mode
        case "$OPERATION_MODE" in
            "smb")
                log_message "Creating SMB share directory: $MONITOR_PATH"
                mkdir -p "$MONITOR_PATH"
                chown camerabridge:camerabridge "$MONITOR_PATH"
                ;;
            "usb-gadget")
                log_message "USB gadget storage not mounted. Attempting to mount..."
                if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                    usb-gadget-manager.sh mount || {
                        log_message "ERROR: Failed to mount USB gadget storage"
                        return 1
                    }
                else
                    log_message "ERROR: USB gadget manager not found"
                    return 1
                fi
                ;;
        esac
    fi

    # Start file monitoring with inotify
    inotifywait -m -r -e create,moved_to,close_write "$MONITOR_PATH" --format '%w%f %e' 2>/dev/null |
    while read -r file event; do
        # Only process image files
        if [[ "$file" =~ \.(jpg|jpeg|png|tiff|raw|dng|cr2|nef|orf|arw|JPG|JPEG|PNG|TIFF|RAW|DNG|CR2|NEF|ORF|ARW)$ ]]; then
            log_message "New file detected: $file (event: $event, mode: $OPERATION_MODE)"

            # Different handling based on mode
            case "$OPERATION_MODE" in
                "usb-gadget")
                    # For USB gadget mode, wait longer as camera might still be writing
                    sleep 5
                    ;;
                "smb")
                    # For SMB mode, standard wait time
                    sleep 3
                    ;;
            esac

            # Verify file is complete by checking if it's still being written to
            if ! lsof "$file" >/dev/null 2>&1; then
                # Sync to Dropbox if connected
                if check_internet; then
                    sync_to_dropbox "$file"
                else
                    log_message "No internet connection, file queued for later sync: $file"
                    # Add to queue file for later processing
                    echo "$file" >> "/tmp/camera-bridge-queue"
                fi
            else
                log_message "File still being written, will retry: $file"
                # Re-queue the file for processing
                sleep 5
                echo "$file" >> "/tmp/camera-bridge-retry"
            fi
        else
            log_message "Ignoring non-image file: $file"
        fi
    done
}

# Check internet connectivity
check_internet() {
    # Try multiple DNS servers
    for dns in 8.8.8.8 1.1.1.1 208.67.222.222; do
        if ping -c 1 -W 5 "$dns" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Check if Dropbox is configured
check_dropbox_config() {
    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ] && grep -q "\[dropbox\]" /home/camerabridge/.config/rclone/rclone.conf; then
        return 0
    else
        log_message "WARNING: Dropbox not configured"
        return 1
    fi
}

# Test Dropbox connection
test_dropbox() {
    if check_dropbox_config; then
        sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1
        return $?
    else
        return 1
    fi
}

# Sync specific file to Dropbox
sync_to_dropbox() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_message "ERROR: File does not exist: $file"
        return 1
    fi

    if ! check_dropbox_config; then
        log_message "ERROR: Dropbox not configured, cannot sync: $file"
        return 1
    fi

    log_message "Syncing to Dropbox: $file"

    # Get relative path from monitor directory
    local rel_path="${file#$MONITOR_PATH/}"
    local dest_path="$DROPBOX_DEST/$rel_path"

    # Create directory structure on Dropbox if needed
    local dest_dir=$(dirname "$dest_path")
    if [ "$dest_dir" != "$DROPBOX_DEST" ]; then
        sudo -u camerabridge rclone mkdir "$dest_dir" 2>/dev/null || true
    fi

    # Sync the file
    if sudo -u camerabridge rclone copy "$file" "$DROPBOX_DEST" --create-empty-src-dirs --log-level INFO 2>&1 | tee -a "$LOG_FILE"; then
        log_message "Successfully synced: $file -> $dest_path"

        # For USB gadget mode, optionally remove file after sync to save space
        if [ "$OPERATION_MODE" = "usb-gadget" ] && [ "$AUTO_DELETE_SYNCED" = "true" ]; then
            log_message "Removing synced file from USB storage: $file"
            rm -f "$file"
        fi

        # Remove from retry queue if present
        if [ -f "/tmp/camera-bridge-retry" ]; then
            grep -v "^$file$" "/tmp/camera-bridge-retry" > "/tmp/camera-bridge-retry.tmp" 2>/dev/null || true
            mv "/tmp/camera-bridge-retry.tmp" "/tmp/camera-bridge-retry" 2>/dev/null || true
        fi

        return 0
    else
        log_message "Failed to sync: $file"
        # Add to retry queue
        echo "$file" >> "/tmp/camera-bridge-retry"
        return 1
    fi
}

# Process queued files
process_queue() {
    local queue_file="/tmp/camera-bridge-queue"

    if [ -f "$queue_file" ] && [ -s "$queue_file" ]; then
        log_message "Processing queued files..."

        while IFS= read -r file; do
            if [ -f "$file" ]; then
                sync_to_dropbox "$file"
            fi
        done < "$queue_file"

        # Clear the queue
        > "$queue_file"
    fi
}

# Process retry queue
process_retry_queue() {
    local retry_file="/tmp/camera-bridge-retry"

    if [ -f "$retry_file" ] && [ -s "$retry_file" ]; then
        log_message "Processing retry queue..."

        local temp_file="/tmp/camera-bridge-retry.processing"
        mv "$retry_file" "$temp_file" 2>/dev/null || return

        while IFS= read -r file; do
            if [ -f "$file" ]; then
                # Check if file is still being written to
                if ! lsof "$file" >/dev/null 2>&1; then
                    sync_to_dropbox "$file"
                else
                    log_message "File still being written, re-queuing: $file"
                    echo "$file" >> "$retry_file"
                fi
            fi
        done < "$temp_file"

        rm -f "$temp_file"
    fi
}

# Periodic full sync
periodic_sync() {
    local sync_interval=${SYNC_INTERVAL:-300}  # Default 5 minutes

    while true; do
        sleep "$sync_interval"

        if check_internet && check_dropbox_config; then
            log_message "Starting periodic sync (mode: $OPERATION_MODE)"

            # Process any queued files first
            process_queue
            process_retry_queue

            # Full directory sync
            if sudo -u camerabridge rclone sync "$MONITOR_PATH" "$DROPBOX_DEST" \
                --include "*.{jpg,jpeg,png,tiff,raw,dng,cr2,nef,orf,arw,JPG,JPEG,PNG,TIFF,RAW,DNG,CR2,NEF,ORF,ARW}" \
                --exclude ".*" \
                --exclude "Thumbs.db" \
                --exclude "desktop.ini" \
                --create-empty-src-dirs \
                --log-level INFO 2>&1 | tee -a "$LOG_FILE"; then
                log_message "Periodic sync completed successfully"

                # For USB gadget mode, clean up synced files if enabled
                if [ "$OPERATION_MODE" = "usb-gadget" ] && [ "$AUTO_DELETE_SYNCED" = "true" ]; then
                    log_message "Cleaning up synced files from USB storage"
                    find "$MONITOR_PATH" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \
                        -o -name "*.tiff" -o -name "*.raw" -o -name "*.dng" -o -name "*.cr2" \
                        -o -name "*.nef" -o -name "*.orf" -o -name "*.arw" \) \
                        -mtime +1 -delete 2>/dev/null || true
                fi
            else
                log_message "Periodic sync failed"
            fi
        else
            if ! check_internet; then
                log_message "No internet connection for periodic sync"
            elif ! check_dropbox_config; then
                log_message "Dropbox not configured for periodic sync"
            fi
        fi
    done
}

# Switch operation mode
switch_mode() {
    local new_mode="$1"

    log_message "Switching to $new_mode mode..."

    case "$new_mode" in
        "smb")
            # Disable USB gadget if active
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                usb-gadget-manager.sh disable >/dev/null 2>&1 || true
            fi
            OPERATION_MODE="smb"
            MONITOR_PATH="$SMB_SHARE"
            ;;
        "usb-gadget")
            if ! detect_hardware; then
                log_message "ERROR: USB gadget mode not supported on this hardware"
                return 1
            fi
            # Enable USB gadget
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                usb-gadget-manager.sh enable || {
                    log_message "ERROR: Failed to enable USB gadget mode"
                    return 1
                }
            else
                log_message "ERROR: USB gadget manager not found"
                return 1
            fi
            OPERATION_MODE="usb-gadget"
            MONITOR_PATH="$USB_MOUNT"
            ;;
        *)
            log_message "ERROR: Invalid mode: $new_mode"
            return 1
            ;;
    esac

    # Save mode to config
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "OPERATION_MODE=\"$OPERATION_MODE\"" > "$CONFIG_FILE"
    echo "MONITOR_PATH=\"$MONITOR_PATH\"" >> "$CONFIG_FILE"

    log_message "Switched to $new_mode mode successfully"
}

# Get current status with mode information
get_status() {
    echo "Camera Bridge Service Status"
    echo "============================"
    echo ""
    echo "Operation Mode: $OPERATION_MODE"
    echo "Monitor Path: $MONITOR_PATH"
    echo ""

    # Hardware detection
    if detect_hardware; then
        echo "Hardware: Pi Zero 2 W (USB gadget capable)"
    else
        echo "Hardware: Standard device"
    fi

    # Service status
    if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        echo "Service Status: Running (PID: $(cat $PID_FILE))"
    else
        echo "Service Status: Stopped"
    fi

    # Mode-specific status
    case "$OPERATION_MODE" in
        "usb-gadget")
            echo ""
            echo "USB Gadget Status:"
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                usb-gadget-manager.sh status | tail -n +3
            else
                echo "  USB gadget manager not available"
            fi
            ;;
        "smb")
            echo ""
            echo "SMB Service Status:"
            if systemctl is-active --quiet smbd; then
                echo "  SMB Server: Running"
            else
                echo "  SMB Server: Stopped"
            fi
            ;;
    esac

    # Dropbox status
    echo ""
    echo "Dropbox Status:"
    if check_dropbox_config; then
        if test_dropbox; then
            echo "  Connection: OK"
        else
            echo "  Connection: Failed"
        fi
    else
        echo "  Configuration: Not configured"
    fi

    # Recent activity
    echo ""
    echo "Recent Activity:"
    local recent_files=$(find "$MONITOR_PATH" -type f -mtime -1 2>/dev/null | wc -l)
    echo "  Files added today: $recent_files"

    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "0B")
        echo "  Log size: $log_size"
    fi
}

# Cleanup function
cleanup() {
    log_message "Cleaning up camera bridge service"

    # Kill background processes
    pkill -P $$ 2>/dev/null || true

    # Remove PID file
    rm -f "$PID_FILE"

    log_message "Camera Bridge Service stopped"
    exit 0
}

# Signal handlers
trap cleanup SIGTERM SIGINT

# Handle USR1 signal for USB gadget file notifications
handle_usr1() {
    log_message "Received USB gadget file notification"
    # Process any pending files immediately
    process_queue
    process_retry_queue
}

trap handle_usr1 SIGUSR1

start_service() {
    check_root
    load_config

    # Check if already running
    if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        log_message "Camera Bridge Service is already running (PID: $(cat $PID_FILE))"
        exit 1
    fi

    # Create PID file
    echo $$ > "$PID_FILE"

    log_message "Camera Bridge Service starting (PID: $$, Mode: $OPERATION_MODE)"

    # Ensure log directory exists
    mkdir -p "$(dirname $LOG_FILE)"
    chown camerabridge:camerabridge "$(dirname $LOG_FILE)"

    # Test Dropbox connection
    if check_dropbox_config; then
        if test_dropbox; then
            log_message "Dropbox connection: OK"
        else
            log_message "WARNING: Dropbox connection failed"
        fi
    else
        log_message "WARNING: Dropbox not configured"
    fi

    # Mode-specific initialization
    case "$OPERATION_MODE" in
        "usb-gadget")
            log_message "Initializing USB gadget mode..."
            if command -v usb-gadget-manager.sh >/dev/null 2>&1; then
                if ! usb-gadget-manager.sh status >/dev/null 2>&1; then
                    log_message "Setting up USB gadget..."
                    usb-gadget-manager.sh setup
                    usb-gadget-manager.sh enable
                fi
            else
                log_message "ERROR: USB gadget manager not found"
                exit 1
            fi
            ;;
        "smb")
            log_message "Using SMB network sharing mode..."
            # Ensure SMB services are running
            systemctl start smbd 2>/dev/null || log_message "WARNING: Could not start SMB service"
            ;;
    esac

    # Start background processes
    monitor_files &
    MONITOR_PID=$!

    periodic_sync &
    SYNC_PID=$!

    log_message "File monitor started (PID: $MONITOR_PID)"
    log_message "Periodic sync started (PID: $SYNC_PID)"

    # Wait for background processes
    wait
}

stop_service() {
    log_message "Camera Bridge Service stopping"

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            # Wait for graceful shutdown
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi

    # Kill any remaining processes
    pkill -f "inotifywait.*$MONITOR_PATH" 2>/dev/null || true
    pkill -f "camera-bridge.*periodic_sync" 2>/dev/null || true

    log_message "Camera Bridge Service stopped"
}

status_service() {
    get_status
    if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Main command handling
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
        status_service
        ;;
    switch-mode)
        if [ -z "$2" ]; then
            echo "Usage: $0 switch-mode {smb|usb-gadget}"
            exit 1
        fi
        switch_mode "$2"
        ;;
    test-dropbox)
        if test_dropbox; then
            echo "Dropbox connection: OK"
            exit 0
        else
            echo "Dropbox connection: FAILED"
            exit 1
        fi
        ;;
    sync-now)
        load_config
        if check_internet && check_dropbox_config; then
            log_message "Manual sync requested (mode: $OPERATION_MODE)"
            process_queue
            process_retry_queue
            sudo -u camerabridge rclone sync "$MONITOR_PATH" "$DROPBOX_DEST" \
                --include "*.{jpg,jpeg,png,tiff,raw,dng,cr2,nef,orf,arw,JPG,JPEG,PNG,TIFF,RAW,DNG,CR2,NEF,ORF,ARW}" \
                --exclude ".*" \
                --create-empty-src-dirs \
                --progress
        else
            echo "Cannot sync: No internet or Dropbox not configured"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|switch-mode|test-dropbox|sync-now}"
        echo ""
        echo "switch-mode options:"
        echo "  smb         - Use SMB network sharing"
        echo "  usb-gadget  - Use USB gadget mode (Pi Zero 2 W only)"
        exit 1
        ;;
esac