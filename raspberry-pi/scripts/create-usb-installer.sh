#!/bin/bash

# Camera Bridge USB Installer Creator
# Creates a bootable USB drive with Camera Bridge auto-installer for Raspberry Pi

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

echo -e "${BLUE}🍓 Camera Bridge USB Installer Creator${NC}"
echo "========================================"

# Check dependencies
if ! command -v parted >/dev/null 2>&1; then
    error "parted is required but not installed"
    exit 1
fi

if ! command -v mkfs.fat >/dev/null 2>&1; then
    error "dosfstools is required but not installed"
    exit 1
fi

# Get USB device
if [ -z "$1" ]; then
    echo "Available USB devices:"
    lsblk | grep -E "sd[b-z]" | grep -v part
    echo ""
    echo "Usage: $0 /dev/sdX"
    echo "Example: $0 /dev/sdb"
    exit 1
fi

USB_DEVICE="$1"

if [ ! -b "$USB_DEVICE" ]; then
    error "Device $USB_DEVICE does not exist or is not a block device"
    exit 1
fi

# Safety check
if [[ "$USB_DEVICE" == "/dev/sda" ]] || [[ "$USB_DEVICE" == *"mmcblk"* ]]; then
    error "Refusing to use $USB_DEVICE - this might be your system drive!"
    exit 1
fi

# Get device info
DEVICE_SIZE=$(lsblk -b -n -o SIZE "$USB_DEVICE" | head -1)
DEVICE_SIZE_GB=$((DEVICE_SIZE / 1024 / 1024 / 1024))

log "Target device: $USB_DEVICE"
log "Device size: ${DEVICE_SIZE_GB}GB"

if [ "$DEVICE_SIZE_GB" -lt 2 ]; then
    error "USB device too small. Need at least 2GB."
    exit 1
fi

# Warning and confirmation
warn "This will COMPLETELY ERASE $USB_DEVICE and all its data!"
echo "Device info:"
lsblk "$USB_DEVICE"
echo ""
read -p "Are you sure you want to continue? Type 'yes' to proceed: " confirm

if [ "$confirm" != "yes" ]; then
    log "Operation cancelled"
    exit 0
fi

# Unmount any existing partitions
log "Unmounting any existing partitions..."
umount "${USB_DEVICE}"* 2>/dev/null || true

# Create new partition table and partition
log "Creating new partition table..."
parted -s "$USB_DEVICE" mklabel msdos
parted -s "$USB_DEVICE" mkpart primary fat32 1MiB 100%
parted -s "$USB_DEVICE" set 1 boot on

# Format partition
PARTITION="${USB_DEVICE}1"
if [[ "$USB_DEVICE" == *"mmcblk"* ]]; then
    PARTITION="${USB_DEVICE}p1"
fi

log "Formatting partition as FAT32..."
mkfs.fat -F32 -n "CAMERA-BRIDGE" "$PARTITION"

# Mount partition
MOUNT_POINT="/mnt/camera-bridge-usb"
mkdir -p "$MOUNT_POINT"
mount "$PARTITION" "$MOUNT_POINT"

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

log "Copying Camera Bridge files to USB drive..."

# Create directory structure
mkdir -p "$MOUNT_POINT"/{camera-bridge,boot-scripts,docs}

