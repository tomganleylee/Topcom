#!/bin/bash

# Setup Auto-Login Configuration
# Configures automatic console login for seamless user experience

set -e

LOG_FILE="/var/log/camera-bridge/setup.log"
USER="camerabridge"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Detect the system type
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Configure auto-login for Raspberry Pi OS
setup_rpi_autologin() {
    log_message "Configuring auto-login for Raspberry Pi OS"

    # Enable auto-login service
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        log_message "Auto-login already configured"
        return 0
    fi

    # Create override directory
    mkdir -p /etc/systemd/system/getty@tty1.service.d/

    # Create auto-login configuration
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF

    log_message "Auto-login configuration created for $USER"

    # Reload systemd
    systemctl daemon-reload
    systemctl restart getty@tty1.service
}

# Configure auto-login for Ubuntu/Debian
setup_ubuntu_autologin() {
    log_message "Configuring auto-login for Ubuntu/Debian"

    # Check if running in graphical mode
    if systemctl get-default | grep -q graphical; then
        log_message "WARNING: System is in graphical mode. Consider switching to multi-user.target"
        log_message "Run: sudo systemctl set-default multi-user.target"
    fi

    # Create override directory
    mkdir -p /etc/systemd/system/getty@tty1.service.d/

    # Create auto-login configuration
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I linux
EOF

    log_message "Auto-login configuration created for $USER"

    # Reload systemd
    systemctl daemon-reload
}

# Configure user profile for auto-start
setup_user_profile() {
    local user_home="/home/$USER"

    log_message "Configuring user profile for auto-start"

    # Ensure user exists and has home directory
    if [ ! -d "$user_home" ]; then
        log_message "ERROR: User home directory not found: $user_home"
        return 1
    fi

    # Create .profile if it doesn't exist
    if [ ! -f "$user_home/.profile" ]; then
        touch "$user_home/.profile"
        chown $USER:$USER "$user_home/.profile"
    fi

    # Add auto-start configuration to .profile
    if ! grep -q "camera-bridge-autostart" "$user_home/.profile"; then
        cat >> "$user_home/.profile" << 'EOF'

# Camera Bridge Auto-start
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    # Check if camera-bridge-autostart should run
    if [ -f /opt/camera-bridge/config/autostart-enabled ]; then
        # Clear screen and start UI
        clear
        echo "Starting Camera Bridge..."
        sleep 2
        /usr/local/bin/camera-bridge-autostart
    fi
fi
EOF
        chown $USER:$USER "$user_home/.profile"
        log_message "Auto-start configuration added to user profile"
    else
        log_message "Auto-start configuration already exists in user profile"
    fi
}

# Create autostart control files
setup_autostart_control() {
    local config_dir="/opt/camera-bridge/config"

    log_message "Setting up autostart control"

    # Create config directory
    mkdir -p "$config_dir"

    # Create autostart enabled flag
    touch "$config_dir/autostart-enabled"

    # Set permissions
    chown -R $USER:$USER "$config_dir"
    chmod 755 "$config_dir"
    chmod 644 "$config_dir/autostart-enabled"

    log_message "Autostart control files created"
}

# Disable auto-login function
disable_autologin() {
    log_message "Disabling auto-login"

    # Remove auto-login configuration
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
    fi

    if [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
        rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
    fi

    # Remove autostart flag
    rm -f /opt/camera-bridge/config/autostart-enabled

    # Reload systemd
    systemctl daemon-reload
    systemctl restart getty@tty1.service

    log_message "Auto-login disabled"
}

# Main setup function
main() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This script must be run as root"
        exit 1
    fi

    # Ensure log directory exists
    mkdir -p "$(dirname $LOG_FILE)"

    case "$1" in
        "enable")
            log_message "Enabling auto-login and auto-start"

            # Detect system and configure accordingly
            SYSTEM=$(detect_system)
            case "$SYSTEM" in
                "raspbian")
                    setup_rpi_autologin
                    ;;
                "ubuntu"|"debian")
                    setup_ubuntu_autologin
                    ;;
                *)
                    log_message "WARNING: Unknown system type: $SYSTEM"
                    log_message "Attempting Ubuntu/Debian configuration"
                    setup_ubuntu_autologin
                    ;;
            esac

            # Common configuration
            setup_user_profile
            setup_autostart_control

            log_message "Auto-login setup complete"
            log_message "System will auto-login as '$USER' on next boot"
            log_message "Camera Bridge UI will start automatically"
            ;;

        "disable")
            disable_autologin
            ;;

        "status")
            if [ -f /opt/camera-bridge/config/autostart-enabled ]; then
                echo "Auto-login: ENABLED"
                echo "User: $USER"
                echo "Auto-start: ENABLED"
            else
                echo "Auto-login: DISABLED"
            fi

            # Check current getty configuration
            if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ] || \
               [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
                echo "Getty service: CONFIGURED for auto-login"
            else
                echo "Getty service: STANDARD (manual login required)"
            fi
            ;;

        *)
            echo "Usage: $0 {enable|disable|status}"
            echo ""
            echo "  enable  - Enable auto-login and auto-start"
            echo "  disable - Disable auto-login and auto-start"
            echo "  status  - Show current configuration"
            exit 1
            ;;
    esac
}

main "$@"