#!/bin/bash

# WiFi Auto-Connect Service
# Automatically connects to saved networks when available

WIFI_MANAGER="/opt/camera-bridge/scripts/wifi-manager.sh"
LOG_FILE="/var/log/camera-bridge/wifi-auto-connect.log"
PID_FILE="/var/run/wifi-auto-connect.pid"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    if ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "Auto-connect service already running (PID: $(cat "$PID_FILE"))"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# Write PID file
echo $$ > "$PID_FILE"

# Cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
    log_message "WiFi auto-connect service stopped"
    exit 0
}

trap cleanup EXIT INT TERM

log_message "WiFi auto-connect service started (PID: $$)"

# Main monitoring loop
while true; do
    # Check if we have a WiFi connection
    if ! current_ssid=$(iwgetid -r 2>/dev/null) || [ -z "$current_ssid" ]; then
        log_message "No WiFi connection detected, attempting auto-connect..."

        if [ -x "$WIFI_MANAGER" ]; then
            if "$WIFI_MANAGER" auto-connect >> "$LOG_FILE" 2>&1; then
                # Check if connection was successful
                sleep 5
                if new_ssid=$(iwgetid -r 2>/dev/null) && [ -n "$new_ssid" ]; then
                    log_message "Auto-connected successfully to: $new_ssid"
                else
                    log_message "Auto-connect completed but no connection established"
                fi
            else
                log_message "Auto-connect failed"
            fi
        else
            log_message "WiFi manager script not found: $WIFI_MANAGER"
        fi
    else
        # Already connected, just log periodically
        if [ $(($(date +%s) % 300)) -eq 0 ]; then  # Every 5 minutes
            log_message "Connected to: $current_ssid"
        fi
    fi

    # Wait before next check
    sleep 30
done