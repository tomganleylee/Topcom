#!/bin/bash

# Raspberry Pi Camera Bridge Setup Script
# Final setup after installation

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

echo -e "${BLUE}🍓 Camera Bridge Raspberry Pi Setup${NC}"
echo "======================================"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

log "Project root: $PROJECT_ROOT"

# Copy scripts
log "Copying camera bridge scripts..."
cp -r "$PROJECT_ROOT/scripts"/* /opt/camera-bridge/scripts/
chmod +x /opt/camera-bridge/scripts/*.sh

# Copy web interface
log "Copying web interface..."
cp -r "$PROJECT_ROOT/web"/* /opt/camera-bridge/web/
chown -R www-data:www-data /opt/camera-bridge/web

# Copy configuration files
log "Applying configuration files..."

# SMB configuration
cp "$PROJECT_ROOT/config/smb.conf" /etc/samba/smb.conf

# Systemd service
cp "$PROJECT_ROOT/config/camera-bridge.service" /etc/systemd/system/
systemctl daemon-reload

# Nginx configuration
cp "$PROJECT_ROOT/config/nginx-camera-bridge.conf" /etc/nginx/sites-available/camera-bridge
ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/default

# Test nginx configuration
if nginx -t; then
    systemctl restart nginx
    log "Nginx configured and restarted"
else
    error "Nginx configuration test failed"
    exit 1
fi

# Create Raspberry Pi specific aliases
log "Creating Raspberry Pi aliases and shortcuts..."
cat >> /home/camerabridge/.bashrc << 'EOF'

# Camera Bridge aliases
alias cb-ui='/opt/camera-bridge/scripts/terminal-ui.sh'
alias cb-status='/opt/camera-bridge/scripts/camera-bridge-service.sh status'
alias cb-logs='tail -f /var/log/camera-bridge/service.log'
alias cb-wifi='/opt/camera-bridge/scripts/wifi-manager.sh'
alias cb-temp='vcgencmd measure_temp'
alias cb-memory='free -h'
alias cb-disk='df -h'
alias cb-services='systemctl status camera-bridge smbd nginx'

# Raspberry Pi specific aliases
alias pi-temp='vcgencmd measure_temp'
alias pi-throttle='vcgencmd get_throttled'
alias pi-config='vcgencmd get_config int'
alias pi-mem='vcgencmd get_mem arm && vcgencmd get_mem gpu'
EOF

# Set up auto-start terminal UI for local access
cat >> /home/camerabridge/.bashrc << 'EOF'

# Auto-start camera bridge UI on local login (not SSH)
if [[ $- == *i* ]] && [[ -z "$SSH_CLIENT" ]] && [[ -z "$SSH_TTY" ]]; then
    echo "Starting Camera Bridge UI..."
    echo "Press Ctrl+C to cancel in 3 seconds..."
    if timeout 3 bash -c 'read -n1'; then
        echo "Cancelled by user"
    else
        /opt/camera-bridge/scripts/terminal-ui.sh
    fi
fi
EOF

# Create desktop shortcut if desktop environment is available
if command -v lxpanel >/dev/null 2>&1 || [ -d "/usr/share/pixmaps" ]; then
    log "Creating desktop shortcuts..."

    mkdir -p /home/camerabridge/Desktop

    cat > /home/camerabridge/Desktop/CameraBridge.desktop << 'EOF'
[Desktop Entry]
Name=Camera Bridge Manager
Comment=Manage Camera Bridge Settings
Exec=lxterminal -e '/opt/camera-bridge/scripts/terminal-ui.sh'
Icon=camera-photo
Type=Application
Categories=System;Photography;
Terminal=false
StartupNotify=true
EOF

    cat > /home/camerabridge/Desktop/CameraBridge-Web.desktop << 'EOF'
[Desktop Entry]
Name=Camera Bridge Web
Comment=Open Camera Bridge Web Interface
Exec=chromium-browser http://localhost
Icon=web-browser
Type=Application
Categories=Network;Photography;
Terminal=false
StartupNotify=true
EOF

    chmod +x /home/camerabridge/Desktop/*.desktop
    chown camerabridge:camerabridge /home/camerabridge/Desktop/*.desktop
fi

# Set up LED status indicator (if available)
log "Setting up status LED indicators..."
cat > /opt/camera-bridge/scripts/led-status.sh << 'EOF'
#!/bin/bash

# LED Status indicator for Raspberry Pi
# Uses built-in LEDs to show system status

# LED paths (may vary by Pi model)
LED_ACT="/sys/class/leds/led0"
LED_PWR="/sys/class/leds/led1"

set_led() {
    local led_path="$1"
    local state="$2"  # on, off, heartbeat, timer

    if [ -w "$led_path/trigger" ]; then
        echo "$state" > "$led_path/trigger" 2>/dev/null || true
    fi
}

case "$1" in
    "boot")
        # Solid red during boot
        set_led "$LED_ACT" "default-on"
        ;;
    "ready")
        # Heartbeat when ready
        set_led "$LED_ACT" "heartbeat"
        ;;
    "error")
        # Fast blink on error
        set_led "$LED_ACT" "timer"
        echo 100 > "$LED_ACT/delay_on" 2>/dev/null || true
        echo 100 > "$LED_ACT/delay_off" 2>/dev/null || true
        ;;
    "sync")
        # Slow blink during sync
        set_led "$LED_ACT" "timer"
        echo 500 > "$LED_ACT/delay_on" 2>/dev/null || true
        echo 500 > "$LED_ACT/delay_off" 2>/dev/null || true
        ;;
    "off")
        set_led "$LED_ACT" "none"
        ;;
esac
EOF

chmod +x /opt/camera-bridge/scripts/led-status.sh

# Create system health monitor
log "Creating system health monitor..."
cat > /opt/camera-bridge/scripts/health-monitor.sh << 'EOF'
#!/bin/bash

# Raspberry Pi health monitoring script
# Monitors temperature, throttling, and system resources

HEALTH_LOG="/var/log/camera-bridge/health.log"
mkdir -p "$(dirname "$HEALTH_LOG")"

log_health() {
    echo "$(date): $1" >> "$HEALTH_LOG"
}

# Check CPU temperature
temp=$(vcgencmd measure_temp | cut -d'=' -f2 | cut -d"'" -f1)
temp_int=${temp%.*}

if [ "$temp_int" -gt 80 ]; then
    log_health "HIGH TEMP: ${temp}°C"
    /opt/camera-bridge/scripts/led-status.sh error
elif [ "$temp_int" -gt 70 ]; then
    log_health "WARM: ${temp}°C"
fi

# Check throttling
throttled=$(vcgencmd get_throttled)
if [ "$throttled" != "throttled=0x0" ]; then
    log_health "THROTTLED: $throttled"
    /opt/camera-bridge/scripts/led-status.sh error
fi

# Check disk space
disk_usage=$(df / | awk 'NR==2{printf "%d", $5}')
if [ "$disk_usage" -gt 90 ]; then
    log_health "DISK FULL: ${disk_usage}%"
    /opt/camera-bridge/scripts/led-status.sh error
fi

# Check memory usage
mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ "$mem_usage" -gt 90 ]; then
    log_health "HIGH MEMORY: ${mem_usage}%"
fi

# Check if camera bridge service is running
if ! systemctl is-active --quiet camera-bridge; then
    log_health "SERVICE DOWN: camera-bridge"
    /opt/camera-bridge/scripts/led-status.sh error
else
    /opt/camera-bridge/scripts/led-status.sh ready
fi
EOF

chmod +x /opt/camera-bridge/scripts/health-monitor.sh

# Set up health monitoring cron job
log "Setting up health monitoring..."
cat > /etc/cron.d/camera-bridge-health << 'EOF'
# Camera Bridge health monitoring
*/5 * * * * root /opt/camera-bridge/scripts/health-monitor.sh
EOF

