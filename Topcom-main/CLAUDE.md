# Camera Bridge Project - Claude Development Notes

## Project Overview

This is a complete camera bridge system that automatically syncs photos from cameras to cloud storage (Dropbox). The system primarily uses:

1. **Network SMB Mode**: Traditional network file sharing for cameras with WiFi

**Note**: USB Gadget Mode has been deprecated and is no longer in active use. The project now focuses solely on the original SMB network sharing approach.

## Key Features Implemented

### Core Functionality
- **Automatic Photo Sync**: Real-time monitoring and sync to Dropbox using rclone
- **Dual Mode Operation**: Switch between SMB network sharing and USB gadget modes
- **Web Interface**: Complete setup wizard and status dashboard
- **Terminal UI**: Advanced management interface with ncurses-style menus
- **WiFi Management**: Automatic hotspot fallback and network configuration
- **Seamless Boot Experience**: Auto-login, boot splash, and immediate UI access

### Hardware Support
- **Ubuntu/Debian Systems**: Full network SMB mode support
- **Raspberry Pi**: Optimized for Pi 4, Pi 3B+ compatibility
- **Pi Zero 2 W**: Specialized USB gadget mode for direct camera connection
- **Multi-platform**: Works across different Linux distributions

### Recent Major Development: USB Gadget Mode + Seamless Boot Experience

## Repository Information

- **GitHub Repository**: https://github.com/tomganleylee/Topcom
- **Branch**: feature/usb-gadget-mode (development), main (stable)
- **Language**: Bash scripts, PHP web interface, HTML/CSS/JavaScript
- **License**: Open source

## Development Commands for Claude

### Testing and Development
```bash
# Run linting (when available)
npm run lint || echo "No lint configuration found"

# Run type checking
npm run typecheck || echo "No typecheck configuration found"

# Test camera bridge service
sudo systemctl status camera-bridge

# Test terminal UI (primary interface)
sudo /usr/local/bin/terminal-ui

# Test seamless boot experience
sudo /usr/local/bin/camera-bridge-autostart
```

### Installation Commands
```bash
# Main installation (Ubuntu/Debian)
sudo ./scripts/install-packages.sh

# Pi Zero 2 W installation
cd raspberry-pi/pi-zero-2w
sudo ./scripts/install-pi-zero-2w.sh

# Enable seamless boot experience
sudo ./scripts/setup-auto-login.sh enable
sudo ./scripts/setup-boot-splash.sh enable
```

### Service Management
```bash
# Camera bridge service (primary service)
sudo systemctl start|stop|restart|status camera-bridge

# Manual sync
sudo /opt/camera-bridge/scripts/camera-bridge-service.sh sync-now

# Test Dropbox connection
sudo /opt/camera-bridge/scripts/camera-bridge-service.sh test-dropbox
```

### Log Monitoring
```bash
# Service logs
sudo journalctl -u camera-bridge -f

# Detailed logs
sudo tail -f /var/log/camera-bridge/service.log

# Setup logs
sudo tail -f /var/log/camera-bridge/setup.log

# Auto-start logs
sudo tail -f /var/log/camera-bridge/autostart.log
```

## File Structure

### Core Scripts
- `scripts/camera-bridge-service.sh` - Main SMB mode service (primary service)
- `scripts/terminal-ui.sh` - Terminal interface (primary UI)
- `scripts/wifi-manager.sh` - WiFi and hotspot management
- `scripts/install-packages.sh` - Main installation script

### Deprecated Scripts (USB Gadget Mode - No longer used)
- `scripts/camera-bridge-service-enhanced.sh` - Dual-mode service (deprecated)
- `scripts/terminal-ui-enhanced.sh` - Enhanced UI with mode switching (deprecated)

### USB Gadget Mode (Pi Zero 2 W) - DEPRECATED
- `raspberry-pi/pi-zero-2w/scripts/usb-gadget-manager.sh` - USB gadget configuration (deprecated)
- `raspberry-pi/pi-zero-2w/scripts/install-pi-zero-2w.sh` - Pi Zero 2 W installer (deprecated)
- `raspberry-pi/pi-zero-2w/USB-GADGET-MODE.md` - Complete documentation (deprecated)
- `raspberry-pi/pi-zero-2w/QUICK-START.md` - 5-minute setup guide (deprecated)

