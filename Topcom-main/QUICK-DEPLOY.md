# Camera Bridge Quick Deployment Guide

## 🚀 One-Command Deployment

### Standard Installation (Camera Only)
```bash
cd /opt/camera-bridge/Topcom-main
sudo ./deploy-complete.sh
```

### With Brother DS-640 Scanner
```bash
cd /opt/camera-bridge/Topcom-main
sudo ./deploy-complete.sh --with-scanner
```

## 📋 What Gets Installed

### Core Features
- ✅ SMB share for camera photos
- ✅ Web interface for management
- ✅ Automatic Dropbox sync
- ✅ DHCP server for ethernet
- ✅ WiFi configuration
- ✅ Service auto-start on boot

### With Scanner (--with-scanner flag)
- ✅ Brother DS-640 drivers
- ✅ Scanner directory `/srv/scanner/scans`
- ✅ Scanner SMB share
- ✅ Automatic scan-to-Dropbox

## ⚙️ Post-Installation Setup

### 1. Fix Nginx (if needed)
```bash
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

### 2. Configure Dropbox
```bash
# Option A: Use setup script
sudo /opt/camera-bridge/Topcom-main/scripts/setup-dropbox-token.sh

# Option B: Via web interface
# Open browser: http://192.168.10.1
# Go to setup page and enter Dropbox token
```

### 3. Start Service
```bash
sudo systemctl start camera-bridge
sudo systemctl status camera-bridge
```

### 4. Connect Scanner (if installed)
```bash
# Connect Brother DS-640 via USB
lsusb | grep Brother

# Configure scanner
sudo brsaneconfig4 -a name=DS640 model=DS-640

# Test scanner
scanimage --test
```

## 🔍 Quick Checks

### Service Status
```bash
sudo systemctl status camera-bridge
sudo systemctl status smbd
sudo systemctl status nginx
```

### View Logs
```bash
sudo journalctl -u camera-bridge -f
```

### Test Dropbox Connection
```bash
sudo -u camerabridge rclone ls dropbox:
```

### Check Network
```bash
ip addr show
# Ethernet should show: 192.168.10.1
```

## 📁 File Locations

| Component | Location |
|-----------|----------|
| Scripts | `/opt/camera-bridge/scripts/` |
| Web Interface | `/opt/camera-bridge/web/` |
| Camera Photos | `/srv/samba/camera-share/` |
| Scanner Output | `/srv/scanner/scans/` |
| Service Logs | `/var/log/camera-bridge/` |
| Rclone Config | `/home/camerabridge/.config/rclone/` |

## 🌐 Network Access

| Service | Address | Credentials |
|---------|---------|-------------|
| Web Interface | `http://192.168.10.1` | None |
| SMB Photo Share | `\\192.168.10.1\photos` | camera / camera123 |
| SMB Scanner Share | `\\192.168.10.1\scanner` | camera / camera123 |
| SSH Access | `ssh user@192.168.10.1` | System user |

## 📤 Dropbox Folders

| Source | Dropbox Destination |
|--------|---------------------|
| Camera Photos | `Camera-Photos/` |
| Scanned Documents | `Scanned-Documents/` |

## 🛠️ Common Tasks

### Restart Services
```bash
sudo systemctl restart camera-bridge
sudo systemctl restart smbd
sudo systemctl restart nginx
```

### View Recent Syncs
```bash
sudo journalctl -u camera-bridge -n 50
```

### Manual Sync
```bash
sudo -u camerabridge rclone sync /srv/samba/camera-share dropbox:Camera-Photos
sudo -u camerabridge rclone sync /srv/scanner/scans dropbox:Scanned-Documents
```

### Update Web Interface
```bash
sudo chown -R www-data:www-data /opt/camera-bridge/web/
```

### Fix Permissions
```bash
sudo chown -R camera:camera /srv/samba/camera-share
sudo chown -R camerabridge:scanner /srv/scanner/scans
sudo chmod 775 /srv/samba/camera-share
sudo chmod 775 /srv/scanner/scans
```

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check Dropbox config exists
ls -la /home/camerabridge/.config/rclone/rclone.conf

# Check service status
sudo systemctl status camera-bridge

# View detailed logs
sudo journalctl -u camera-bridge -n 100
```

### Nginx Won't Start
```bash
# Test configuration
sudo nginx -t

# Check for duplicate default servers
ls -la /etc/nginx/sites-enabled/

# Remove duplicate
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

### WiFi Not Saving
```bash
# Check web directory permissions
ls -la /opt/camera-bridge/web/

# Fix permissions
sudo chown -R www-data:www-data /opt/camera-bridge/web/

# Check sudoers
sudo cat /etc/sudoers.d/camera-bridge
```

### Scanner Not Working
```bash
# Check USB connection
lsusb | grep Brother

# Check scanner group
groups camerabridge | grep scanner

# Reconfigure scanner
sudo brsaneconfig4 -d
sudo brsaneconfig4 -a name=DS640 model=DS-640

# Test scan
scanimage --test
```

### Files Not Syncing
```bash
# Check Dropbox connection
sudo -u camerabridge rclone lsd dropbox:

# Check monitoring service
sudo systemctl status camera-bridge

# Restart service
sudo systemctl restart camera-bridge

# Watch logs
sudo journalctl -u camera-bridge -f
```

## 📞 Need Help?

1. **Check logs first:**
   ```bash
   sudo journalctl -u camera-bridge -f
   ```

2. **Verify services:**
   ```bash
   sudo systemctl status camera-bridge smbd nginx
   ```

3. **Test Dropbox:**
   ```bash
   sudo -u camerabridge rclone ls dropbox:
   ```

4. **Check documentation:**
   - [SCANNER-SETUP.md](SCANNER-SETUP.md) - Scanner integration details
   - [DEPLOYMENT-V2.md](DEPLOYMENT-V2.md) - Deployment guide
   - [README.md](README.md) - Main documentation

## 🔄 Updating to Latest Version

```bash
cd /opt/camera-bridge/Topcom-main
git pull origin main
sudo ./deploy-complete.sh --with-scanner  # Or without --with-scanner
```

---

**Quick Deploy Version:** 2.1
**Last Updated:** October 2025
**Compatible Systems:** Ubuntu 20.04+, Debian 11+