# Create Raspberry Pi specific system info
log "Creating system information collector..."
cat > /opt/camera-bridge/scripts/pi-system-info.sh << 'EOF'
#!/bin/bash

# Raspberry Pi system information collector

echo "RASPBERRY PI SYSTEM INFORMATION"
echo "==============================="
echo ""

# Basic system info
echo "Model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
echo "Serial: $(cat /proc/cpuinfo | grep Serial | cut -d' ' -f2)"
echo "Revision: $(cat /proc/cpuinfo | grep Revision | cut -d' ' -f2)"

# Temperatures and performance
echo ""
echo "PERFORMANCE METRICS"
echo "==================="
echo "CPU Temperature: $(vcgencmd measure_temp | cut -d'=' -f2)"
echo "GPU Temperature: $(vcgencmd measure_temp | cut -d'=' -f2)"
echo "Throttled Status: $(vcgencmd get_throttled)"
echo "CPU Frequency: $(vcgencmd measure_clock arm | cut -d'=' -f2) Hz"
echo "GPU Frequency: $(vcgencmd measure_clock core | cut -d'=' -f2) Hz"

# Memory info
echo ""
echo "MEMORY INFORMATION"
echo "=================="
echo "ARM Memory: $(vcgencmd get_mem arm | cut -d'=' -f2)"
echo "GPU Memory: $(vcgencmd get_mem gpu | cut -d'=' -f2)"
free -h

