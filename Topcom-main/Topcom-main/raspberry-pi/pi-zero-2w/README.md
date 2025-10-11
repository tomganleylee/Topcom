# Camera Bridge - Raspberry Pi Zero 2 W USB Gadget Mode

Smart USB storage device that automatically syncs photos to Dropbox.

## What It Does

Transform your Raspberry Pi Zero 2 W into an intelligent USB drive that:
- Acts as USB mass storage when connected to cameras/computers
- Automatically detects new photos
- Syncs them to Dropbox in the background
- Works with any camera that supports USB storage

## Quick Start

1. **Install**: `sudo ./scripts/install-pi-zero-2w.sh`
2. **Configure Dropbox**: `rclone config`
3. **Enable USB Mode**: `sudo /usr/local/bin/usb-gadget-manager.sh setup && enable`
4. **Connect & Shoot**: Plug into camera, start taking photos!

See [QUICK-START.md](QUICK-START.md) for detailed 5-minute setup.

## Features

- **USB Mass Storage Emulation** - Appears as standard USB drive
- **Automatic Photo Detection** - Real-time monitoring with inotify
- **Background Dropbox Sync** - Uses rclone for reliable uploads
- **Dual Mode Operation** - Switch between USB gadget and network SMB modes
- **Terminal Management UI** - Easy configuration and monitoring
- **Camera Compatibility** - Works with DSLR, mirrorless, action cameras
- **File Type Support** - JPEG, PNG, TIFF, RAW formats (CR2, NEF, ARW, etc.)

## Hardware Requirements

- **Raspberry Pi Zero 2 W** (USB OTG support required)
- **MicroSD Card** - 16GB+ recommended
- **USB-C Cable** - Data capable (not power-only)
- **Camera/Computer** - With USB port

## Documentation

- **[Quick Start Guide](QUICK-START.md)** - 5-minute setup
- **[Complete Documentation](USB-GADGET-MODE.md)** - Detailed usage and troubleshooting
- **[Installation Script](scripts/install-pi-zero-2w.sh)** - Automated setup

## File Structure

```
pi-zero-2w/
├── README.md                    # This file
├── QUICK-START.md              # 5-minute setup guide
├── USB-GADGET-MODE.md          # Complete documentation
└── scripts/
    ├── install-pi-zero-2w.sh   # Installation script
    └── usb-gadget-manager.sh   # USB gadget management
```

## Common Use Cases

### Photography Workflow
1. Connect Pi Zero 2 W to camera via USB
2. Camera sees 4GB USB drive
3. Take photos, save to "USB drive"
4. Photos automatically sync to Dropbox
5. Access from anywhere via Dropbox

### Backup Solution
- Automatic backup of camera photos
- No manual file management required
- Internet connectivity for cloud sync
- Local storage buffer for offline use

### Event Photography
- Continuous backup during shoots
- Multiple photographers can use same device
- Centralized photo collection in Dropbox
- Real-time sharing capabilities

## System Requirements

### Software
- Raspberry Pi OS (latest)
- Kernel modules: `dwc2`, `libcomposite`
- Dependencies: `inotify-tools`, `lsof`, `rclone`

### Hardware
- USB OTG capability (Pi Zero 2 W built-in)
- Minimum 2GB storage for OS + buffer
- Reliable internet connection for sync

## Installation Methods

### Automatic (Recommended)
```bash
git clone https://github.com/tomganleylee/Topcom.git camera-bridge
cd camera-bridge/raspberry-pi/pi-zero-2w
sudo ./scripts/install-pi-zero-2w.sh
```

### Manual
See [USB-GADGET-MODE.md](USB-GADGET-MODE.md) for step-by-step manual installation.

## Status and Monitoring

### Quick Status Check
```bash
sudo /usr/local/bin/usb-gadget-manager.sh status
sudo systemctl status camera-bridge
```

### Live Monitoring
```bash
# Service logs
sudo journalctl -u camera-bridge -f

# Detailed logs
sudo tail -f /var/log/camera-bridge/service.log

# Terminal UI
sudo /usr/local/bin/terminal-ui-enhanced
```

## Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| USB not detected | Check cable, verify `lsmod \| grep dwc2` |
| No Dropbox sync | Test: `sudo /usr/local/bin/camera-bridge-service test-dropbox` |
| Storage full | Resize: `sudo /usr/local/bin/usb-gadget-manager.sh resize 8G` |
| Service errors | Check: `sudo journalctl -u camera-bridge` |

## Performance

- **Sync Speed**: Depends on internet connection and file size
- **Storage**: Default 4GB, expandable to available SD card space
- **Compatibility**: FAT32 filesystem for universal camera support
- **Reliability**: Automatic retry and queue management

## Security

- Physical device security recommended
- Dropbox provides encryption in transit/at rest
- Local storage accessible when mounted
- Network mode available for secure sharing

## Support

- **Documentation**: See [USB-GADGET-MODE.md](USB-GADGET-MODE.md)
- **Logs**: `sudo journalctl -u camera-bridge`
- **Status**: `sudo /usr/local/bin/usb-gadget-manager.sh status`
- **Issues**: Check main repository for bug reports

## Parent Project

This is part of the Camera Bridge project. See the main repository for:
- Network SMB sharing mode
- Web interface
- Ubuntu/Debian installation
- Complete system documentation

## License

Open source - see main repository for license details.