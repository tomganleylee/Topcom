# Camera Bridge Pi Zero 2W - Offline Installation Guide

**🎯 Goal**: Install Camera Bridge completely offline - no internet connection needed after initial setup!

## Overview

This guide creates a fully offline installer that includes ALL dependencies, so you can set up your Pi Zero 2W Camera Bridge anywhere without internet access.

## Step 1: Create Offline Installer (Do This Once)

**On a Pi with internet connection:**

```bash
# Download Camera Bridge
wget https://github.com/tomganleylee/Topcom/archive/refs/heads/main.zip
unzip main.zip
cd Topcom-main

# Create offline installer (downloads ~500MB of packages)
sudo ./raspberry-pi/pi-zero-2w/scripts/create-offline-installer.sh
```

This creates: `/boot/camera-bridge-offline-installer.tar.gz`

## Step 2: Prepare SD Card for Offline Installation

### Windows Users:

1. **Flash Pi OS Lite** with Raspberry Pi Imager
   - Enable SSH, set username: `pi`, password: your choice
   - **Don't configure WiFi** (we want offline mode)

2. **Copy files to SD card:**
   ```
   E:\camera-bridge-offline-installer.tar.gz
   E:\camera-bridge\                    (extract Camera Bridge ZIP here)
   E:\auto-install-camera-bridge.txt    (empty trigger file)
   ```

3. **Create first-run script** `E:\firstrun.sh`:
   ```bash
   #!/bin/bash
   cd /boot
   tar xzf camera-bridge-offline-installer.tar.gz
   cd camera-bridge-offline
   sudo ./install-offline.sh
   /boot/camera-bridge/raspberry-pi/pi-zero-2w/scripts/auto-install-first-boot.sh
   ```

## Step 3: Offline Installation Process

1. **Insert SD card** into Pi Zero 2W
2. **Power on** (no WiFi needed!)
3. **Wait 15-20 minutes** for automatic installation
4. **Look for hotspot**: `CameraBridge-Setup`
5. **Connect and configure**: `http://192.168.4.1`

## What Gets Installed Offline

### System Packages (~300MB):
- hostapd, dnsmasq (WiFi hotspot)
- nginx, php8.2-fpm (web interface)
- samba (file sharing)
- inotify-tools (file monitoring)
- All dependencies and libraries

### Applications (~50MB):
- rclone (Dropbox sync)
- Camera Bridge scripts
- USB gadget utilities

### Configurations:
- USB gadget mode setup
- WiFi hotspot configuration
- Web interface
- Auto-start services

## Manual Offline Installation

If automatic installation fails:

```bash
# On Pi (no internet needed)
cd /boot
tar xzf camera-bridge-offline-installer.tar.gz
cd camera-bridge-offline
sudo ./install-offline.sh

# Then run Camera Bridge setup
cd /boot/camera-bridge
sudo ./raspberry-pi/pi-zero-2w/scripts/install-pi-zero-2w.sh
```

## Benefits of Offline Installation

✅ **No internet required** during Pi setup
✅ **Faster installation** (no downloads)
✅ **Works anywhere** (remote locations, no WiFi)
✅ **Consistent results** (same package versions)
✅ **Air-gapped security** (no network exposure)

## Troubleshooting

### Large Package Size
The offline installer is ~500MB because it includes all dependencies. This ensures everything works without internet.

### Slow Installation
First boot takes longer (15-20 minutes) because it's installing many packages from SD card.

### Missing Packages
If installation fails with missing packages, recreate the offline installer on a Pi with internet.

### Storage Space
Ensure SD card has at least 8GB free space for all packages and Camera Bridge files.

## Advanced: Creating Minimal Offline Installer

For smaller size, exclude non-essential packages:

```bash
# Edit create-offline-installer.sh
# Remove: htop, vim, git (optional packages)
# Reduces size by ~100MB
```

## Updating Offline Installer

Recreate the offline installer periodically to get latest package versions:

```bash
# Every few months, recreate with:
sudo ./raspberry-pi/pi-zero-2w/scripts/create-offline-installer.sh
```

---

**🎉 Result**: A completely self-contained Camera Bridge that installs and runs without any internet connection!