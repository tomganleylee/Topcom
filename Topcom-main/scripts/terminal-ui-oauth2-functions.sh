#!/bin/bash

# Find the configure_dropbox function and add OAuth2 option
# This patch adds OAuth2 token entry to the terminal UI

# Function to add to terminal-ui.sh
add_oauth2_functions() {
    cat << 'FUNCS'

# OAuth2 Token Configuration Function
configure_dropbox_oauth2_token() {
    local TEMP_DIR="/tmp/camera-bridge-$$"
    mkdir -p "$TEMP_DIR"

    clear
    dialog --title "Dropbox OAuth2 Setup" --msgbox "DROPBOX OAUTH2 TOKEN SETUP\n\nThis method uses OAuth2 tokens with automatic refresh.\nOnce configured, tokens renew automatically!\n\nYou'll need to get a token from another machine\nwith a web browser.\n\nPress OK to continue." 13 65

    # Show instructions
    dialog --title "Getting OAuth2 Token - Step 1" --msgbox "ON A COMPUTER WITH A WEB BROWSER:\n\n1. Open a terminal/command prompt\n\n2. Run this command:\n   rclone authorize dropbox\n\n3. Your browser will open\n\n4. Log in to Dropbox (or Dropbox Business)\n\n5. Authorize rclone\n\n6. Copy the ENTIRE token that appears\n   (starts with { and ends with })\n\nPress OK when you have the token ready." 18 70

    # Get the token
    local token_input=""
    local token_file="$TEMP_DIR/oauth_token.txt"

    dialog --title "Enter OAuth2 Token" --inputbox "Paste the complete OAuth2 token JSON here:\n\nIt should look like:\n{\"access_token\":\"...\",\"token_type\":\"bearer\",\"refresh_token\":\"...\",\"expiry\":\"...\"}\n\nIMPORTANT: Include everything from { to }" 14 75 2>"$token_file"

    if [ ! -f "$token_file" ] || [ ! -s "$token_file" ]; then
        dialog --title "Cancelled" --msgbox "No token provided. Setup cancelled." 7 50
        rm -rf "$TEMP_DIR"
        return 1
    fi

    token_input=$(cat "$token_file")

    # Validate token format
    if [[ "$token_input" != *"{"* ]] || [[ "$token_input" != *"}"* ]]; then
        dialog --title "Invalid Format" --msgbox "ERROR: Token must be complete JSON!\n\nMake sure to copy everything from { to }\n\nExample:\n{\"access_token\":\"...\", \"refresh_token\":\"...\"}" 11 65
        rm -rf "$TEMP_DIR"
        return 1
    fi

    if [[ "$token_input" != *"access_token"* ]]; then
        dialog --title "Invalid Token" --msgbox "ERROR: This doesn't appear to be a valid token!\n\nMake sure you ran:\nrclone authorize dropbox\n\nAnd copied the entire output." 10 60
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Check for refresh token
    local has_refresh=0
    if [[ "$token_input" == *"refresh_token"* ]]; then
        has_refresh=1
        dialog --title "Token Validated" --infobox "✓ OAuth2 token detected\n✓ Refresh token found\n✓ Automatic renewal enabled\n\nConfiguring Dropbox..." 8 50
        sleep 2
    else
        dialog --title "⚠ Warning" --msgbox "Token is missing refresh_token!\n\nThis token will expire and need manual renewal.\n\nFor automatic refresh, use:\nrclone authorize dropbox" 10 60
    fi

    # Create configuration
    dialog --title "Configuring..." --infobox "Setting up Dropbox configuration...\n\nPlease wait..." 6 50

    # Ensure user exists
    if ! id "camerabridge" >/dev/null 2>&1; then
        sudo useradd -r -s /bin/false -d /home/camerabridge camerabridge 2>/dev/null || true
    fi

    # Create config directory
    sudo mkdir -p /home/camerabridge/.config/rclone 2>/dev/null

    # Write configuration
    cat > "$TEMP_DIR/rclone.conf" << EOFCONF
[dropbox]
type = dropbox
token = $token_input
EOFCONF

    # Install configuration
    sudo cp "$TEMP_DIR/rclone.conf" /home/camerabridge/.config/rclone/rclone.conf
    sudo chown -R camerabridge:camerabridge /home/camerabridge/.config
    sudo chmod 700 /home/camerabridge/.config/rclone
    sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf

    # Test connection
    dialog --title "Testing Connection..." --infobox "Testing Dropbox connection...\n\nThis may take 10-30 seconds." 6 50

    if timeout 45 sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        # Get account info
        local account_info=""
        account_info=$(sudo -u camerabridge rclone about dropbox: 2>/dev/null | grep -E "(Account|User|Used:|Free:|Total:)" | head -5)

        if [ $has_refresh -eq 1 ]; then
            dialog --title "✓ SUCCESS!" --msgbox "DROPBOX OAUTH2 CONFIGURED!\n\n$account_info\n\n✓ OAuth2 token installed\n✓ Refresh token enabled\n✓ Automatic renewal active\n✓ No manual reconfiguration needed!\n\nPhotos will sync to:\ndropbox:Camera-Photos/" 18 70
        else
            dialog --title "✓ Configured" --msgbox "DROPBOX CONFIGURED!\n\n$account_info\n\n⚠ No refresh token\n⚠ Token may expire\n⚠ May need reconfiguration\n\nPhotos will sync to:\ndropbox:Camera-Photos/" 16 70
        fi

        # Create destination folder
        sudo -u camerabridge rclone mkdir dropbox:Camera-Photos 2>/dev/null || true

        # Restart service if running
        if systemctl is-active --quiet camera-bridge; then
            dialog --title "Restarting Service" --infobox "Restarting Camera Bridge service..." 5 45
            sudo systemctl restart camera-bridge
            sleep 2
        fi

        rm -rf "$TEMP_DIR"
        return 0
    else
        # Connection failed
        local error_msg=$(sudo -u camerabridge rclone lsd dropbox: 2>&1 | head -3)

        dialog --title "Connection Failed" --msgbox "Failed to connect to Dropbox!\n\nError:\n$error_msg\n\nPossible issues:\n• Invalid token\n• Network problems\n• Dropbox API issues\n\nTry getting a fresh token." 15 70

        # Offer to keep config
        if dialog --title "Keep Configuration?" --yesno "Do you want to keep the configuration to retry later?" 7 60; then
            dialog --title "Configuration Saved" --msgbox "Configuration saved.\nYou can test it later from the Dropbox menu." 7 55
        else
            sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
            dialog --title "Configuration Removed" --msgbox "Configuration removed.\nYou can try again from the menu." 7 50
        fi

        rm -rf "$TEMP_DIR"
        return 1
    fi
}

# Updated configure_dropbox function with OAuth2 option
configure_dropbox() {
    local choice=""

    # Check if already configured
    if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
        if grep -q "refresh_token" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
            dialog --title "Dropbox Status" --msgbox "Dropbox is already configured with OAuth2!\n\n✓ Refresh token detected\n✓ Automatic renewal enabled\n\nChoose 'Reconfigure' to set up again." 10 60
        else
            dialog --title "Dropbox Status" --msgbox "Dropbox is configured with a legacy token.\n\n⚠ No refresh token\n⚠ May expire\n\nConsider reconfiguring with OAuth2." 10 60
        fi
    fi

    dialog --title "Dropbox Configuration" --menu "Choose configuration method:" 15 70 5 \
        1 "OAuth2 Token (Recommended)" \
        2 "Legacy Access Token" \
        3 "Reconfigure Existing" \
        4 "View Current Config" \
        5 "Cancel" 2>"$TEMP_DIR/dropbox_method"

    choice=$(cat "$TEMP_DIR/dropbox_method" 2>/dev/null)

    case $choice in
        1)
            # OAuth2 Token Entry
            configure_dropbox_oauth2_token
            ;;
        2)
            # Legacy token (existing function)
            configure_dropbox_manual
            ;;
        3)
            # Reconfigure
            if dialog --title "Confirm Reconfigure" --yesno "This will replace your existing configuration.\n\nContinue?" 8 55; then
                sudo rm -f /home/camerabridge/.config/rclone/rclone.conf
                configure_dropbox_oauth2_token
            fi
            ;;
        4)
            # View config
            if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
                local config_info="Configuration exists:\n"
                if grep -q "refresh_token" /home/camerabridge/.config/rclone/rclone.conf 2>/dev/null; then
                    config_info="$config_info\n✓ OAuth2 with refresh token"
                else
                    config_info="$config_info\n⚠ Legacy token (no refresh)"
                fi

                if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
                    config_info="$config_info\n✓ Connection working"
                else
                    config_info="$config_info\n✗ Connection failed"
                fi

                dialog --title "Current Configuration" --msgbox "$config_info" 10 60
            else
                dialog --title "No Configuration" --msgbox "No Dropbox configuration found." 7 45
            fi
            ;;
        *)
            return
            ;;
    esac
}
FUNCS
}

# Add the functions to the script
add_oauth2_functions
