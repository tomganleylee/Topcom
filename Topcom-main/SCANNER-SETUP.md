# Brother DS-640 Scanner Integration Guide

## Overview

The Camera Bridge now supports the Brother DS-640 USB scanner with automatic Dropbox sync. When you press the scan button on the scanner, documents are automatically saved and synced to Dropbox.

## Features

- **Automatic Sync**: Scanned documents automatically upload to Dropbox
- **Separate Folders**: Camera photos go to `Camera-Photos`, scans go to `Scanned-Documents`
- **SMB Share**: Access scanned documents via network share `\\192.168.10.1\scanner`
- **Multiple Formats**: Supports JPG, PNG, PDF, TIFF
- **USB Connection**: Simple USB connection, no network configuration needed

## Quick Setup

### On New Machine

If you're deploying to a new machine, use the complete deployment script:

```bash
cd /opt/camera-bridge/Topcom-main
sudo ./deploy-complete.sh --with-scanner
```

This will:
1. Install Camera Bridge
2. Install Brother scanner drivers
3. Configure scanner directory and permissions
4. Set up automatic Dropbox sync for scans
5. Create SMB share for scanner output

### On Existing Installation

If you already have Camera Bridge installed:

```bash
cd /opt/camera-bridge/Topcom-main
sudo ./scripts/setup-brother-scanner.sh
```

Then update the monitoring service:

```bash
sudo cp /opt/camera-bridge/Topcom-main/scripts/monitor-service-with-scanner.sh /opt/camera-bridge/scripts/monitor-service.sh
sudo systemctl restart camera-bridge
```

## Hardware Setup

### 1. Connect Scanner

Connect the Brother DS-640 to a USB port on your machine.

### 2. Verify Detection

```bash
lsusb | grep Brother
```

You should see output like:
```
Bus 001 Device 005: ID 04f9:60e0 Brother Industries, Ltd
```

### 3. Configure Scanner

```bash
sudo brsaneconfig4 -a name=DS640 model=DS-640
```

Verify configuration:
```bash
brsaneconfig4 -q | grep DS640
```

### 4. Test Scanner

```bash
scanimage --test
```

If successful, you'll see:
```
scanimage: rounded value of br-x from 215.9 to 215.872
scanimage: rounded value of br-y from 355.6 to 355.567
```

## Using the Scanner

### Scanning Documents

1. **Insert Document**: Place document in scanner
2. **Press Scan Button**: Press the physical scan button on the Brother DS-640
3. **Wait for Completion**: Scanner processes the document
4. **Auto-Upload**: File automatically syncs to Dropbox

### Where Files Go

**Local Storage:**
- Scanner saves to: `/srv/scanner/scans/`
- SMB share: `\\192.168.10.1\scanner`

**Dropbox:**
- Scans go to: `Scanned-Documents/`
- Camera photos go to: `Camera-Photos/`

### File Naming

Scans are automatically named with timestamp:
```
scan_20251008_143025.jpg
scan_20251008_143156.jpg
```

## Monitoring

### Check Service Status

```bash
sudo systemctl status camera-bridge
```

### View Live Logs

```bash
sudo journalctl -u camera-bridge -f
```

You'll see entries like:
```
2025-10-08 14:30:25: [SCANNER] Detected: scan_20251008_143025.jpg
2025-10-08 14:30:28: [SCANNER] ✓ Uploaded: scan_20251008_143025.jpg
```

### Check Dropbox Sync

```bash
sudo -u camerabridge rclone ls dropbox:Scanned-Documents/
```

## SMB Access

### From Windows

1. Open File Explorer
2. Type in address bar: `\\192.168.10.1\scanner`
3. Login:
   - Username: `camera`
   - Password: `camera123`
4. View/download scanned documents

### From Mac

1. Open Finder
2. Press `Cmd+K`
3. Enter: `smb://192.168.10.1/scanner`
4. Connect with username `camera` and password `camera123`

