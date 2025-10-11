# Camera Bridge - Quick Start Guide

## Overview

Camera Bridge is an automated file sync system that monitors camera photos and scanned documents, automatically uploading them to Dropbox.

**Features:**
- 📸 Automatic photo sync from cameras via SMB/Samba share
- 📄 Brother scanner support with auto-sync
- 📡 WiFi hotspot mode (creates its own network)
- 🔄 OAuth2 token refresh (no manual token updates)
- 🌐 Web interface for easy configuration
- 🔒 Secure, runs as dedicated user

---

## Quick Setup - New Machine

### One-Command Setup (Recommended)

```bash
# Clone repository
git clone https://github.com/tomganleylee/Topcom.git /opt/camera-bridge
cd /opt/camera-bridge

# Run interactive setup script
sudo bash setup-new-machine.sh
```

The script will ask you:
- ✓ Install camera bridge (required)
- ? Install WiFi hotspot? (optional)
- ? Install scanner support? (optional)

That's it! The script handles everything.

---

## Manual Setup (Advanced)

If you prefer manual installation:

### 1. Clone Repository
```bash
git clone https://github.com/tomganleylee/Topcom.git /opt/camera-bridge
cd /opt/camera-bridge
```

### 2. Install Base System
```bash
sudo bash Topcom-main/scripts/install-complete.sh
```

### 3. (Optional) Install WiFi Hotspot
```bash
sudo bash Topcom-main/scripts/setup-wifi-hotspot.sh
```

### 4. (Optional) Install Scanner Support
```bash
sudo bash Topcom-main/scripts/setup-brother-scanner.sh

# Create quick scan command
sudo tee /usr/local/bin/scan << 'EOF'
#!/bin/bash
SCAN_DIR="/srv/samba/camera-share/scans"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
FILENAME="scan_${TIMESTAMP}.jpg"
echo "Scanning..."
scanimage --format=jpeg --resolution=300 --mode=Color > "$SCAN_DIR/$FILENAME" 2>/dev/null
if [ $? -eq 0 ]; then
    chmod 664 "$SCAN_DIR/$FILENAME"
    chown camerabridge:scanner "$SCAN_DIR/$FILENAME"
    echo "✓ Scan saved: $FILENAME"
    echo "  Will auto-sync to Dropbox..."
else
    echo "✗ Scan failed"
fi
EOF
sudo chmod +x /usr/local/bin/scan
```

---

## Post-Installation Configuration

### 1. Configure Dropbox Token

**Option A: Web Interface (Easiest)**
```
http://localhost/
# Or if using WiFi hotspot: http://192.168.4.1/
```

**Option B: Terminal UI**
```bash
sudo bash /opt/camera-bridge/scripts/terminal-ui.sh
```

### 2. Connect Camera

**Windows/Mac/Linux:**
- Connect to network (or WiFi hotspot if enabled)
- Mount SMB share: `\\<machine-ip>\camera-share`
- Username: `camera`
- Password: (set during installation)

**Camera (if supported):**
- Some cameras can connect directly to SMB shares
- Configure in camera settings

### 3. Use Scanner (if installed)

```bash
# Check scanner detected
scanimage -L

# Scan a document
scan

# Scans auto-upload to Dropbox within seconds!
```

---

## System Architecture

```
Camera/Scanner → SMB Share → inotify → rclone → Dropbox
                    ↓
          /srv/samba/camera-share/
                    ├── photos/
                    └── scans/
```

**How it works:**
1. Files saved to SMB share (from camera or scanner)
2. `inotifywait` detects new files instantly
3. `rclone` uploads to Dropbox with retry logic
4. OAuth2 token auto-refreshes every 3 hours

---

## Network Modes

### Client Mode (Default)
- Machine connects to existing WiFi/Ethernet
- Access via: `http://<machine-ip>/`

### Access Point Mode (with WiFi hotspot)
- Machine creates WiFi network: **CameraBridge**
- IP: `192.168.4.1`
- Access via: `http://192.168.4.1/`
- Other devices connect to this network

---

## Common Commands

