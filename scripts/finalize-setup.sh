#!/bin/bash

# Camera Bridge Final Setup Script
# Sets up permissions, creates shortcuts, and prepares system for deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

echo -e "${BLUE}🔧 Camera Bridge Final Setup${NC}"
echo "============================"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log "Project root: $PROJECT_ROOT"
log "Current user: $(whoami)"

# Set correct permissions for all scripts
log "Setting script permissions..."
find "$PROJECT_ROOT/scripts" -name "*.sh" -exec chmod +x {} \;
find "$PROJECT_ROOT/raspberry-pi/scripts" -name "*.sh" -exec chmod +x {} \;

# Make all scripts executable
chmod +x "$PROJECT_ROOT"/scripts/*.sh
chmod +x "$PROJECT_ROOT"/raspberry-pi/scripts/*.sh

# Create symbolic links for easy access
log "Creating command shortcuts..."

# Main commands
ln -sf "$PROJECT_ROOT/scripts/terminal-ui.sh" /usr/local/bin/camera-bridge-ui 2>/dev/null || true
ln -sf "$PROJECT_ROOT/scripts/camera-bridge-service.sh" /usr/local/bin/camera-bridge-service 2>/dev/null || true
ln -sf "$PROJECT_ROOT/scripts/wifi-manager.sh" /usr/local/bin/camera-bridge-wifi 2>/dev/null || true

# Short aliases
ln -sf "$PROJECT_ROOT/scripts/terminal-ui.sh" /usr/local/bin/cb-ui 2>/dev/null || true
ln -sf "$PROJECT_ROOT/scripts/camera-bridge-service.sh" /usr/local/bin/cb-service 2>/dev/null || true
ln -sf "$PROJECT_ROOT/scripts/wifi-manager.sh" /usr/local/bin/cb-wifi 2>/dev/null || true

# Create status check command
cat > /usr/local/bin/cb-status << 'EOF'
#!/bin/bash
echo "Camera Bridge System Status"
echo "==========================="
echo ""

# Service status
echo "Services:"
for service in camera-bridge smbd nginx; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "  ✓ $service: Running"
    else
        echo "  ✗ $service: Stopped"
    fi
done

echo ""

# Network status
if command -v iwgetid >/dev/null 2>&1; then
    if ssid=$(iwgetid -r 2>/dev/null) && [ -n "$ssid" ]; then
        echo "WiFi: Connected to $ssid"
    else
        echo "WiFi: Not connected"
    fi
fi

ip_addr=$(hostname -I | awk '{print $1}')
echo "IP Address: ${ip_addr:-None}"

echo ""

# Storage status
echo "Storage:"
df -h / | awk 'NR==2{printf "  Root: %s used, %s available\n", $3, $4}'
if [ -d "/srv/samba/camera-share" ]; then
    share_size=$(du -sh /srv/samba/camera-share 2>/dev/null | cut -f1 || echo "0B")
    echo "  Camera Share: $share_size"
fi

echo ""

# Recent activity
if [ -f "/var/log/camera-bridge/service.log" ]; then
    recent_files=$(find /srv/samba/camera-share -type f -mtime -1 2>/dev/null | wc -l)
    echo "Recent Activity: $recent_files files in last 24 hours"
fi

# Dropbox status
if [ -f "/home/camerabridge/.config/rclone/rclone.conf" ]; then
    if sudo -u camerabridge rclone lsd dropbox: >/dev/null 2>&1; then
        echo "Dropbox: Connected ✓"
    else
        echo "Dropbox: Connection failed ✗"
    fi
else
    echo "Dropbox: Not configured"
fi
EOF

chmod +x /usr/local/bin/cb-status

# Create log viewer command
cat > /usr/local/bin/cb-logs << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/camera-bridge/service.log"

if [ -f "$LOG_FILE" ]; then
    if [ "$1" = "-f" ]; then
        tail -f "$LOG_FILE"
    else
        tail -50 "$LOG_FILE"
    fi
else
    echo "Log file not found: $LOG_FILE"
    exit 1
fi
EOF

chmod +x /usr/local/bin/cb-logs

# Create system info command for Raspberry Pi
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    cat > /usr/local/bin/cb-temp << 'EOF'
#!/bin/bash
if command -v vcgencmd >/dev/null 2>&1; then
    temp=$(vcgencmd measure_temp | cut -d'=' -f2)
    echo "CPU Temperature: $temp"

    # Check for throttling
    throttled=$(vcgencmd get_throttled)
    if [ "$throttled" != "throttled=0x0" ]; then
        echo "Throttling detected: $throttled"
    else
        echo "No throttling detected"
    fi
else
    echo "Not a Raspberry Pi or vcgencmd not available"
fi
EOF

    chmod +x /usr/local/bin/cb-temp
fi

# Create global bashrc additions for all users
log "Setting up global aliases..."
cat > /etc/profile.d/camera-bridge.sh << 'EOF'
# Camera Bridge aliases and functions
alias cb-ui='camera-bridge-ui'
alias cb-status='camera-bridge-status'
alias cb-logs='camera-bridge-logs'
alias cb-wifi='camera-bridge-wifi'

# Function to quickly check camera bridge status
cb() {
    case "$1" in
        "status"|"")
            cb-status
            ;;
        "logs")
            cb-logs
            ;;
        "ui")
            cb-ui
            ;;
        "wifi")
            shift
            cb-wifi "$@"
            ;;
        "temp")
            cb-temp 2>/dev/null || echo "Temperature monitoring not available"
            ;;
        *)
            echo "Camera Bridge Commands:"
            echo "  cb status  - Show system status"
            echo "  cb logs    - Show recent logs"
            echo "  cb ui      - Open terminal interface"
            echo "  cb wifi    - WiFi management"
            echo "  cb temp    - CPU temperature (Pi only)"
            ;;
    esac
}
EOF

# Create project information file
log "Creating project information..."
cat > "$PROJECT_ROOT/PROJECT_INFO" << EOF
Camera Bridge Project Information
=================================

Generated: $(date)
Platform: $(uname -a)
User: $(whoami)
Project Root: $PROJECT_ROOT

Installation Status:
- Scripts: $(find "$PROJECT_ROOT/scripts" -name "*.sh" -executable | wc -l) executable
- Raspberry Pi Scripts: $(find "$PROJECT_ROOT/raspberry-pi/scripts" -name "*.sh" -executable 2>/dev/null | wc -l) executable
- Web Interface: $([ -f "$PROJECT_ROOT/web/index.php" ] && echo "Present" || echo "Missing")
- Configuration Files: $(ls "$PROJECT_ROOT/config/"*.conf 2>/dev/null | wc -l) files
- Documentation: $(ls "$PROJECT_ROOT"/*.md 2>/dev/null | wc -l) files

System Commands Available:
- camera-bridge-ui (cb-ui)
- camera-bridge-service (cb-service)
- camera-bridge-wifi (cb-wifi)
- cb-status
- cb-logs
- cb-temp (Raspberry Pi only)

Quick Start:
1. Install packages: sudo ./scripts/install-packages.sh
2. Configure system: Use web interface or cb-ui
3. Check status: cb-status
4. View logs: cb-logs

For Raspberry Pi:
1. Install: sudo ./raspberry-pi/scripts/install-rpi.sh
2. Setup: sudo ./raspberry-pi/scripts/setup-rpi.sh
3. Manage: cb-ui

For USB installer:
sudo ./raspberry-pi/scripts/create-usb-installer.sh /dev/sdX

EOF

# Set proper ownership for project files
log "Setting ownership and permissions..."
if id "camerabridge" >/dev/null 2>&1; then
    # Change ownership of config and data directories
    mkdir -p /home/camerabridge/.camera-bridge
    chown -R camerabridge:camerabridge /home/camerabridge/.camera-bridge

    # If system directories exist, set proper ownership
    if [ -d "/srv/samba/camera-share" ]; then
        chown -R camerabridge:camerabridge /srv/samba/camera-share
    fi

    if [ -d "/var/log/camera-bridge" ]; then
        chown -R camerabridge:camerabridge /var/log/camera-bridge
    fi
fi

# Create desktop shortcuts if desktop environment exists
if command -v lxpanel >/dev/null 2>&1 || [ -d "/usr/share/applications" ]; then
    log "Creating desktop shortcuts..."

    mkdir -p /usr/share/applications

    cat > /usr/share/applications/camera-bridge-ui.desktop << 'EOF'
[Desktop Entry]
Name=Camera Bridge Manager
Comment=Manage Camera Bridge System
Exec=x-terminal-emulator -e camera-bridge-ui
Icon=camera-photo
Type=Application
Categories=System;Photography;Network;
Terminal=false
StartupNotify=true
EOF

    cat > /usr/share/applications/camera-bridge-status.desktop << 'EOF'
[Desktop Entry]
Name=Camera Bridge Status
Comment=View Camera Bridge Status
Exec=x-terminal-emulator -e "cb-status; read -p 'Press Enter to close...'"
Icon=dialog-information
Type=Application
Categories=System;Photography;Network;
Terminal=false
StartupNotify=true
EOF

    chmod 644 /usr/share/applications/camera-bridge-*.desktop
fi

# Create systemd user service for automatic UI startup (optional)
if id "camerabridge" >/dev/null 2>&1; then
    log "Setting up user service..."

    sudo -u camerabridge mkdir -p /home/camerabridge/.config/systemd/user

    cat > /home/camerabridge/.config/systemd/user/camera-bridge-ui.service << 'EOF'
[Unit]
Description=Camera Bridge UI Auto-Start
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/camera-bridge-ui
RemainAfterExit=yes
StandardOutput=null

[Install]
WantedBy=default.target
EOF

    # Don't enable by default - let user choose
    chown -R camerabridge:camerabridge /home/camerabridge/.config/systemd
fi

# Create update script
log "Creating update mechanism..."
cat > "$PROJECT_ROOT/update.sh" << 'EOF'
#!/bin/bash

# Camera Bridge Update Script

set -e

echo "Camera Bridge Update"
echo "==================="

# Get current directory
UPDATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./update.sh"
    exit 1
fi

echo "Updating from: $UPDATE_DIR"

# Stop services
echo "Stopping services..."
systemctl stop camera-bridge 2>/dev/null || true

# Backup current installation
echo "Creating backup..."
tar czf "/var/backups/camera-bridge-$(date +%Y%m%d_%H%M%S).tar.gz" \
    /opt/camera-bridge 2>/dev/null || true

# Copy new files
echo "Installing update..."
cp -r "$UPDATE_DIR"/* /opt/camera-bridge/ 2>/dev/null || {
    echo "Warning: Some files could not be copied"
}

# Set permissions
echo "Setting permissions..."
bash /opt/camera-bridge/scripts/finalize-setup.sh

# Restart services
echo "Starting services..."
systemctl daemon-reload
systemctl start camera-bridge 2>/dev/null || true

echo "Update completed successfully!"
echo "Check status with: cb-status"
EOF

chmod +x "$PROJECT_ROOT/update.sh"

# Test command accessibility
log "Testing command accessibility..."
if command -v cb-status >/dev/null 2>&1; then
    log "✓ cb-status command available"
else
    warn "✗ cb-status command not accessible - check PATH"
fi

if command -v cb-ui >/dev/null 2>&1; then
    log "✓ cb-ui command available"
else
    warn "✗ cb-ui command not accessible - check PATH"
fi

# Create installation verification script
cat > "$PROJECT_ROOT/verify-installation.sh" << 'EOF'
#!/bin/bash

echo "Camera Bridge Installation Verification"
echo "======================================"
echo ""

# Check directories
echo "Directory Structure:"
dirs=("/opt/camera-bridge" "/srv/samba/camera-share" "/var/log/camera-bridge")
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir exists"
    else
        echo "  ✗ $dir missing"
    fi
done

echo ""

# Check scripts
echo "Scripts:"
scripts=("camera-bridge-service.sh" "wifi-manager.sh" "terminal-ui.sh")
for script in "${scripts[@]}"; do
    if [ -x "/opt/camera-bridge/scripts/$script" ]; then
        echo "  ✓ $script executable"
    else
        echo "  ✗ $script missing or not executable"
    fi
done

echo ""

# Check commands
echo "System Commands:"
commands=("cb-status" "cb-ui" "cb-logs")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd available"
    else
        echo "  ✗ $cmd not found"
    fi
done

echo ""

# Check services
echo "Services:"
services=("nginx" "smbd")
for service in "${services[@]}"; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "  ✓ $service enabled"
    else
        echo "  ✗ $service not enabled"
    fi
done

echo ""

# Check users
echo "Users:"
if id "camerabridge" >/dev/null 2>&1; then
    echo "  ✓ camerabridge user exists"
else
    echo "  ✗ camerabridge user missing"
fi

if id "camera" >/dev/null 2>&1; then
    echo "  ✓ camera user exists"
else
    echo "  ✗ camera user missing"
fi

echo ""
echo "Installation verification complete."
echo "Run 'cb-status' to check system status."
EOF

chmod +x "$PROJECT_ROOT/verify-installation.sh"

# Create quick deployment summary
log "Creating deployment summary..."
cat > "$PROJECT_ROOT/DEPLOYMENT_SUMMARY.md" << 'EOF'
# Camera Bridge Deployment Summary

## Quick Start Commands

### Installation
```bash
# Ubuntu/Debian
sudo ./scripts/install-packages.sh

# Raspberry Pi
sudo ./raspberry-pi/scripts/install-rpi.sh
sudo ./raspberry-pi/scripts/setup-rpi.sh

# USB Installer (Pi)
sudo ./raspberry-pi/scripts/create-usb-installer.sh /dev/sdX
```

### Management
```bash
# Terminal interface
cb-ui

# Quick status
cb-status

# View logs
cb-logs

# WiFi management
cb-wifi status
```

### Web Interface
- Setup: http://[device-ip]/
- Status: http://[device-ip]/status.php

### Verification
```bash
# Test installation
./verify-installation.sh

# Update system
sudo ./update.sh
```

## File Locations

- **Scripts**: `/opt/camera-bridge/scripts/`
- **Web**: `/opt/camera-bridge/web/`
- **Config**: `/opt/camera-bridge/config/`
- **Logs**: `/var/log/camera-bridge/`
- **SMB Share**: `/srv/samba/camera-share/`

## Service Management

```bash
# Service control
sudo systemctl start|stop|restart camera-bridge
sudo systemctl status camera-bridge

# Manual service control
sudo /opt/camera-bridge/scripts/camera-bridge-service.sh start|stop|status
```

## Network Setup

1. Connect via Ethernet (automatic)
2. WiFi via web interface or cb-ui
3. Hotspot fallback: "CameraBridge-Setup" / "setup123"

## Camera Setup

1. Configure camera SMB:
   - Server: [device-ip]
   - Share: photos
   - User: camera
   - Pass: camera123

2. Photos automatically sync to Dropbox

## Support

- Terminal diagnostics: `cb-ui`
- System logs: `cb-logs`
- Status check: `cb-status`
- Installation test: `./verify-installation.sh`
EOF

log "Final setup completed successfully!"
echo ""
echo "============================================="
echo "🎉 CAMERA BRIDGE SETUP COMPLETE"
echo "============================================="
echo ""
echo "Available Commands:"
echo "  cb-status    - Quick system status check"
echo "  cb-ui        - Full terminal interface"
echo "  cb-logs      - View recent logs"
echo "  cb-wifi      - WiFi management"
echo "  cb-temp      - CPU temperature (Pi only)"
echo ""
echo "Quick Start:"
echo "1. Install packages: sudo ./scripts/install-packages.sh"
echo "2. Open interface: cb-ui"
echo "3. Check status: cb-status"
echo ""
echo "For Raspberry Pi:"
echo "1. sudo ./raspberry-pi/scripts/install-rpi.sh"
echo "2. sudo ./raspberry-pi/scripts/setup-rpi.sh"
echo ""
echo "Verify installation: ./verify-installation.sh"
echo "Project ready for deployment!"