### From Linux

```bash
smb://192.168.10.1/scanner
```

## Troubleshooting

### Scanner Not Detected

**Check USB connection:**
```bash
lsusb | grep Brother
```

**Check scanner group permissions:**
```bash
groups camerabridge | grep scanner
```

**Reload udev rules:**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Scans Not Syncing

**Check monitoring service:**
```bash
sudo systemctl status camera-bridge
sudo journalctl -u camera-bridge -n 50
```

**Check scanner directory permissions:**
```bash
ls -la /srv/scanner/scans/
```

Should show: `drwxrwxr-x camerabridge scanner`

**Check Dropbox connection:**
```bash
sudo -u camerabridge rclone lsd dropbox:Scanned-Documents/
```

### Scan Button Not Working

**Test manual scan:**
```bash
scanimage --device-name="brother4:net1;dev0" \
    --format=jpeg \
    --resolution=300 \
    --mode=Color \
    > /srv/scanner/scans/test_scan.jpg
```

**Check Brother scan-key service:**
```bash
ps aux | grep brscan
```

### SMB Share Not Accessible

**Check Samba configuration:**
```bash
testparm -s | grep -A 20 "\[scanner\]"
```

**Restart Samba:**
```bash
sudo systemctl restart smbd
```

**Check if listening:**
```bash
netstat -tuln | grep 445
```

## Scanner Specifications

**Brother DS-640**
- Type: Mobile scanner
- Connection: USB 2.0
- Scan Speed: Up to 7.5 pages/minute
- Resolution: Up to 600 x 600 dpi
- Document Width: Up to 8.5"
- Supported Formats: PDF, JPG, PNG, TIFF

## Advanced Configuration

### Change Scan Directory

Edit `/opt/camera-bridge/scripts/monitor-service.sh`:

```bash
SCANNER_DIR="/srv/scanner/scans"  # Change this path
```

Then restart service:
```bash
sudo systemctl restart camera-bridge
```

### Change Dropbox Folder

Edit `/opt/camera-bridge/scripts/monitor-service.sh`:

```bash
DROPBOX_SCANS="dropbox:Scanned-Documents"  # Change folder name
```

Then restart service:
```bash
sudo systemctl restart camera-bridge
```

### Change Scan Resolution

Edit `/usr/local/bin/brother-scan-to-dropbox`:

```bash
scanimage --device-name="brother4:net1;dev0" \
    --format=jpeg \
    --resolution=600 \    # Change from 300 to 600
    --mode=Color \
    > "$SCAN_DIR/${FILENAME}.jpg" 2>/dev/null
```

### Save as PDF Instead of JPG

Edit `/usr/local/bin/brother-scan-to-dropbox`:

```bash
scanimage --device-name="brother4:net1;dev0" \
    --format=tiff \      # Change format
    --resolution=300 \
    --mode=Color \
    | convert - "$SCAN_DIR/${FILENAME}.pdf"  # Convert to PDF
```

## Uninstalling Scanner Support

```bash
# Remove Brother software
sudo apt remove brscan-skey brscan4 -y

# Remove scanner directory
sudo rm -rf /srv/scanner

# Remove SMB share (edit /etc/samba/smb.conf, remove [scanner] section)
sudo nano /etc/samba/smb.conf

# Revert to non-scanner monitoring service
sudo cp /opt/camera-bridge/Topcom-main/scripts/install-complete.sh /tmp/
# Extract the original monitor-service.sh from install-complete.sh
sudo systemctl restart camera-bridge
```

## Support

For issues or questions:
1. Check service logs: `sudo journalctl -u camera-bridge -f`
2. Verify scanner detection: `lsusb | grep Brother`
3. Test manual scan: `scanimage --test`
4. Check Dropbox sync: `sudo -u camerabridge rclone ls dropbox:`

---

**Version:** 2.1
**Last Updated:** October 2025
**Compatible With:** Brother DS-640 USB Scanner
