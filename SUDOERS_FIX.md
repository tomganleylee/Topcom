# Sudoers Configuration Fix

## Problem
The camera-bridge system was prompting for a sudo password during bootup when the terminal UI was trying to load. This occurred because:

1. The camera-bridge service runs as root and uses `sudo -u camerabridge rclone` commands
2. The terminal UI (running as camerabridge user) uses many `sudo` commands for system management
3. No sudoers configuration existed to allow these commands without password prompts

## Solution
A comprehensive sudoers configuration file has been created at `/etc/sudoers.d/camera-bridge` with the following permissions:

### For Camera-Bridge Service (root user)
- Allows root to run rclone as camerabridge user without password
- Needed for: Camera monitoring and syncing to Dropbox

### For Terminal UI (camerabridge user)
- Allows camerabridge user to run system management commands without password
- Includes: systemctl, rclone, smbpasswd, mount, umount, apt, file operations, user management
- Needed for: Terminal UI system management features

### For Web Interface (www-data user)
- Allows www-data to manage configuration files and services
- Includes: File copy operations, network management, service control
- Needed for: Web-based configuration interface

## Updated Scripts

The following scripts have been updated with this sudoers configuration:

1. **[fix-boot-issues.sh](scripts/fix-boot-issues.sh)** - Boot issue fix script
2. **[install-complete.sh](scripts/install-complete.sh)** - Complete installation script
3. **[install-packages.sh](scripts/install-packages.sh)** - Package installation script

## Manual Application

If you need to manually apply this fix, run:

```bash
sudo /opt/camera-bridge/scripts/fix-boot-issues.sh
```

Or create the file manually:

```bash
sudo tee /etc/sudoers.d/camera-bridge << 'EOF'
# Allow camera-bridge service (running as root) to execute rclone as camerabridge user without password
root ALL=(camerabridge) NOPASSWD: /usr/bin/rclone

# Allow camerabridge user to run system commands without password for terminal UI and service management
camerabridge ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/rclone, /usr/sbin/smbpasswd, /bin/mount, /bin/umount, /usr/bin/apt, /usr/bin/apt-get, /bin/cp, /bin/rm, /bin/mkdir, /bin/chmod, /bin/chown, /usr/sbin/useradd, /opt/camera-bridge/scripts/wifi-manager.sh, /opt/camera-bridge/scripts/camera-bridge-service.sh, /usr/local/bin/terminal-ui-enhanced

# Allow www-data (web interface) to manage configuration files and services
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf
www-data ALL=(ALL) NOPASSWD: /bin/chown camerabridge\:camerabridge /home/camerabridge/.config/rclone/rclone.conf
www-data ALL=(ALL) NOPASSWD: /usr/sbin/iwlist
www-data ALL=(ALL) NOPASSWD: /opt/camera-bridge/scripts/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart wpa_supplicant
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart dhcpcd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart hostapd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart dnsmasq
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start hostapd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop hostapd
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start dnsmasq
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop dnsmasq
EOF

sudo chmod 440 /etc/sudoers.d/camera-bridge
sudo visudo -c -f /etc/sudoers.d/camera-bridge
```

## Verification

To verify the fix is working:

1. Check the sudoers file exists:
   ```bash
   sudo cat /etc/sudoers.d/camera-bridge
   ```

2. Test sudo commands work without password:
   ```bash
   sudo -u camerabridge rclone version
   ```

3. Reboot and confirm no password prompts appear

## Security Considerations

This configuration allows the camerabridge user to run system commands without a password. This is acceptable because:

1. The camerabridge user is a system service account
2. The device is intended to run in a controlled environment
3. The terminal UI requires these permissions for legitimate system management
4. Specific commands are listed rather than blanket ALL access (where possible)

## Date Applied
2025-10-10
