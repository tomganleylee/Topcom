# Camera Bridge - Update Instructions

## For Updating Your Other Machine

Follow these steps to update your other Camera Bridge installation with the latest changes:

### Prerequisites
- Your other machine should already have Camera Bridge installed
- You should have network access to the machine (SSH or direct access)
- The machine should have internet connectivity

### Update Steps

1. **Connect to your other machine**
   ```bash
   ssh camerabridge@<other-machine-ip>
   # OR access directly via console
   ```

2. **Navigate to the project directory**
   ```bash
   cd /path/to/camera-bridge
   # If you cloned to default location:
   cd ~/camera-bridge
   ```

3. **Pull the latest changes**
   ```bash
   git pull origin main
   ```

4. **Run the unified installer in update mode**
   ```bash
   sudo ./install.sh
   ```

   The installer will:
   - ✅ Detect existing installation automatically
   - ✅ Preserve your Dropbox configuration
   - ✅ Preserve your WiFi passwords
   - ✅ Preserve your SMB passwords
   - ✅ Update all system files and scripts
   - ✅ Restart services safely

5. **Verify the update**
   ```bash
   # Check services are running
   sudo systemctl status camera-bridge
   sudo systemctl status smbd
   sudo systemctl status dnsmasq

   # Check logs
   sudo journalctl -u camera-bridge -n 50
   ```

6. **Test functionality**
   - Connect a camera via ethernet
   - Check if it gets an IP address (192.168.10.x)
   - Test SMB access: `\\192.168.10.1\photos`
   - Upload a test photo and verify Dropbox sync

### What Changed in This Update

#### 🔒 Security Improvements
- Removed all sensitive credentials from repository
- Added security warnings in README
- Repository is now safe for public visibility

#### 🚀 New Unified Installer
- Single `install.sh` replaces multiple setup scripts
- Automatically detects if updating existing installation
- Preserves all your configurations during updates
- Idempotent design - safe to run multiple times

#### ⚙️ Better DHCP Configuration
- Improved ethernet DHCP setup
- Better network interface detection
- More reliable NAT configuration

#### 📦 Scanner Integration
- Brother scanner support now included in main installer
- Automatic setup during installation

### Troubleshooting

#### If Git Pull Fails
```bash
# If you have local modifications
git stash              # Save local changes
git pull origin main   # Pull updates
git stash pop          # Restore local changes (if needed)
```

#### If Update Seems to Fail
```bash
# Check if Dropbox config is still present
ls -la /home/camerabridge/.config/rclone/rclone.conf

# Check if services are running
sudo systemctl status camera-bridge smbd dnsmasq

# View detailed logs
sudo journalctl -xe
```

#### If DHCP Stops Working
```bash
# Restart DHCP server
sudo systemctl restart dnsmasq

# Check ethernet interface
ip addr show eno1  # or your ethernet interface name

# Check DHCP config
cat /etc/dnsmasq.d/camera-bridge.conf
```

### Rollback Instructions

If something goes wrong, you can rollback to the previous commit:

```bash
cd /path/to/camera-bridge
git log --oneline -5  # Find the commit before the update
git checkout <previous-commit-hash>
sudo ./install.sh     # Re-run installer with old code
```

Or restore from backup configs:
```bash
# Samba config
sudo cp /etc/samba/smb.conf.backup-* /etc/samba/smb.conf
sudo systemctl restart smbd

# dnsmasq config
sudo cp /etc/dnsmasq.d/camera-bridge.conf.backup-* /etc/dnsmasq.d/camera-bridge.conf
sudo systemctl restart dnsmasq
```

### Getting Help

If you encounter issues:
1. Check the logs: `sudo journalctl -u camera-bridge -f`
2. Review the installation output
3. Check service status: `sudo systemctl status camera-bridge`
4. Open an issue on GitHub: https://github.com/tomganleylee/Topcom/issues

### Important Notes

- ⚠️ The update preserves your configurations, but it's always good to have backups
- ⚠️ Your Dropbox token will NOT be changed - the update preserves it
- ⚠️ Your SMB password will NOT be changed (unless you want to change it)
- ✅ The update is designed to be non-destructive and safe
- ✅ You can run the installer multiple times if needed

### After Update - Optional Steps

1. **Change default passwords** (if you haven't already):
   ```bash
   # SMB password
   sudo smbpasswd camera

   # System user password
   sudo passwd camerabridge
   ```

2. **Verify network configuration**:
   ```bash
   ip addr show eno1  # Check ethernet IP
   sudo systemctl status dnsmasq  # Check DHCP
   ```

3. **Test from camera**:
   - Connect camera to ethernet
   - Should get IP 192.168.10.x automatically
   - Access SMB share: `\\192.168.10.1\photos`

---

## Quick Reference

### Useful Commands

```bash
# Update the system
cd camera-bridge && git pull && sudo ./install.sh

# Check service status
sudo systemctl status camera-bridge

# View live logs
sudo journalctl -u camera-bridge -f

# Restart services
sudo systemctl restart camera-bridge
sudo systemctl restart smbd
sudo systemctl restart dnsmasq

# Test Dropbox connection
sudo -u camerabridge rclone lsd dropbox:

# Manual sync
sudo -u camerabridge rclone copy /srv/samba/camera-share dropbox:Camera-Photos
```

### Default Credentials (change these!)

- **SMB Share**: username: `camera`, password: `camera123`
- **System User**: username: `camerabridge`, password: (set during install)
- **Web Interface**: No authentication (access via http://192.168.10.1)

### Network Details

- **Ethernet IP**: 192.168.10.1
- **DHCP Range**: 192.168.10.10 - 192.168.10.50
- **SMB Share**: `\\192.168.10.1\photos`
- **Web Interface**: `http://192.168.10.1`

---

**Generated**: 2025-11-04
**Version**: 3.0 (Unified Installer Update)
