# Camera Bridge Pi Zero 2W - Windows Setup Guide

**🎯 Goal**: Create a fully automatic Camera Bridge that requires **no display, no keyboard, no technical setup** - just flash an SD card and plug it in!

## What You Need

- **Pi Zero 2W** with USB-C power cable
- **SD Card** (16GB or larger, Class 10 recommended)
- **Windows PC** with SD card reader
- **Internet connection** (for downloading files)

## Software Requirements

1. **Raspberry Pi Imager** - [Download Here](https://www.raspberrypi.com/software/)
2. **Camera Bridge Files** - [Download ZIP](https://github.com/tomganleylee/Topcom/archive/refs/heads/main.zip)

## 📋 Step-by-Step Setup

### Step 1: Download Required Files

1. **Download Raspberry Pi Imager** and install it
2. **Download Camera Bridge ZIP file** from GitHub and extract it to your desktop
3. Insert your **SD card** into your Windows PC

### Step 2: Flash Raspberry Pi OS

1. **Open Raspberry Pi Imager**
2. **Choose OS**:
   - Click "Choose OS"
   - Select "Raspberry Pi OS (other)"
   - Select "Raspberry Pi OS Lite (64-bit)"
3. **Choose Storage**: Select your SD card
4. **Click the ⚙️ GEAR icon** for advanced options:
   - ✅ **Enable SSH** (use password authentication)
   - 📝 **Username**: `pi`
   - 🔑 **Password**: (choose a secure password)
   - 📶 **Configure WiFi**: (optional - leave blank to use hotspot mode)
   - 🕐 **Set locale settings**: (your timezone)
5. **Click "WRITE"** and wait for flashing to complete

### Step 3: Prepare SD Card for Auto-Installation

1. **Don't eject the SD card yet!** After flashing, Windows will show it as a drive (usually E: or F:)

2. **Copy Camera Bridge files**:
   ```
   From: Topcom-main\ (extracted ZIP folder)
   To: E:\camera-bridge\ (create this folder on SD card)
   ```

   Copy ALL files and folders so you have:
   ```
   E:\camera-bridge\scripts\
   E:\camera-bridge\raspberry-pi\
   E:\camera-bridge\web\
   E:\camera-bridge\config\
   E:\camera-bridge\docs\
   etc...
   ```

3. **Create auto-installation trigger**:
   - Right-click on the SD card (E:) and create a new text file
   - Name it: `auto-install-camera-bridge.txt`
   - Content doesn't matter, just the filename

4. **Create installation script**:
   Create a file called `firstrun.sh` on the SD card with this content:
   ```bash
   #!/bin/bash
   # Auto-run Camera Bridge installation
   if [ -f /boot/auto-install-camera-bridge.txt ]; then
       echo "Starting Camera Bridge auto-installation..." > /var/log/camera-bridge-setup.log
       /boot/camera-bridge/raspberry-pi/pi-zero-2w/scripts/auto-install-first-boot.sh
   fi
   ```

### Step 4: Final Setup

1. **Safely eject the SD card** from Windows
2. **Insert SD card** into your Pi Zero 2W
3. **Connect power** (USB-C cable)
4. **Wait 10-15 minutes** for automatic installation

## 🚀 What Happens Automatically

1. **Pi boots** with Raspberry Pi OS Lite
2. **Auto-installation starts** (runs in background)
3. **Camera Bridge installs** automatically
4. **WiFi hotspot created**: `CameraBridge-Setup` (password: `setup123`)
5. **Web interface available** at: `http://192.168.4.1`
6. **System reboots** when installation complete

## 📱 Connecting to Your Camera Bridge

### Method 1: WiFi Hotspot (Default)
1. **Look for WiFi network**: `CameraBridge-Setup`
2. **Connect with password**: `setup123`
3. **Open browser** and go to: `http://192.168.4.1`
4. **Complete setup** using the web interface

### Method 2: Existing WiFi (If Configured)
1. **Find Pi's IP address** on your router
2. **Open browser** and go to Pi's IP address
3. **Complete setup** using the web interface

## 🔧 Web Interface Setup

Once connected, the web interface will guide you through:

1. **Dropbox Authentication**
   - Click "Connect to Dropbox"
   - Sign in and authorize Camera Bridge
   - Confirm connection successful

2. **Camera Bridge Mode**
   - **USB Gadget Mode**: Direct USB connection to camera
   - **Network SMB Mode**: WiFi file sharing

3. **Network Configuration** (if needed)
   - Connect to your home WiFi
   - Set up remote access options

4. **Test Setup**
   - Copy test photos to verify sync
   - Monitor sync status

## 🎯 USB Gadget Mode (Recommended for Pi Zero 2W)

This mode makes your Pi Zero 2W appear as a **USB storage device** to your camera:

1. **Connect camera** to Pi via USB-C cable
2. **Camera sees** Pi as external storage
3. **Photos automatically sync** to Dropbox in background
4. **No WiFi configuration** needed on camera

## 📊 Status Monitoring

Access these URLs to monitor your Camera Bridge:

- **Main Dashboard**: `http://192.168.4.1/`
- **Status Page**: `http://192.168.4.1/status.php`
- **Dropbox Connection Test**: Available in web interface

## 🔍 Troubleshooting

### Pi Won't Create Hotspot
- **Wait longer**: Initial setup takes 10-15 minutes
- **Check power**: Use quality USB-C cable and power adapter
- **Red LED solid**: Pi is booting normally
- **Green LED activity**: SD card being accessed

### Can't Connect to Web Interface
- **Confirm WiFi connection** to `CameraBridge-Setup`
- **Try different browser**: Chrome, Firefox, Safari
- **Check URL**: Must be `http://` not `https://`
- **Restart Pi**: Unplug power for 10 seconds, reconnect

### Installation Failed
- **Check SD card**: Must be 16GB+ and working properly
- **Verify files**: Ensure camera-bridge folder copied correctly
- **Internet connection**: Pi needs internet for some packages
- **View logs**: Connect via SSH to check `/var/log/camera-bridge-auto-install.log`

### USB Gadget Not Working
- **Use data cable**: Not all USB-C cables support data transfer
- **Check camera compatibility**: Most modern cameras support USB storage
- **Try different cable**: Some cables are power-only

## 🔒 Security Notes

- **Change default passwords** in web interface
- **Enable WPA3** if your network supports it
- **Regular updates**: Update Pi OS and Camera Bridge periodically
- **Monitor access**: Check who's connected to your hotspot

## 📞 Support

If you encounter issues:

1. **Check logs**: `/var/log/camera-bridge-auto-install.log`
2. **Web interface**: Error messages shown in browser
3. **GitHub Issues**: Report bugs at repository
4. **Documentation**: Check other guides in `docs/` folder

## 🎉 Success!

Once setup is complete, you have a fully automatic camera bridge that:

- ✅ **No display needed** - completely headless operation
- ✅ **No keyboard needed** - all configuration via web
- ✅ **Automatic sync** - photos appear in Dropbox instantly
- ✅ **Multiple modes** - USB gadget or network sharing
- ✅ **Professional grade** - reliable for important shoots

Your Camera Bridge is now ready for professional photography workflows!