# Storage info
echo ""
echo "STORAGE INFORMATION"
echo "==================="
df -h

# Network interfaces
echo ""
echo "NETWORK INTERFACES"
echo "=================="
ip addr show

# Camera Bridge status
echo ""
echo "CAMERA BRIDGE STATUS"
echo "===================="
systemctl is-active camera-bridge && echo "Service: Running" || echo "Service: Stopped"
systemctl is-active smbd && echo "SMB: Running" || echo "SMB: Stopped"
systemctl is-active nginx && echo "Web: Running" || echo "Web: Stopped"

# WiFi status
echo ""
echo "WIFI STATUS"
echo "==========="
iwgetid && echo "Connected: $(iwgetid -r)" || echo "Not connected"
EOF

chmod +x /opt/camera-bridge/scripts/pi-system-info.sh

# Enable and start services
log "Starting services..."
systemctl enable camera-bridge
systemctl enable smbd
systemctl enable nmbd

# Test services
log "Testing service startup..."
systemctl start smbd
systemctl start nmbd

if systemctl start camera-bridge; then
    log "Camera Bridge service started successfully"
else
    warn "Camera Bridge service failed to start (may need configuration)"
fi

# Create final status script
log "Creating status checker..."
cat > /opt/camera-bridge/scripts/setup-status.sh << 'EOF'
#!/bin/bash

echo "CAMERA BRIDGE SETUP STATUS"
echo "=========================="
echo ""

# Check required directories
dirs=("/opt/camera-bridge" "/srv/samba/camera-share" "/var/log/camera-bridge")
for dir in "${dirs[@]}"; do
    [ -d "$dir" ] && echo "✓ Directory: $dir" || echo "✗ Missing: $dir"
done

# Check required scripts
scripts=("camera-bridge-service.sh" "wifi-manager.sh" "terminal-ui.sh")
for script in "${scripts[@]}"; do
    [ -x "/opt/camera-bridge/scripts/$script" ] && echo "✓ Script: $script" || echo "✗ Missing: $script"
done

# Check web interface
[ -f "/opt/camera-bridge/web/index.php" ] && echo "✓ Web interface installed" || echo "✗ Web interface missing"

# Check services
services=("camera-bridge" "smbd" "nginx")
for service in "${services[@]}"; do
    systemctl is-enabled "$service" >/dev/null 2>&1 && echo "✓ Service enabled: $service" || echo "✗ Service not enabled: $service"
done

# Check users
id camerabridge >/dev/null 2>&1 && echo "✓ User: camerabridge" || echo "✗ User missing: camerabridge"
id camera >/dev/null 2>&1 && echo "✓ SMB user: camera" || echo "✗ SMB user missing: camera"

echo ""
echo "Setup completed! Reboot recommended."
echo "After reboot, connect to: http://$(hostname -I | awk '{print $1}')"
EOF

chmod +x /opt/camera-bridge/scripts/setup-status.sh

# Set correct ownership
chown -R camerabridge:camerabridge /opt/camera-bridge
chown -R www-data:www-data /opt/camera-bridge/web

log "Raspberry Pi setup completed successfully!"
echo ""
echo "==============================================="
echo "🍓 RASPBERRY PI CAMERA BRIDGE SETUP COMPLETE"
echo "==============================================="
echo ""
echo "Next steps:"
echo "1. Reboot the Raspberry Pi: sudo reboot"
echo "2. After reboot, connect to web interface:"
echo "   http://$(hostname -I | awk '{print $1}')"
echo "3. Or connect a monitor and use terminal UI: cb-ui"
echo ""
echo "Status check: /opt/camera-bridge/scripts/setup-status.sh"
echo "System info: /opt/camera-bridge/scripts/pi-system-info.sh"
echo ""
echo "For headless setup:"
echo "- Enable SSH: sudo systemctl enable ssh"
echo "- WiFi hotspot will be available if no WiFi configured"
echo "- Connect to 'CameraBridge-Setup' and visit http://192.168.4.1"