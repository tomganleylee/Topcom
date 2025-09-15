# USB Gadget Mode for Raspberry Pi Zero 2 W

## Overview

The Raspberry Pi Zero 2 W can be configured to act as a USB mass storage device when connected to a computer or camera. In this mode, the Pi appears as a USB drive that automatically syncs any new photos to Dropbox in the background.

## Features

- **USB Mass Storage Emulation**: Pi Zero 2 W appears as a standard USB drive
- **Automatic Photo Detection**: Monitors for new image files in real-time
- **Background Dropbox Sync**: Automatically uploads photos to Dropbox
- **Dual Mode Operation**: Can switch between USB gadget mode and network SMB mode
- **Status Monitoring**: Built-in status indicators and logging

## Hardware Requirements

- Raspberry Pi Zero 2 W
- MicroSD card (16GB+ recommended)
- USB-C cable (data capable, not power-only)
- Computer or camera with USB port

## Installation

### Automatic Installation

```bash
cd /home/tom/camera-bridge/raspberry-pi/pi-zero-2w
sudo ./scripts/install-pi-zero-2w.sh
```

### Manual Installation Steps

1. **Enable USB OTG in boot config:**
   ```bash
   echo "dtoverlay=dwc2" | sudo tee -a /boot/firmware/config.txt
   echo "modules-load=dwc2,libcomposite" | sudo tee -a /boot/firmware/cmdline.txt
   ```

2. **Install required packages:**
   ```bash
   sudo apt update
   sudo apt install -y inotify-tools lsof
   ```

3. **Create camerabridge user:**
   ```bash
   sudo useradd -m -s /bin/bash camerabridge
   sudo usermod -aG sudo camerabridge
   ```

4. **Copy scripts to system:**
   ```bash
   sudo cp scripts/usb-gadget-manager.sh /usr/local/bin/
   sudo cp ../scripts/camera-bridge-service-enhanced.sh /usr/local/bin/camera-bridge-service
   sudo chmod +x /usr/local/bin/usb-gadget-manager.sh
   sudo chmod +x /usr/local/bin/camera-bridge-service
   ```

5. **Reboot to enable USB gadget kernel modules**

## Configuration

### 1. Configure Dropbox

Before using USB gadget mode, you must configure Dropbox authentication:

```bash
# Switch to camerabridge user
sudo su - camerabridge

# Configure rclone for Dropbox
rclone config

# Follow the interactive setup for Dropbox
# Name: dropbox
# Storage: dropbox
# Complete OAuth2 authentication
```

### 2. USB Gadget Setup

Initialize the USB gadget configuration:

```bash
sudo /usr/local/bin/usb-gadget-manager.sh setup
```

This creates:
- USB mass storage device configuration
- 4GB storage file at `/opt/camera-bridge/storage/usb-storage.img`
- FAT32 filesystem for compatibility

### 3. Enable USB Gadget Mode

```bash
sudo /usr/local/bin/usb-gadget-manager.sh enable
```

## Usage

### Starting USB Gadget Mode

1. **Enable USB gadget:**
   ```bash
   sudo /usr/local/bin/usb-gadget-manager.sh enable
   ```

2. **Start camera bridge service:**
   ```bash
   sudo systemctl start camera-bridge
   ```

3. **Connect Pi Zero 2 W to computer/camera via USB-C**

4. **The Pi will appear as a USB drive ready for photo storage**

### Switching Between Modes

Use the enhanced terminal UI:

```bash
sudo /usr/local/bin/terminal-ui-enhanced
```

Navigate to "Operation Mode Management" to switch between:
- **SMB Network Mode**: Traditional network file sharing
- **USB Gadget Mode**: USB mass storage device

### Manual Mode Switching

```bash
# Switch to USB gadget mode
sudo /usr/local/bin/camera-bridge-service switch-mode usb-gadget

# Switch to SMB network mode
sudo /usr/local/bin/camera-bridge-service switch-mode smb
```

## How It Works

### USB Mass Storage Emulation

1. **Kernel Modules**: Uses `dwc2` and `libcomposite` for USB OTG functionality
2. **ConfigFS**: Leverages Linux configfs to create USB gadget configuration
3. **Storage Backend**: Creates a loopback file that appears as USB storage
4. **File Monitoring**: Uses inotify to detect new files in real-time

### Photo Sync Process

1. **File Detection**: Camera or computer writes photos to USB drive
2. **Inotify Trigger**: System detects new image files immediately
3. **File Validation**: Waits for complete file write, checks file integrity
4. **Background Upload**: Automatically syncs to Dropbox using rclone
5. **Status Logging**: Records all sync operations with timestamps

### Supported File Types

- JPEG: `.jpg`, `.jpeg`
- PNG: `.png`
- TIFF: `.tiff`, `.tif`
- RAW formats: `.raw`, `.dng`, `.cr2`, `.nef`, `.orf`, `.arw`
- Both uppercase and lowercase extensions

## Monitoring and Status

### Check USB Gadget Status

```bash
sudo /usr/local/bin/usb-gadget-manager.sh status
```

### View Service Logs