# Copy all project files
cp -r "$PROJECT_ROOT"/* "$MOUNT_POINT/camera-bridge/"

# Create auto-installer script
log "Creating auto-installer..."
cat > "$MOUNT_POINT/install.sh" << 'EOF'
#!/bin/bash

# Camera Bridge Auto-Installer
# Run this on a fresh Raspberry Pi OS installation

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

# Get USB mount point
USB_MOUNT=$(findmnt -n -o TARGET -T "$0" | head -1)
CAMERA_BRIDGE_DIR="$USB_MOUNT/camera-bridge"

if [ ! -d "$CAMERA_BRIDGE_DIR" ]; then
    error "Camera Bridge files not found. Please run this script from the USB drive."
    exit 1
fi

echo -e "${BLUE}🍓 Camera Bridge Auto-Installer${NC}"
echo "================================"
log "Installing from: $USB_MOUNT"
log "Camera Bridge source: $CAMERA_BRIDGE_DIR"

# Run Raspberry Pi installation
if [ -f "$CAMERA_BRIDGE_DIR/raspberry-pi/scripts/install-rpi.sh" ]; then
    log "Running Raspberry Pi installation..."
    bash "$CAMERA_BRIDGE_DIR/raspberry-pi/scripts/install-rpi.sh"
else
    error "Raspberry Pi installation script not found"
    exit 1
fi

# Run setup
if [ -f "$CAMERA_BRIDGE_DIR/raspberry-pi/scripts/setup-rpi.sh" ]; then
    log "Running Raspberry Pi setup..."
    SCRIPT_DIR="$CAMERA_BRIDGE_DIR/raspberry-pi/scripts"
    bash "$CAMERA_BRIDGE_DIR/raspberry-pi/scripts/setup-rpi.sh"
else
    error "Raspberry Pi setup script not found"
    exit 1
fi

log "Installation completed!"
log "Reboot recommended: sudo reboot"
EOF

chmod +x "$MOUNT_POINT/install.sh"

# Create quick setup script
cat > "$MOUNT_POINT/quick-setup.sh" << 'EOF'
#!/bin/bash

# Quick Camera Bridge Setup
# For users who want minimal interaction

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./quick-setup.sh"
    exit 1
fi

echo "🍓 Camera Bridge Quick Setup"
echo "============================="

# Get current directory (USB mount)
USB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Update system
echo "Updating system packages..."
apt update && apt upgrade -y

# Run main installation
echo "Running main installation..."
bash "$USB_DIR/install.sh"

echo ""
echo "Quick setup complete!"
echo "The system will reboot in 10 seconds..."
echo "Press Ctrl+C to cancel reboot"

if timeout 10 bash -c 'read -n1'; then
    echo "Reboot cancelled"
else
    reboot
fi
EOF

chmod +x "$MOUNT_POINT/quick-setup.sh"

# Create README
cat > "$MOUNT_POINT/README.txt" << 'EOF'
Camera Bridge USB Installer
===========================

This USB drive contains everything needed to set up a Camera Bridge
on your Raspberry Pi.

Quick Start:
1. Insert this USB drive into your Raspberry Pi
2. Open terminal and run: sudo ./quick-setup.sh
3. Wait for installation to complete
4. System will reboot automatically
5. Connect to http://[pi-ip-address] for setup

Manual Installation:
1. Run: sudo ./install.sh
2. Follow the prompts
3. Reboot when complete

What is Camera Bridge?
- Automatically syncs camera photos to Dropbox
- Provides SMB network share for cameras
- Web interface for easy setup
- Terminal interface for advanced management
- Optimized for Raspberry Pi

Requirements:
- Raspberry Pi 4 or newer (3B+ may work)
- 8GB+ SD card
- Internet connection for setup
- Dropbox account (free works)

Support:
- Check the docs/ folder for detailed instructions
- Use the terminal interface for troubleshooting
- View logs at /var/log/camera-bridge/

Network Setup:
- Ethernet: Plug in cable, should work automatically
- WiFi: Connect via web interface or hotspot mode
- Hotspot: "CameraBridge-Setup" password "setup123"

Camera Setup:
- Connect camera via Ethernet to Pi
- Configure camera to use SMB share: \\[pi-ip]\photos
- SMB credentials: username "camera" password "camera123"

Files will automatically sync to Dropbox folder:
/Apps/CameraBridge/

Enjoy your automated photo workflow!
EOF

# Create docs folder with additional documentation
mkdir -p "$MOUNT_POINT/docs"

cat > "$MOUNT_POINT/docs/INSTALLATION.md" << 'EOF'
# Camera Bridge Installation Guide

## Overview
Camera Bridge is an automated photo sync system designed for professional photographers who need reliable, automatic backup of their photos from cameras to cloud storage.

## System Requirements

### Hardware
- Raspberry Pi 4 (4GB+ recommended, 2GB minimum)
- MicroSD card (16GB+ recommended, 8GB minimum)
- Ethernet cable
- WiFi capability
- Camera with network/SMB capability

### Software
- Raspberry Pi OS (32-bit or 64-bit)
- Internet connection for initial setup

## Installation Methods

### Method 1: USB Auto-Installer (Recommended)
1. Insert USB drive into Raspberry Pi
2. Open terminal: `sudo ./quick-setup.sh`
3. Wait for installation (15-30 minutes)
4. System will reboot automatically

### Method 2: Manual Installation
1. Run: `sudo ./install.sh`
2. Follow prompts and make selections
3. Reboot when prompted

### Method 3: Step-by-Step Installation
1. Copy files: `sudo cp -r camera-bridge /opt/`
2. Run: `sudo /opt/camera-bridge/raspberry-pi/scripts/install-rpi.sh`
3. Run: `sudo /opt/camera-bridge/raspberry-pi/scripts/setup-rpi.sh`
4. Reboot: `sudo reboot`

## Post-Installation Setup

### 1. Network Configuration
- **Ethernet**: Should work automatically
- **WiFi**: Use web interface at http://[pi-ip]/
- **Hotspot Mode**: Connect to "CameraBridge-Setup" (password: setup123)

### 2. Dropbox Setup
1. Go to https://dropbox.com/developers/apps
2. Create new app → Scoped access → App folder
3. Generate access token
4. Enter token in web interface

### 3. Camera Configuration
1. Connect camera via Ethernet
2. Configure camera SMB settings:
   - Server: Pi IP address
   - Share: `photos`
   - Username: `camera`
   - Password: `camera123`

## Troubleshooting

### Installation Issues
- Ensure sufficient disk space (2GB+ free)
- Check internet connection
- Try running individual scripts manually

### Network Issues
- Check cables and connections
- Use `cb-wifi status` for WiFi diagnosis
- Reset network: `sudo /opt/camera-bridge/scripts/wifi-manager.sh reset`

### Service Issues
- Check status: `cb-status`
- View logs: `cb-logs`
- Restart services: `sudo systemctl restart camera-bridge`

### Performance Issues
- Check temperature: `cb-temp`
- Monitor resources: `cb-memory`, `cb-disk`
- Consider SD card optimization

## Management Interfaces

### Web Interface
- URL: `http://[pi-ip-address]`
- Features: Setup, status, configuration
- Mobile-friendly design

### Terminal Interface
- Command: `cb-ui` (or `/opt/camera-bridge/scripts/terminal-ui.sh`)
- Features: Full system management
- Works over SSH

### Command Line Tools
- `cb-status`: Service status
- `cb-logs`: View logs
- `cb-wifi`: WiFi management
- `cb-temp`: Temperature monitoring

## File Locations

### Configuration
- `/opt/camera-bridge/`: Main installation
- `/etc/samba/smb.conf`: SMB configuration
- `/home/camerabridge/.config/rclone/`: Dropbox configuration

### Data
- `/srv/samba/camera-share/`: Camera photos
- `/var/log/camera-bridge/`: Log files

### Services
- `camera-bridge.service`: Main sync service
- `smbd.service`: SMB file sharing
- `nginx.service`: Web interface

## Security Considerations

### Network Security
- Change default SMB password
- Use strong WiFi passwords
- Consider VPN for remote access
- Firewall configuration if needed

### Data Security
- Photos stored locally until synced
- Dropbox uses app-folder access (limited scope)
- Logs may contain filenames
- Consider encryption for sensitive content

## Backup and Recovery

### System Backup
- SD card image backup recommended
- Configuration files in `/opt/camera-bridge/config/`
- Dropbox credentials in `/home/camerabridge/.config/rclone/`

### Recovery Procedures
- Reinstall from USB if system corrupted
- Restore configuration files
- Reconfigure Dropbox authentication

## Performance Optimization

### SD Card Longevity
- Use high-quality SD card (Class 10, A1 rated)
- Enable log rotation
- Consider moving logs to USB storage
- Run: `/opt/camera-bridge/scripts/sd-card-maintenance.sh`

### Network Performance
- Use Ethernet for cameras when possible
- Position Pi for good WiFi signal
- Consider USB Ethernet adapters for multiple cameras

### Storage Management
- Monitor disk usage regularly
- Set up automatic cleanup if needed
- Consider external USB storage for large volumes

## Advanced Configuration

### Multiple Cameras
- Each camera can use same SMB share
- Organize by folders in camera settings
- Monitor bandwidth usage

### Custom Sync Rules
- Edit rclone configuration for custom filters
- Set up multiple Dropbox destinations
- Configure sync scheduling

### Integration with Other Services
- Webhook notifications
- Integration with photo management software
- Automated workflows with APIs

For more help, use the terminal interface or check the logs for specific error messages.
EOF

cat > "$MOUNT_POINT/docs/TROUBLESHOOTING.md" << 'EOF'
# Camera Bridge Troubleshooting Guide

## Common Issues and Solutions

### Installation Problems

#### "Insufficient disk space"
- **Cause**: SD card too small or full
- **Solution**: Use 16GB+ SD card, clean up unnecessary files
- **Check**: `df -h` to see disk usage

#### "Package installation failed"
- **Cause**: Network issues or corrupted packages
- **Solution**:
  1. Check internet: `ping google.com`
  2. Update package lists: `sudo apt update`
  3. Fix broken packages: `sudo apt --fix-broken install`

#### "Permission denied" errors
- **Cause**: Not running as root
- **Solution**: Use `sudo` with installation commands
- **Example**: `sudo ./install.sh`

### Network Issues

#### WiFi won't connect
- **Check signal strength**: `iwconfig wlan0`
- **Scan networks**: `sudo /opt/camera-bridge/scripts/wifi-manager.sh scan`
- **Reset WiFi**: `sudo /opt/camera-bridge/scripts/wifi-manager.sh reset`
- **Check password**: Try manual connection

#### Hotspot mode not working
- **Check interface**: `ip link show wlan0`
- **Restart services**: `sudo systemctl restart hostapd dnsmasq`
- **Check configuration**: `/etc/hostapd/hostapd.conf`

#### Can't access web interface
- **Check nginx**: `sudo systemctl status nginx`
- **Check IP address**: `hostname -I`
- **Check firewall**: `sudo ufw status` (if enabled)
- **Try different port**: May be blocked by network

### Service Issues

#### Camera Bridge service won't start
- **Check status**: `sudo systemctl status camera-bridge`
- **View logs**: `tail -f /var/log/camera-bridge/service.log`
- **Check dependencies**: Ensure SMB share exists
- **Manual start**: `sudo /opt/camera-bridge/scripts/camera-bridge-service.sh start`

#### SMB sharing not working
- **Check service**: `sudo systemctl status smbd`
- **Test locally**: `smbclient -L localhost -U camera`
- **Check permissions**: `ls -la /srv/samba/camera-share`
- **Reset SMB password**: `sudo smbpasswd camera`

#### Dropbox sync failing
- **Test connection**: `sudo -u camerabridge rclone lsd dropbox:`
- **Check token**: May have expired, regenerate
- **View sync logs**: `grep -i dropbox /var/log/camera-bridge/service.log`
- **Manual sync test**: `sudo -u camerabridge rclone ls dropbox:`

### Performance Issues

#### System running slow
- **Check temperature**: `vcgencmd measure_temp`
- **Check throttling**: `vcgencmd get_throttled`
- **Monitor resources**: `htop` or `top`
- **Check SD card health**: May be failing

#### High CPU temperature
- **Immediate**: Ensure good ventilation
- **Check workload**: `htop` - identify heavy processes
- **Consider cooling**: Fan or heatsink
- **Reduce load**: Limit concurrent operations

#### Out of memory errors
- **Check usage**: `free -h`
- **Add swap**: If less than 1GB RAM
- **Restart services**: `sudo systemctl restart camera-bridge`
- **Check for memory leaks**: Monitor over time

### Camera Connection Issues

#### Camera can't connect to SMB share
- **Check network**: Camera and Pi on same network
- **Test SMB access**: From another computer
- **Check credentials**: Username "camera", password "camera123"
- **Check share path**: `\\[pi-ip]\photos`

#### Photos not syncing
- **Check file formats**: Ensure supported formats
- **Check permissions**: Files must be readable
- **Monitor logs**: `tail -f /var/log/camera-bridge/service.log`
- **Manual test**: Copy file manually to share

#### Slow photo transfer
- **Check network speed**: Between camera and Pi
- **Monitor bandwidth**: `iftop` or similar
- **Check SD card speed**: May be bottleneck
- **Consider wired connection**: More stable than WiFi

## Diagnostic Commands

### System Health
```bash
# Overall system status
cb-status

# Temperature monitoring
cb-temp
vcgencmd measure_temp

# Memory usage
free -h
cb-memory

# Disk usage
df -h
cb-disk

# System load
uptime
htop
```

### Network Diagnostics
```bash
# WiFi status
cb-wifi status

# Network interfaces
ip addr show

# Network connectivity
ping google.com
ping 8.8.8.8

# DNS resolution
nslookup google.com
```

### Service Diagnostics
```bash
# Service status
systemctl status camera-bridge
systemctl status smbd
systemctl status nginx

# Service logs
journalctl -u camera-bridge -f
journalctl -u smbd -n 50

# Camera Bridge logs
tail -f /var/log/camera-bridge/service.log
```

### Dropbox Diagnostics
```bash
# Test Dropbox connection
sudo -u camerabridge rclone lsd dropbox:

# List files
sudo -u camerabridge rclone ls dropbox:

# Check configuration
cat /home/camerabridge/.config/rclone/rclone.conf

# Manual sync test
sudo -u camerabridge rclone copy /srv/samba/camera-share/test.jpg dropbox: -v
```

## Recovery Procedures

### Service Recovery
```bash
# Restart all services
sudo systemctl restart camera-bridge smbd nginx

# Reload configuration
sudo systemctl daemon-reload

# Reset to defaults
sudo /opt/camera-bridge/scripts/wifi-manager.sh reset
```

### Configuration Recovery
```bash
# Restore SMB configuration
sudo cp /opt/camera-bridge/config/smb.conf /etc/samba/smb.conf

# Restore nginx configuration
sudo cp /opt/camera-bridge/config/nginx-camera-bridge.conf /etc/nginx/sites-available/camera-bridge
```

### Complete Reset
```bash
# Stop all services
sudo systemctl stop camera-bridge smbd nginx

# Remove configuration
sudo rm -rf /home/camerabridge/.config/rclone/
sudo rm -f /etc/wpa_supplicant/wpa_supplicant.conf

# Restart setup wizard
# Then access web interface to reconfigure
```

## Getting Help

### Log Collection
Before asking for help, collect these logs:
```bash
# System logs
sudo journalctl > system.log

# Service logs
sudo systemctl status camera-bridge > service-status.log
cat /var/log/camera-bridge/service.log > camera-bridge.log

# Network status
ip addr show > network-status.log
iwconfig > wifi-status.log

# System info
/opt/camera-bridge/scripts/pi-system-info.sh > system-info.log
```

### Support Channels
- Check documentation in `/opt/camera-bridge/docs/`
- Use terminal interface diagnostics: `cb-ui`
- View system logs for specific error messages
- GitHub issues (if available)

### Emergency Recovery
If system becomes unresponsive:
1. Reboot: `sudo reboot`
2. Safe mode: Hold Shift during boot
3. Reinstall: Use USB installer again
4. SD card recovery: Re-image with backup

Remember: Most issues can be resolved by checking logs and following the error messages. Take time to read error messages carefully before trying solutions.
EOF

# Create a boot configuration for auto-start (optional)
cat > "$MOUNT_POINT/boot-scripts/auto-install.sh" << 'EOF'
#!/bin/bash

# Auto-install script that can be placed in /boot/
# Runs automatically on first boot if placed correctly

# This is a template - actual implementation depends on boot setup
echo "Camera Bridge auto-install triggered"

# Find USB mount point
USB_MOUNT="/media/pi/CAMERA-BRIDGE"
if [ ! -d "$USB_MOUNT" ]; then
    # Try alternative mount points
    USB_MOUNT=$(findmnt -n -o TARGET LABEL=CAMERA-BRIDGE | head -1)
fi

if [ -d "$USB_MOUNT" ]; then
    cd "$USB_MOUNT"
    sudo ./quick-setup.sh
else
    echo "Camera Bridge USB drive not found"
fi
EOF

chmod +x "$MOUNT_POINT/boot-scripts/auto-install.sh"

# Create version info
cat > "$MOUNT_POINT/VERSION" << 'EOF'
Camera Bridge USB Installer
Version: 1.0
Created: $(date)
Compatible: Raspberry Pi OS (32-bit/64-bit)
Minimum Pi: Raspberry Pi 4 (3B+ may work)
EOF

# Sync and unmount
log "Finalizing USB drive..."
sync
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

log "USB installer created successfully!"
echo ""
echo "============================================"
echo "🍓 CAMERA BRIDGE USB INSTALLER READY"
echo "============================================"
echo ""
echo "USB Device: $USB_DEVICE"
echo "Label: CAMERA-BRIDGE"
echo "Size: ${DEVICE_SIZE_GB}GB"
echo ""
echo "Usage Instructions:"
echo "1. Insert USB drive into Raspberry Pi"
echo "2. Mount drive and navigate to it"
echo "3. Run: sudo ./quick-setup.sh"
echo "4. Wait for installation to complete"
echo "5. System will reboot automatically"
echo ""
echo "Alternative methods:"
echo "- Manual: sudo ./install.sh"
echo "- Read: README.txt for detailed instructions"
echo ""
echo "The USB drive is now ready for deployment!"