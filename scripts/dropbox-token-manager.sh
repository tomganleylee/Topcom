#!/bin/bash

# Dropbox Token Manager for Camera Bridge
# Handles token refresh, validation, and automatic renewal
# Supports both short-lived access tokens and refresh tokens

# Configuration
CONFIG_DIR="/home/camerabridge/.config/rclone"
RCLONE_CONF="$CONFIG_DIR/rclone.conf"
TOKEN_CACHE="$CONFIG_DIR/.dropbox-token-cache"
TOKEN_TIMESTAMP="$CONFIG_DIR/.dropbox-token-timestamp"
LOG_FILE="/var/log/camera-bridge/token-manager.log"
LOCK_FILE="/var/run/dropbox-token-refresh.lock"

# Token expiry settings (in seconds)
TOKEN_LIFETIME=$((4 * 3600))  # 4 hours
REFRESH_BEFORE=$((3 * 3600))  # Refresh 1 hour before expiry (after 3 hours)
OFFLINE_MAX_AGE=$((7 * 24 * 3600))  # Consider token expired after 7 days offline

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Logging function
log_message() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

# Check if we have internet connectivity
check_internet() {
    # Try multiple reliable endpoints
    for host in "api.dropboxapi.com" "8.8.8.8" "1.1.1.1"; do
        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Get current token from rclone config
get_current_token() {
    if [ ! -f "$RCLONE_CONF" ]; then
        log_message "ERROR" "rclone config not found at $RCLONE_CONF"
        return 1
    fi

    # Extract token from config
    local token_json=$(grep -A1 "^\[dropbox\]" "$RCLONE_CONF" | grep "^token" | cut -d'=' -f2- | xargs)

    if [ -z "$token_json" ]; then
        log_message "ERROR" "No token found in rclone config"
        return 1
    fi

    echo "$token_json"
}

# Parse access token from JSON
parse_access_token() {
    local json="$1"
    echo "$json" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p'
}

# Parse refresh token from JSON
parse_refresh_token() {
    local json="$1"
    echo "$json" | sed -n 's/.*"refresh_token":"\([^"]*\)".*/\1/p'
}

# Check if token needs refresh
needs_refresh() {
    # Check timestamp file
    if [ ! -f "$TOKEN_TIMESTAMP" ]; then
        log_message "INFO" "No timestamp file found, assuming token needs refresh"
        return 0
    fi

    local last_refresh=$(cat "$TOKEN_TIMESTAMP" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age=$((current_time - last_refresh))

    # If we've been offline for too long, force refresh
    if [ $age -gt $OFFLINE_MAX_AGE ]; then
        log_message "WARN" "Token age ($age seconds) exceeds offline maximum, forcing refresh"
        return 0
    fi

    # Check if it's time for regular refresh
    if [ $age -gt $REFRESH_BEFORE ]; then
        log_message "INFO" "Token age ($age seconds) exceeds refresh threshold"
        return 0
    fi

    log_message "DEBUG" "Token is still valid (age: $age seconds)"
    return 1
}

# Refresh token using Dropbox API
refresh_dropbox_token() {
    local refresh_token="$1"

    if [ -z "$refresh_token" ]; then
        log_message "ERROR" "No refresh token provided"
        return 1
    fi

    log_message "INFO" "Refreshing Dropbox access token..."

    # Get app key and secret from stored config or environment
    local app_key="${DROPBOX_APP_KEY:-}"
    local app_secret="${DROPBOX_APP_SECRET:-}"

    # If not in environment, try to read from config file
    if [ -z "$app_key" ] && [ -f "$CONFIG_DIR/.dropbox-app-credentials" ]; then
        source "$CONFIG_DIR/.dropbox-app-credentials"
        app_key="${DROPBOX_APP_KEY:-}"
        app_secret="${DROPBOX_APP_SECRET:-}"
    fi

    # For now, use rclone's built-in OAuth handling if credentials aren't available
    if [ -z "$app_key" ] || [ -z "$app_secret" ]; then
        log_message "INFO" "Using rclone's internal OAuth refresh mechanism"

        # Force rclone to refresh by doing a simple operation
        if sudo -u camerabridge rclone lsd dropbox: --max-depth 1 >/dev/null 2>&1; then
            log_message "INFO" "Token refreshed successfully via rclone"
            date +%s > "$TOKEN_TIMESTAMP"
            return 0
        else
            log_message "ERROR" "Failed to refresh token via rclone"
            return 1
        fi
    fi

    # Direct API refresh (if we have app credentials)
    local response=$(curl -s -X POST https://api.dropbox.com/oauth2/token \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$refresh_token" \
        -d "client_id=$app_key" \
        -d "client_secret=$app_secret")

    local new_access_token=$(echo "$response" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

    if [ -z "$new_access_token" ]; then
        log_message "ERROR" "Failed to refresh token. Response: $response"
        return 1
    fi

    log_message "INFO" "Successfully obtained new access token"

    # Update rclone config with new token
    update_rclone_config "$new_access_token" "$refresh_token"

    # Update timestamp
    date +%s > "$TOKEN_TIMESTAMP"

    return 0
}

# Update rclone configuration with new token
update_rclone_config() {
    local access_token="$1"
    local refresh_token="${2:-}"

    log_message "INFO" "Updating rclone configuration..."

    # Backup current config
    cp "$RCLONE_CONF" "$RCLONE_CONF.backup.$(date +%Y%m%d_%H%M%S)"

    # Create new token JSON
    local token_json='{"access_token":"'$access_token'","token_type":"bearer"'

    if [ -n "$refresh_token" ]; then
        token_json+=",\"refresh_token\":\"$refresh_token\""
    fi

    token_json+=',"expiry":"'$(date -u -d "+4 hours" '+%Y-%m-%dT%H:%M:%SZ')'"}'

    # Update config file
    # First, create temp file with updated token
    awk -v token="$token_json" '
        /^\[dropbox\]/ { in_dropbox=1; print; next }
        /^token/ && in_dropbox { print "token = " token; in_dropbox=0; next }
        /^\[/ && in_dropbox { in_dropbox=0 }
        { print }
    ' "$RCLONE_CONF" > "$RCLONE_CONF.tmp"

    # Replace original if successful
    if [ -s "$RCLONE_CONF.tmp" ]; then
        mv "$RCLONE_CONF.tmp" "$RCLONE_CONF"
        chown camerabridge:camerabridge "$RCLONE_CONF"
        chmod 600 "$RCLONE_CONF"
        log_message "INFO" "rclone config updated successfully"
    else
        log_message "ERROR" "Failed to update rclone config"
        rm -f "$RCLONE_CONF.tmp"
        return 1
    fi
}

# Validate current token
validate_token() {
    log_message "INFO" "Validating Dropbox token..."

    # Try to list root directory with minimal data
    if sudo -u camerabridge rclone lsd dropbox: --max-depth 1 --timeout 10s >/dev/null 2>&1; then
        log_message "INFO" "Token is valid and working"
        return 0
    else
        log_message "WARN" "Token validation failed"
        return 1
    fi
}

# Main refresh logic
perform_refresh() {
    # Use lock file to prevent concurrent refreshes
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        log_message "INFO" "Another refresh process is running, skipping"
        return 0
    fi

    # Check internet connectivity first
    if ! check_internet; then
        log_message "WARN" "No internet connectivity, skipping token refresh"

        # Check if we've been offline too long
        if [ -f "$TOKEN_TIMESTAMP" ]; then
            local last_refresh=$(cat "$TOKEN_TIMESTAMP")
            local current_time=$(date +%s)
            local offline_time=$((current_time - last_refresh))

            if [ $offline_time -gt $OFFLINE_MAX_AGE ]; then
                log_message "ERROR" "Token expired due to extended offline period ($offline_time seconds)"
                # Mark for immediate refresh when online
                echo "0" > "$TOKEN_TIMESTAMP"
            fi
        fi

        return 1
    fi

    # Get current token configuration
    local token_json=$(get_current_token)
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Failed to get current token"
        return 1
    fi

    # Extract tokens
    local access_token=$(parse_access_token "$token_json")
    local refresh_token=$(parse_refresh_token "$token_json")

    # Check if we have a refresh token
    if [ -n "$refresh_token" ]; then
        log_message "INFO" "Using refresh token for automatic renewal"

        # Check if refresh is needed
        if needs_refresh; then
            refresh_dropbox_token "$refresh_token"
            return $?
        else
            log_message "INFO" "Token is still valid, no refresh needed"
            return 0
        fi
    else
        log_message "WARN" "No refresh token available, using short-lived token only"

        # Validate current token
        if validate_token; then
            date +%s > "$TOKEN_TIMESTAMP"
            return 0
        else
            log_message "ERROR" "Short-lived token expired and no refresh token available"
            log_message "ERROR" "Please reconfigure Dropbox with a new token"
            return 1
        fi
    fi

    # Release lock
    flock -u 200
}

# Handle different command line options
case "${1:-}" in
    "refresh")
        log_message "INFO" "Manual token refresh requested"
        perform_refresh
        exit $?
        ;;

    "validate")
        validate_token
        exit $?
        ;;

    "check")
        if needs_refresh; then
            echo "Token needs refresh"
            exit 0
        else
            echo "Token is valid"
            exit 1
        fi
        ;;

    "status")
        echo "Dropbox Token Status"
        echo "===================="

        if [ -f "$TOKEN_TIMESTAMP" ]; then
            local last_refresh=$(cat "$TOKEN_TIMESTAMP")
            local current_time=$(date +%s)
            local age=$((current_time - last_refresh))
            echo "Last refresh: $(date -d "@$last_refresh" '+%Y-%m-%d %H:%M:%S')"
            echo "Token age: $((age / 3600)) hours $((age % 3600 / 60)) minutes"

            if [ $age -gt $TOKEN_LIFETIME ]; then
                echo "Status: EXPIRED (needs refresh)"
            elif [ $age -gt $REFRESH_BEFORE ]; then
                echo "Status: EXPIRING SOON (will refresh)"
            else
                echo "Status: VALID"
            fi
        else
            echo "No refresh timestamp found"
        fi

        if validate_token >/dev/null 2>&1; then
            echo "Validation: PASSED"
        else
            echo "Validation: FAILED"
        fi
        ;;

    "setup-refresh-token")
        # Helper to set up OAuth app for refresh tokens
        echo "Setting up Dropbox OAuth App for refresh tokens"
        echo "================================================"
        echo ""
        echo "To use refresh tokens (recommended for long-term operation):"
        echo ""
        echo "1. Go to: https://www.dropbox.com/developers/apps"
        echo "2. Create a new app or use existing one"
        echo "3. Note your App key and App secret"
        echo "4. Set token access type to 'offline' when authorizing"
        echo ""
        read -p "Enter App Key: " app_key
        read -s -p "Enter App Secret: " app_secret
        echo ""

        # Save credentials
        cat > "$CONFIG_DIR/.dropbox-app-credentials" << EOF
# Dropbox OAuth App Credentials
DROPBOX_APP_KEY="$app_key"
DROPBOX_APP_SECRET="$app_secret"
EOF
        chmod 600 "$CONFIG_DIR/.dropbox-app-credentials"
        chown camerabridge:camerabridge "$CONFIG_DIR/.dropbox-app-credentials"

        echo "Credentials saved. Now run the authorization flow to get refresh token."
        ;;

    "auto")
        # Automatic mode for service/cron
        log_message "INFO" "Running automatic token refresh check"
        perform_refresh
        exit $?
        ;;

    *)
        echo "Dropbox Token Manager for Camera Bridge"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  refresh   - Manually refresh the token"
        echo "  validate  - Check if current token is valid"
        echo "  check     - Check if token needs refresh"
        echo "  status    - Show token status"
        echo "  auto      - Run automatic refresh (for cron/service)"
        echo "  setup-refresh-token - Set up OAuth app for refresh tokens"
        echo ""
        echo "This script handles automatic token refresh to prevent expiration."
        exit 0
        ;;
esac