```bash
# View service status
sudo systemctl status camera-bridge

# View live logs
sudo journalctl -u camera-bridge -f

# Restart service
sudo systemctl restart camera-bridge

# Scan document (if scanner installed)
scan

# Check WiFi hotspot (if installed)
sudo systemctl status hostapd
sudo systemctl status dnsmasq

# Manual token refresh
sudo bash /opt/camera-bridge/scripts/dropbox-token-manager.sh refresh

# Check rclone configuration
sudo -u camerabridge rclone config show

# Test Dropbox connection
sudo -u camerabridge rclone lsd dropbox:
```

---

## Updating Existing Machines

```bash
cd /opt/camera-bridge
git pull origin main
sudo systemctl restart camera-bridge
```

---

## Directory Structure

```
/opt/camera-bridge/
├── setup-new-machine.sh          # Interactive setup script
├── Topcom-main/
│   └── scripts/
│       ├── install-complete.sh   # Base system installer
│       ├── setup-wifi-hotspot.sh # WiFi AP setup
│       └── setup-brother-scanner.sh # Scanner setup
├── scripts/
│   ├── camera-bridge-service.sh  # Main service script
│   ├── terminal-ui.sh            # Configuration UI
│   └── dropbox-token-manager.sh  # OAuth2 token manager
├── config/
│   ├── camera-bridge.service     # Systemd service
│   ├── hostapd.conf              # WiFi AP config
│   └── dnsmasq-ap.conf           # DHCP config
└── web/
    ├── index.php                 # Web interface
    └── setup.php                 # Setup wizard

/srv/samba/camera-share/          # SMB share
├── photos/                       # Camera photos go here
└── scans/                        # Scanner output (if installed)

/var/log/camera-bridge/           # Service logs
```

---

## Features by Machine

You can customize each machine:

| Feature | Machine 1 | Machine 2 | Machine 3 |
|---------|-----------|-----------|-----------|
| Camera Bridge | ✓ | ✓ | ✓ |
| WiFi Hotspot | ✗ | ✓ | ✗ |
| Scanner | ✓ | ✓ | ✗ |

Each machine can have different features based on its hardware!

---

## Troubleshooting

### Camera Bridge Service Won't Start
```bash
# Check logs
sudo journalctl -u camera-bridge -n 50

# Check Dropbox token
sudo -u camerabridge rclone lsd dropbox:

# Increase timeout (if needed)
sudo nano /etc/systemd/system/camera-bridge.service
# Add: TimeoutStartSec=90
sudo systemctl daemon-reload
sudo systemctl restart camera-bridge
```

### WiFi Hotspot Not Working
```bash
# Check WiFi adapter
lsusb | grep -i "tp-link\|realtek"

# Check services
sudo systemctl status hostapd
sudo systemctl status dnsmasq

# View logs
sudo journalctl -u hostapd -f
```

### Scanner Not Detected
```bash
# Check USB connection
lsusb | grep -i brother

# Test SANE
scanimage -L

# Add user to scanner group
sudo usermod -a -G scanner $USER
# Logout and login
```

---

## Security Notes

- Service runs as dedicated `camerabridge` user (not root)
- OAuth2 tokens stored in `~camerabridge/.config/rclone/`
- Tokens encrypted by rclone
- SMB access requires password
- Web interface accessible only on local network

---

## Requirements

**Hardware:**
- Linux machine (Ubuntu/Debian recommended)
- (Optional) USB WiFi adapter for hotspot mode
- (Optional) Brother scanner for scanning

**Software:**
- Ubuntu 20.04+ or Debian 11+
- Internet connection for initial setup
- Dropbox account

---

## Support

For detailed guides, see:
- [SETUP_SECOND_MACHINE.md](SETUP_SECOND_MACHINE.md) - Full setup guide
- [UPDATE_EXISTING_MACHINE.md](UPDATE_EXISTING_MACHINE.md) - Update guide
- [BOOT_FIXES_APPLIED.md](BOOT_FIXES_APPLIED.md) - Boot configuration
- [Topcom-main/docs/](Topcom-main/docs/) - Additional documentation

---

## License

See [LICENSE](LICENSE) file.

---

**Ready to get started? Run:**

```bash
git clone https://github.com/tomganleylee/Topcom.git /opt/camera-bridge
cd /opt/camera-bridge
sudo bash setup-new-machine.sh
```
