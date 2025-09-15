# 🚀 Camera Bridge Pi Zero 2W - Windows Setup (5 Minutes!)

**Turn your Pi Zero 2W into an automatic camera bridge with NO display, NO keyboard, NO technical setup!**

## What You Get

✅ **Plug & Play**: Flash SD card, insert, power on - that's it!
✅ **WiFi Hotspot**: Automatic `CameraBridge-Setup` network
✅ **Web Interface**: Configure everything in your browser
✅ **USB Gadget Mode**: Pi appears as USB storage to your camera
✅ **Auto Dropbox Sync**: Photos automatically upload to cloud

## Quick Start (5 Steps)

### 1. Download & Install
- **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
- **Camera Bridge**: https://github.com/tomganleylee/Topcom/archive/refs/heads/main.zip

### 2. Flash SD Card
1. Open **Raspberry Pi Imager**
2. **OS**: Raspberry Pi OS Lite (64-bit)
3. **Gear Icon ⚙️**:
   - ✅ Enable SSH
   - Username: `pi`
   - Password: your choice
4. **Flash** to SD card

### 3. Auto-Setup Files
1. **Don't eject SD card yet!**
2. **Extract** Camera Bridge ZIP file
3. **Copy everything** to `E:\camera-bridge\` (replace E: with your SD drive)
4. **Create file**: `E:\auto-install-camera-bridge.txt` (empty file, just the name)

### 4. Power On
1. **Eject SD card** safely
2. **Insert** into Pi Zero 2W
3. **Connect power** (USB-C)
4. **Wait 10-15 minutes**

### 5. Connect & Configure
1. **Find WiFi**: `CameraBridge-Setup`
2. **Password**: `setup123`
3. **Browser**: `http://192.168.4.1`
4. **Follow setup wizard**

## That's It! 🎉

Your Camera Bridge is now ready for professional photography workflows!

## USB Gadget Mode

**Connect camera directly to Pi via USB-C:**
- Camera sees Pi as external storage
- Photos automatically sync to Dropbox
- No WiFi setup needed on camera
- Perfect for field photography

## Troubleshooting

**No hotspot after 20 minutes?**
- Check power cable (must be good quality)
- Verify SD card worked in imager
- Try different power adapter

**Can't access web interface?**
- Ensure connected to `CameraBridge-Setup` WiFi
- Use `http://` not `https://`
- Try different browser

**Need help?**
- Check full guide: `WINDOWS-SETUP-GUIDE.md`
- GitHub issues: https://github.com/tomganleylee/Topcom/issues

---

**🎯 Result**: Professional-grade camera bridge that works anywhere, anytime, with zero technical setup!