# Pi Zero 2 W USB Gadget Mode - Quick Start

## What This Does

Transform your Raspberry Pi Zero 2 W into a smart USB drive that automatically uploads photos to Dropbox when connected to cameras or computers.

## Prerequisites

- Raspberry Pi Zero 2 W with Raspberry Pi OS
- MicroSD card (16GB+)
- USB-C cable (data capable)
- Internet connection for initial setup
- Dropbox account

## 5-Minute Setup

### 1. Flash and Boot
```bash
# Flash Raspberry Pi OS to SD card
# Boot Pi Zero 2 W and connect to internet
```

### 2. Install Camera Bridge
```bash
# Download and run installer
git clone https://github.com/tomganleylee/Topcom.git camera-bridge
cd camera-bridge/raspberry-pi/pi-zero-2w
sudo ./scripts/install-pi-zero-2w.sh
sudo reboot
```

### 3. Configure Dropbox
```bash
# After reboot, configure Dropbox
sudo su - camerabridge
rclone config
# Choose: New remote > dropbox > Complete OAuth flow
exit
```

### 4. Enable USB Gadget Mode
```bash
# Setup and enable USB gadget
sudo /usr/local/bin/usb-gadget-manager.sh setup
sudo /usr/local/bin/usb-gadget-manager.sh enable
sudo systemctl start camera-bridge
```

### 5. Connect and Use
```bash
# Connect Pi Zero 2 W to camera/computer via USB-C
# Pi appears as 4GB USB drive
# Copy photos to drive - they auto-sync to Dropbox!
```

## Verification

Check everything is working:
```bash
# Check USB gadget status
sudo /usr/local/bin/usb-gadget-manager.sh status

# Test Dropbox connection
sudo /usr/local/bin/camera-bridge-service test-dropbox

# View live logs
sudo journalctl -u camera-bridge -f
```

## Management

Use the terminal UI for easy management:
```bash
sudo /usr/local/bin/terminal-ui-enhanced
```

## Quick Commands

| Command | Purpose |
|---------|---------|
| `sudo systemctl status camera-bridge` | Check service status |
| `sudo /usr/local/bin/camera-bridge-service sync-now` | Force sync now |
| `sudo /usr/local/bin/usb-gadget-manager.sh status` | USB gadget status |
| `sudo tail -f /var/log/camera-bridge/service.log` | View live logs |

## Troubleshooting

**USB drive not appearing?**
- Check USB-C cable supports data
- Verify: `lsmod | grep dwc2`

**Photos not syncing?**
- Check internet: `ping 8.8.8.8`
- Test Dropbox: `sudo /usr/local/bin/camera-bridge-service test-dropbox`

**Need help?**
- See full documentation: `USB-GADGET-MODE.md`
- Check logs: `sudo journalctl -u camera-bridge`

## What's Next?

- Connect to cameras and start shooting!
- Monitor uploads in Dropbox
- Use terminal UI to switch between USB and network modes
- Resize storage if needed: `sudo /usr/local/bin/usb-gadget-manager.sh resize 8G`