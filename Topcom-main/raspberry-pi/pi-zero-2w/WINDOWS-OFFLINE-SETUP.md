# Camera Bridge - Windows Offline Setup Guide

**Problem**: You want to set up Pi Zero 2W Camera Bridge on Windows without needing internet on the Pi.

**Solution**: Hybrid offline setup that works from Windows!

## Method 1: Pre-Built Offline Installer (Easiest)

### Step 1: Download Pre-Built Files
- **Camera Bridge**: [Download ZIP](https://github.com/tomganleylee/Topcom/archive/refs/heads/main.zip)
- **Offline Installer**: [Pre-built offline installer] (500MB - I can create this)

### Step 2: Windows SD Card Setup
1. **Flash Pi OS Lite** with Raspberry Pi Imager
   - Enable SSH, username: `pi`, password: your choice
   - **Don't configure WiFi**

2. **Copy to SD card**:
   ```
   E:\camera-bridge-offline-installer.tar.gz
   E:\camera-bridge\                    (extracted Camera Bridge files)
   E:\auto-install-camera-bridge.txt    (empty file)
   ```

3. **Boot Pi → automatic offline installation!**

## Method 2: Minimal Internet Setup (Most Practical)

### Windows Preparation:
1. **Flash Pi OS Lite** (enable SSH)
2. **Copy Camera Bridge files** to SD card
3. **Create trigger file**: `auto-install-camera-bridge.txt`

### Pi Setup (One-time internet needed):
1. **Power on Pi**
2. **Connect to phone hotspot** (or temporary WiFi)
3. **Automatic installation** downloads packages once
4. **Disconnect from internet**
5. **Pi creates its own hotspot**: `CameraBridge-Setup`

### Future Use:
- **No internet needed** - Pi works as standalone hotspot
- **USB gadget mode** works completely offline
- **Camera Bridge functions** entirely self-contained

## Method 3: Package Caching System

**Idea**: Create a Windows tool that prepares everything:

```batch
@echo off
echo Downloading Camera Bridge dependencies...

:: Download pre-compiled packages
powershell -Command "Invoke-WebRequest -Uri 'https://example.com/camera-bridge-deps.zip' -OutFile 'deps.zip'"

:: Extract to SD card
powershell -Command "Expand-Archive -Path 'deps.zip' -DestinationPath '%1:\camera-bridge-deps\'"

echo Dependencies cached for offline installation!
```

## Recommended Approach for Windows Users

**I recommend Method 2** because:

✅ **Simple Windows setup** - just copy files to SD card
✅ **One-time internet** - Pi downloads packages once
✅ **Fully offline afterward** - no internet needed for operation
✅ **Easy to replicate** - create multiple Pi setups the same way
✅ **Phone hotspot works** - don't need home WiFi

## What Happens After Setup

Once installed (online or offline), your Pi Zero 2W:

- ✅ **Creates WiFi hotspot**: `CameraBridge-Setup`
- ✅ **Works completely offline** for camera bridge functions
- ✅ **USB gadget mode**: Appears as storage device to cameras
- ✅ **Dropbox sync**: Only needs internet for cloud upload
- ✅ **Web interface**: Configure at `http://192.168.4.1`

## Windows Batch File for Easy Setup

```batch
@echo off
title Camera Bridge - Offline Setup for Windows

echo ============================================
echo Camera Bridge Pi Zero 2W - Offline Setup
echo ============================================

set /p drive="Enter SD card drive letter (e.g., E): "

echo Copying Camera Bridge files...
xcopy "Topcom-main\*" "%drive%:\camera-bridge\" /E /I /H /Y

echo Creating auto-install trigger...
echo Auto-install Camera Bridge > "%drive%:\auto-install-camera-bridge.txt"

echo.
echo Setup complete!
echo Insert SD card into Pi Zero 2W and power on.
echo Pi will create WiFi hotspot: CameraBridge-Setup
```

**Bottom line**: You can't create the offline installer on Windows, but you can still achieve offline operation with minimal one-time internet setup on the Pi!