# Seamless Boot Experience Documentation

## Overview

The Camera Bridge system provides a seamless, appliance-like boot experience that automatically displays the management interface without requiring user interaction. This creates an embedded device experience perfect for photography workflows.

## Features

### 1. Custom Boot Splash Screen
- **Visual Branding**: Camera Bridge ASCII art logo
- **Hardware Detection**: Displays detected hardware (Pi Zero 2W, Raspberry Pi, etc.)
- **Service Status**: Shows initialization progress with animations
- **Color Coded**: Status indicators with green/yellow/red colors

### 2. Auto-Login Configuration
- **Passwordless Login**: Automatic console login as `camerabridge` user
- **Multi-Platform**: Works on Raspberry Pi OS, Ubuntu, and Debian
- **TTY1 Focus**: Uses primary console for seamless experience
- **SSH Aware**: Only activates on local console, not SSH sessions

### 3. Terminal UI Auto-Start
- **Hardware Detection**: Automatically detects Pi Zero 2W vs other hardware
- **Status Display**: Shows internet, Dropbox, and service status
- **Mode Guidance**: Provides quick-start instructions for detected hardware
- **Graceful Restart**: Easy restart/exit options

### 4. User Experience Flow

```
Power On → Boot Splash → Auto-Login → Status Display → Terminal UI
```

## Implementation Details

### Boot Splash Service
**File**: `/etc/systemd/system/camera-bridge-splash.service`
**Script**: `/usr/local/bin/camera-bridge-splash`

```bash
# View splash service status
sudo systemctl status camera-bridge-splash

# Enable/disable splash
sudo /opt/camera-bridge/scripts/setup-boot-splash.sh enable
sudo /opt/camera-bridge/scripts/setup-boot-splash.sh disable
```

### Auto-Login Configuration
**File**: `/etc/systemd/system/getty@tty1.service.d/autologin.conf`
**User Profile**: `/home/camerabridge/.profile`

```bash
# Configure auto-login
sudo /opt/camera-bridge/scripts/setup-auto-login.sh enable

# Check status
sudo /opt/camera-bridge/scripts/setup-auto-login.sh status
```

### Auto-Start Script
**File**: `/usr/local/bin/camera-bridge-autostart`
**Control**: `/opt/camera-bridge/config/autostart-enabled`

```bash
# Manual start
/usr/local/bin/camera-bridge-autostart

# Disable auto-start
sudo rm /opt/camera-bridge/config/autostart-enabled
```

## User Experience Elements

### Welcome Banner Display
```
████████████████████████████████████████████████████████████████████████
██                                                                    ██
██    ███████   █████  ██     ██ ███████ ██████   █████      ██████   ██
██   ██    ██  ██   ██ ███   ███ ██      ██   ██ ██   ██     ██   ██  ██
██   ██        ██   ██ ████ ████ █████   ██████  ███████     ██████   ██
██   ██    ██  ██   ██ ██ ███ ██ ██      ██   ██ ██   ██     ██   ██  ██
██    ███████   █████  ██     ██ ███████ ██   ██ ██   ██     ██████   ██
██                                                                    ██
██                     ██████  ██████  ██ ██████   ██████ ███████     ██
██                     ██   ██ ██   ██ ██ ██   ██ ██      ██          ██
██                     ██████  ██████  ██ ██   ██ ██   ██ █████       ██
██                     ██   ██ ██   ██ ██ ██   ██ ██    ██ ██          ██
██                     ██████  ██   ██ ██ ██████   ██████  ███████     ██
██                                                                    ██
████████████████████████████████████████████████████████████████████████

              Automatic Photo Sync to Cloud Storage

🔌 Pi Zero 2 W detected - USB Gadget Mode available

System Status:
   ✅ Internet connection: Connected
   ✅ Dropbox: Configured and accessible
   ✅ Camera Bridge Service: Running
```

### Hardware-Specific Instructions

#### Pi Zero 2 W Detection
```
USB Gadget Mode (Recommended for Pi Zero 2 W):
  1. Enable USB gadget: sudo /usr/local/bin/usb-gadget-manager.sh enable
  2. Connect to camera via USB-C cable
  3. Camera will see this device as USB storage
  4. Photos will automatically sync to Dropbox

Network Mode (Alternative):
  1. Configure WiFi in terminal UI
  2. Set up camera to connect to WiFi network
  3. Configure camera to use SMB share
```

#### Standard Hardware Detection
```
Network SMB Mode:
  1. Configure WiFi/Ethernet connection
  2. Set up camera to connect to same network
  3. Configure camera to save to SMB share
  4. Photos will automatically sync to Dropbox
```

### Status Indicators

| Icon | Meaning | Description |
|------|---------|-------------|
| ✅ | Success | Service/feature working correctly |
| ⚠️ | Warning | Service available but not optimal |
| ❌ | Error | Service not working or not configured |

### Interactive Elements
- **10-second timeout**: Auto-proceeds to Terminal UI
- **'q' to exit**: Quick exit to shell option
- **Restart options**: Easy restart after UI exit

## Configuration Files

### Auto-Start Control
```bash
# Enable auto-start
sudo touch /opt/camera-bridge/config/autostart-enabled

# Disable auto-start
sudo rm /opt/camera-bridge/config/autostart-enabled

# Check status
ls -la /opt/camera-bridge/config/autostart-enabled
```