```bash
# Real-time log viewing
sudo journalctl -u camera-bridge -f

# View recent logs
sudo journalctl -u camera-bridge --since "1 hour ago"

# Service-specific log file
sudo tail -f /var/log/camera-bridge/service.log
```

### Check Dropbox Connection

```bash
sudo /usr/local/bin/camera-bridge-service test-dropbox
```

### Manual Sync

```bash
sudo /usr/local/bin/camera-bridge-service sync-now
```

## Troubleshooting

### USB Gadget Not Appearing

1. **Check kernel modules:**
   ```bash
   lsmod | grep dwc2
   lsmod | grep libcomposite
   ```

2. **Verify USB gadget configuration:**
   ```bash
   ls -la /sys/kernel/config/usb_gadget/
   ```

3. **Check boot configuration:**
   ```bash
   grep dwc2 /boot/firmware/config.txt
   grep libcomposite /boot/firmware/cmdline.txt
   ```

### Photos Not Syncing

1. **Check internet connectivity:**
   ```bash
   ping -c 3 8.8.8.8
   ```

2. **Verify Dropbox configuration:**
   ```bash
   sudo -u camerabridge rclone lsd dropbox:
   ```

3. **Check file permissions:**
   ```bash
   ls -la /opt/camera-bridge/storage/
   ```

### Storage Full

1. **Check storage usage:**
   ```bash
   df -h /opt/camera-bridge/storage/
   ```

2. **Resize storage file:**
   ```bash
   sudo /usr/local/bin/usb-gadget-manager.sh resize 8G
   ```

### Common Issues

| Issue | Solution |
|-------|----------|
| USB device not detected | Ensure USB-C cable supports data transfer |
| Permission denied errors | Check camerabridge user permissions |
| Storage appears read-only | Verify FAT32 filesystem integrity |
| Slow sync speeds | Check WiFi connection and Dropbox API limits |
| Service won't start | Check all dependencies and configuration files |

## Performance Optimization

### SD Card Longevity

The Pi Zero 2 W installation includes optimizations for SD card longevity:
- Reduced swap usage
- Log rotation configuration
- Temporary file management
- Write-efficient storage allocation

### Storage Management

- **Default Size**: 4GB USB storage
- **Expandable**: Can be resized as needed
- **Auto-cleanup**: Automatically manages temporary files
- **Efficient Sync**: Only uploads new/changed files

## Security Considerations

### File Access

- USB storage is formatted as FAT32 for broad compatibility
- No built-in encryption on USB storage layer
- Dropbox provides encryption in transit and at rest

### Network Security

When switching to SMB mode:
- WiFi credentials are stored securely
- SMB shares use authentication
- Firewall rules limit access to necessary ports

### Recommendations

1. **Physical Security**: Secure the Pi Zero 2 W physically
2. **Network Security**: Use WPA3 WiFi when possible
3. **Access Control**: Limit physical access to USB port
4. **Regular Updates**: Keep system packages updated

## Advanced Configuration

### Custom Storage Size

```bash
sudo /usr/local/bin/usb-gadget-manager.sh setup custom 8G
```

### Custom Mount Point

Edit `/usr/local/bin/usb-gadget-manager.sh` and modify:
```bash
MOUNT_POINT="/custom/mount/path"
```

### Custom Dropbox Destination

Edit camera bridge service configuration:
```bash
DROPBOX_DEST="dropbox:Custom-Photos"
```

## Integration with Cameras

### Compatible Cameras

Most modern cameras that support USB storage will work:
- DSLR cameras with USB connectivity
- Mirrorless cameras
- Action cameras (GoPro, etc.)
- Smartphone cameras (via USB connection)

### Camera Setup

1. **Configure camera to save to external storage**
2. **Connect camera to Pi Zero 2 W via USB**
3. **Camera will see Pi as standard USB storage device**
4. **Photos are automatically synced to Dropbox in background**

## Command Reference

### USB Gadget Manager Commands

```bash
# Setup USB gadget (first time)
sudo /usr/local/bin/usb-gadget-manager.sh setup

# Enable USB gadget mode
sudo /usr/local/bin/usb-gadget-manager.sh enable

# Disable USB gadget mode
sudo /usr/local/bin/usb-gadget-manager.sh disable

# Check status
sudo /usr/local/bin/usb-gadget-manager.sh status

# Resize storage
sudo /usr/local/bin/usb-gadget-manager.sh resize 8G
```

### Camera Bridge Service Commands

```bash
# Start service
sudo systemctl start camera-bridge

# Stop service
sudo systemctl stop camera-bridge

# Enable auto-start
sudo systemctl enable camera-bridge

# Check status
sudo systemctl status camera-bridge

# Switch modes
sudo /usr/local/bin/camera-bridge-service switch-mode usb-gadget
sudo /usr/local/bin/camera-bridge-service switch-mode smb

# Test Dropbox
sudo /usr/local/bin/camera-bridge-service test-dropbox

# Manual sync
sudo /usr/local/bin/camera-bridge-service sync-now
```

## Support

For issues and support:
1. Check the troubleshooting section above
2. Review system logs: `sudo journalctl -u camera-bridge`
3. Verify hardware compatibility
4. Check network connectivity and Dropbox configuration

## License

This project is open source. See the main repository for license details.