### Seamless Boot Experience
- `scripts/setup-auto-login.sh` - Auto-login configuration
- `scripts/setup-boot-splash.sh` - Custom boot splash screen
- `scripts/camera-bridge-autostart.sh` - Auto-start script with status display

### Web Interface
- `web/index.php` - Setup wizard
- `web/status.php` - Status dashboard
- `web/api/` - API endpoints for status and configuration

### Configuration
- `config/smb.conf` - Samba configuration template
- `config/nginx.conf` - Web server configuration
- `config/systemd/` - Service files

### Documentation
- `docs/INSTALLATION.md` - Detailed installation guide
- `docs/USB-GADGET-COMPARISON.md` - Mode comparison guide
- `docs/SEAMLESS-BOOT-EXPERIENCE.md` - Boot experience documentation
- `raspberry-pi/pi-zero-2w/README.md` - Pi Zero 2 W overview

## Development History

### Phase 1: Core Implementation
- Created basic SMB network sharing system
- Implemented Dropbox sync with rclone
- Built web interface with setup wizard
- Added terminal UI for management

### Phase 2: Raspberry Pi Optimization
- Added Pi-specific optimizations
- Created USB installer system
- Implemented WiFi management with hotspot fallback
- Added service monitoring and auto-restart

### Phase 3: USB Gadget Mode (Recent)
- Researched and implemented Pi Zero 2 W USB OTG support
- Created USB mass storage device emulation
- Built dual-mode service supporting both SMB and USB gadget
- Enhanced terminal UI with mode switching capabilities
- Added Pi Zero 2 W specific installation and configuration

### Phase 4: Seamless User Experience (Current)
- Implemented auto-login configuration for appliance-like behavior
- Created custom boot splash screen with Camera Bridge branding
- Built auto-start script with hardware detection and status display
- Added seamless boot experience to installation scripts
- Created comprehensive documentation for user experience

## Technical Architecture

### Network SMB Mode (Active)
```
Camera → WiFi → Samba Share → inotify → rclone → Dropbox
```

### USB Gadget Mode (DEPRECATED - No longer used)
```
Camera → USB-C → Pi Zero 2W → Mass Storage → inotify → rclone → Dropbox
```

### Boot Experience Flow
```
Power On → Boot Splash → Auto-Login → Status Display → Terminal UI
```

## Key Technologies Used

- **Linux USB Gadget Framework**: dwc2, libcomposite, configfs
- **File Monitoring**: inotify with inotifywait
- **Cloud Sync**: rclone with OAuth2 tokens
- **Network Sharing**: Samba (SMB/CIFS)
- **Web Server**: nginx with PHP
- **Service Management**: systemd
- **WiFi Management**: hostapd, dnsmasq, wpa_supplicant
- **Terminal UI**: bash with dialog-style menus
- **Boot Integration**: systemd services, getty auto-login

## Network Interface Architecture

### CRITICAL: Network Interface Rules

**eno1 (Primary Ethernet Interface):**
- **Purpose**: Primary interface for camera connectivity via ethernet cable
- **IP Address**: 192.168.10.1/24 (static)
- **DHCP Server**: ACTIVE - serves IPs 192.168.10.10-100
- **Required**: This interface MUST work at all times, regardless of WiFi status
- **Connected Devices**: Cameras, scanners, or other ethernet devices
- **Configuration**: `/etc/dnsmasq.d/camera-bridge.conf`

**wlan0 (External USB WiFi Adapter - OPTIONAL):**
- **Purpose**: WiFi hotspot for camera WiFi connectivity
- **Hardware**: RTL8812AU based USB WiFi adapter
- **IP Address**: 192.168.50.1/24 (when active)
- **DHCP Server**: SHOULD BE ACTIVE when USB adapter is plugged in - serves IPs 192.168.50.10-100
- **Optional**: System operates fully without this interface
- **SSID**: CameraBridge-Setup
- **Configuration**: Will need separate dnsmasq config file
- **Driver Location**: `/usr/src/rtl8812au-5.13.6-23`

**wlp1s0 (Internal Laptop WiFi - DO NOT USE):**
- **Purpose**: Internal laptop WiFi for external connectivity ONLY
- **NEVER use this interface for**:
  - DHCP server
  - WiFi hotspot (hostapd)
  - Camera connectivity