### User Profile Integration
The system integrates with `.profile` to detect console sessions:

```bash
# Auto-start only on TTY1 (local console)
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    if [ -f /opt/camera-bridge/config/autostart-enabled ]; then
        /usr/local/bin/camera-bridge-autostart
    fi
fi
```

## Installation

### Automatic (Included in main installation)
```bash
# Pi Zero 2W
cd raspberry-pi/pi-zero-2w
sudo ./scripts/install-pi-zero-2w.sh

# Standard installation
sudo ./scripts/install-packages.sh
```

### Manual Setup
```bash
# Enable boot splash
sudo ./scripts/setup-boot-splash.sh enable

# Enable auto-login
sudo ./scripts/setup-auto-login.sh enable

# Create symlink for autostart script
sudo ln -sf /opt/camera-bridge/scripts/camera-bridge-autostart.sh /usr/local/bin/camera-bridge-autostart
```

## Troubleshooting

### Boot Splash Not Appearing
```bash
# Check service status
sudo systemctl status camera-bridge-splash

# Check service file
ls -la /etc/systemd/system/camera-bridge-splash.service

# Manually run splash
sudo /usr/local/bin/camera-bridge-splash
```

### Auto-Login Not Working
```bash
# Check getty configuration
ls -la /etc/systemd/system/getty@tty1.service.d/

# Check user profile
grep -A 10 "camera-bridge-autostart" /home/camerabridge/.profile

# Test manual login
sudo -u camerabridge bash -l
```

### Terminal UI Not Auto-Starting
```bash
# Check autostart control file
ls -la /opt/camera-bridge/config/autostart-enabled

# Test autostart script
sudo -u camerabridge /usr/local/bin/camera-bridge-autostart

# Check TTY detection
tty
echo "SSH_CLIENT: $SSH_CLIENT"
echo "SSH_TTY: $SSH_TTY"
```

### Plymouth Integration (Advanced)
For systems with plymouth boot splash support:

```bash
# Check plymouth theme
sudo plymouth-set-default-theme --list

# Install camera-bridge theme
sudo update-initramfs -u

# Test plymouth
sudo plymouthd --debug --debug-file=/tmp/plymouth.debug
sudo plymouth --show-splash
```

## Customization

### Modify Boot Splash
Edit `/usr/local/bin/camera-bridge-splash` to customize:
- ASCII art logo
- Color scheme
- Status messages
- Hardware detection logic

### Change Auto-Login User
Edit auto-login configuration:
```bash
# Change user in getty service
sudo nano /etc/systemd/system/getty@tty1.service.d/autologin.conf

# Update USER variable in setup script
sudo nano /opt/camera-bridge/scripts/setup-auto-login.sh
```

### Customize Welcome Messages
Edit `/opt/camera-bridge/scripts/camera-bridge-autostart.sh`:
- Welcome banner text
- Hardware-specific instructions
- Status check logic
- Interactive prompts

## Security Considerations

### Auto-Login Security
- **Physical Access**: Auto-login grants immediate console access
- **SSH Protection**: Auto-login only applies to local console (TTY1)
- **User Privileges**: `camerabridge` user has limited sudo permissions
- **Service Isolation**: Camera bridge runs in isolated service context

### Recommendations
1. **Physical Security**: Secure device in locked enclosure
2. **Network Security**: Use strong WiFi passwords
3. **SSH Keys**: Use key-based SSH authentication
4. **Firewall**: Configure iptables for required ports only

### Disable Auto-Login
For enhanced security, disable auto-login:
```bash
sudo /opt/camera-bridge/scripts/setup-auto-login.sh disable
```

## Performance Impact

### Boot Time
- **Boot Splash**: Adds ~2-3 seconds to boot time
- **Auto-Login**: Minimal impact (<1 second)
- **Status Checks**: ~1-2 seconds for connectivity tests

### Resource Usage
- **Memory**: <10MB additional RAM usage
- **CPU**: Minimal ongoing CPU impact
- **Storage**: ~50KB of additional scripts and configs

### Optimization Tips
1. Use fast SD cards (Class 10, U3)
2. Reduce boot services if not needed
3. Consider read-only root filesystem for production

## Advanced Features

### Remote Management
Even with auto-login enabled, remote management remains available:
```bash
# SSH access (bypasses auto-login)
ssh camerabridge@device-ip

# Web interface
http://device-ip/

# Direct service management
sudo systemctl status camera-bridge
```

### Kiosk Mode
For dedicated camera bridge devices:
```bash
# Disable unused TTYs
sudo systemctl mask getty@tty2.service
sudo systemctl mask getty@tty3.service
sudo systemctl mask getty@tty4.service
sudo systemctl mask getty@tty5.service
sudo systemctl mask getty@tty6.service

# Prevent TTY switching
echo "kernel.ctrl-alt-del=1" >> /etc/sysctl.conf
```

### Multi-User Setup
Configure multiple auto-login users for different purposes:
```bash
# Photography user
sudo cp /etc/systemd/system/getty@tty1.service.d/autologin.conf \
        /etc/systemd/system/getty@tty2.service.d/

# Management user
sudo sed -i 's/camerabridge/admin/' /etc/systemd/system/getty@tty2.service.d/autologin.conf
```

This seamless boot experience transforms the Camera Bridge into an appliance-like device that's immediately ready for use upon power-on, making it ideal for professional photography workflows and embedded applications.