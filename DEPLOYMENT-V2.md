# Camera Bridge - Production Deployment Guide

## Quick Deploy (2 Commands)

```bash
# 1. Install everything
sudo ./scripts/install-complete.sh

# 2. Configure Dropbox (have your token ready)
sudo ./scripts/setup-dropbox-token.sh
```

That's it! Your Camera Bridge is ready.

## What Gets Installed

### Network Services
- **Ethernet DHCP**: 192.168.10.1 (gives IPs .10-.50)
- **SMB Share**: Available at `\\192.168.10.1\photos`
- **Web Interface**: http://192.168.10.1/
- **NAT/Forwarding**: Laptops get internet through WiFi

### Automatic Features
- ✅ Service starts on boot
- ✅ Real-time photo monitoring
- ✅ Instant Dropbox sync
- ✅ Auto-restart on failure
- ✅ Works with any WiFi interface name
- ✅ Works with any ethernet interface name

### Fixed Issues from v1
- ✅ nmbd hanging - disabled (not needed)
- ✅ SMB binding - listens on all interfaces
- ✅ DHCP conflicts - clean config
- ✅ Service startup - simplified monitoring
- ✅ Interface detection - auto-detects wlp1s0, eno1, etc.

## Testing Your Deployment

### 1. Check Services
```bash
sudo systemctl status camera-bridge
sudo systemctl status smbd
sudo systemctl status dnsmasq
```

### 2. Test from Laptop
1. Connect ethernet cable
2. Should get IP: 192.168.10.x
3. Open: `\\192.168.10.1\photos`
4. Login: `camera` / `camera123`
5. Drop photo → Check Dropbox

### 3. Monitor Sync
```bash
sudo journalctl -u camera-bridge -f
```

## Credentials

### SMB Share
- Username: `camera`
- Password: `camera123`

### System User
- User: `camerabridge`
- Runs the sync service

## File Locations

```
/srv/samba/camera-share/        # SMB share directory
/opt/camera-bridge/scripts/     # Service scripts
/opt/camera-bridge/web/         # Web interface
/var/log/camera-bridge/         # Logs
/home/camerabridge/.config/rclone/  # Dropbox config
```

## Troubleshooting

### Service Won't Start
```bash
# Check if Dropbox is configured
ls -la /home/camerabridge/.config/rclone/rclone.conf

# If not, configure it
sudo ./scripts/setup-dropbox-token.sh
```

### No DHCP on Ethernet
```bash
# Restart dnsmasq
sudo systemctl restart dnsmasq

# Check ethernet IP
ip addr show eno1  # or your ethernet interface
```

### SMB Not Accessible
```bash
# Check if listening
netstat -tuln | grep 445

# Restart SMB
sudo systemctl restart smbd
```

### Files Not Syncing
```bash
# Check service logs
sudo journalctl -u camera-bridge -n 50

# Manually test sync
sudo -u camerabridge rclone ls dropbox:Camera-Photos/
```

## Updates from GitHub

```bash
cd camera-bridge
git pull
sudo ./scripts/install-complete.sh
```

## Customization

### Change SMB Password
```bash
sudo smbpasswd camera
```

### Change DHCP Range
Edit `/etc/dnsmasq.d/camera-bridge.conf`

### Change Dropbox Folder
Edit `/opt/camera-bridge/scripts/monitor-service.sh`
Change `DROPBOX_DEST="dropbox:Camera-Photos"`

## Performance

- **Detection**: Instant (inotify)
- **Sync delay**: 3 seconds (file stabilization)
- **Upload speed**: Depends on internet
- **Typical photo (5MB)**: 5-10 seconds total

## Security Notes

- SMB requires authentication
- No guest access enabled
- Service runs as non-root user
- Dropbox token is protected (mode 600)

## Version History

### v2.0 (Current)
- Complete rewrite of installation
- All production fixes included
- Auto-detects network interfaces
- Simplified monitoring service
- Better error handling

### v1.0
- Initial implementation
- Required manual fixes

---

For issues or questions, check the logs first:
```bash
sudo journalctl -u camera-bridge -f
```