- **Reserved for**: Connecting to other networks, internet access
- **Critical Rule**: DO NOT configure hostapd or dnsmasq on this interface

### Dual DHCP Server Architecture

The system supports **two independent DHCP servers** running simultaneously:

1. **Ethernet DHCP** (eno1): 192.168.10.x network
2. **WiFi Hotspot DHCP** (wlan0): 192.168.50.x network

Both networks can access the Samba share at `/srv/samba/camera-share`

### Network Design Principles

1. **Ethernet-first design**: The system MUST operate fully on ethernet (eno1) even if USB WiFi adapter is not connected
2. **WiFi hotspot is optional**: USB WiFi provides convenience but is NOT required for core functionality
3. **Service resilience**: dnsmasq and hostapd must handle missing interfaces gracefully (no failures on boot)
4. **Never use internal WiFi**: wlp1s0 is off-limits for camera bridge operations

## Configuration Notes

### Important File Locations
- Service logs: `/var/log/camera-bridge/`
- Configuration: `/opt/camera-bridge/config/`
- Storage (USB gadget): `/opt/camera-bridge/storage/`
- Scripts: `/opt/camera-bridge/scripts/`
- Web interface: `/opt/camera-bridge/web/`
- rclone config: `/home/camerabridge/.config/rclone/`

### Default Settings
- SMB share: `/srv/samba/camera-share`
- Dropbox destination: `dropbox:Camera-Photos`
- USB storage size: 4GB (expandable)
- WiFi hotspot: `CameraBridge-Setup` / `setup123`
- Auto-login user: `camerabridge`

## Current Status

### Completed Features
- ✅ Core SMB network sharing
- ✅ Dropbox sync integration
- ✅ Web interface with setup wizard
- ✅ Terminal UI management
- ✅ WiFi management and hotspot
- ✅ USB gadget mode for Pi Zero 2 W
- ✅ Dual-mode operation (SMB + USB gadget)
- ✅ Enhanced terminal UI with mode switching
- ✅ Pi Zero 2 W specific installation
- ✅ Seamless boot experience (auto-login, boot splash, auto-start)
- ✅ Comprehensive documentation

### In Development
- 🔄 Web interface updates for mode selection
- 🔄 USB gadget functionality testing
- 🔄 Integration testing and refinement

### Future Enhancements
- Multiple cloud provider support (Google Drive, OneDrive)
- Camera-specific optimizations
- Mobile app for status monitoring
- Advanced photo organization features
- Backup and restore functionality

## Testing Notes

### USB Gadget Mode Testing
```bash
# Test on Pi Zero 2 W
sudo /usr/local/bin/usb-gadget-manager.sh setup
sudo /usr/local/bin/usb-gadget-manager.sh enable

# Connect via USB-C to computer
# Should appear as USB storage device
# Copy test images and verify Dropbox sync
```

### Seamless Boot Testing
```bash
# Install and reboot to test
sudo ./scripts/install-packages.sh
sudo reboot

# Should see:
# 1. Custom boot splash
# 2. Auto-login as camerabridge
# 3. Welcome banner with status
# 4. Terminal UI auto-start
```

### Network Mode Testing
```bash
# Configure WiFi and test SMB sharing
sudo ./scripts/wifi-manager.sh
# Test from camera or computer SMB client
```

## Troubleshooting Common Issues

### USB Gadget Issues
- Check kernel modules: `lsmod | grep dwc2`
- Verify USB-C cable supports data transfer
- Check configfs: `ls /sys/kernel/config/usb_gadget/`

### Auto-Login Issues
- Check getty service: `systemctl status getty@tty1`
- Verify configuration: `ls /etc/systemd/system/getty@tty1.service.d/`

### Service Issues
- Check status: `systemctl status camera-bridge`
- View logs: `journalctl -u camera-bridge -f`
- Test manually: `sudo /opt/camera-bridge/scripts/camera-bridge-service.sh start`

## Git Workflow

### Current Branch Status
- `main`: Stable releases
- `feature/usb-gadget-mode`: USB gadget and seamless boot development

### Commit Guidelines
- Use descriptive commit messages
- Include both technical changes and user-facing improvements
- Test functionality before committing
- Update documentation with code changes

This project represents a complete, production-ready camera bridge system with both traditional network sharing and innovative USB gadget modes, plus a seamless appliance-like user experience.