# Camera Bridge Deployment Guide

This guide covers different deployment scenarios for the Camera Bridge system, from single-device setups to multi-location deployments.

## 📋 Deployment Scenarios

### 1. Single Photographer Studio
**Best for**: Individual photographers with 1-2 cameras
- **Hardware**: Raspberry Pi 4 (4GB) or dedicated PC
- **Network**: Simple WiFi/Ethernet setup
- **Storage**: 32GB SD card + optional USB storage
- **Cameras**: 1-2 network-capable cameras

### 2. Photography Studio/Agency
**Best for**: Multiple photographers, shared workspace
- **Hardware**: Dedicated PC or high-end Pi
- **Network**: Wired ethernet for stability
- **Storage**: SSD for performance, network backup
- **Cameras**: Multiple cameras, possibly different models

### 3. Event Photography
**Best for**: Portable setup for events/weddings
- **Hardware**: Raspberry Pi with battery pack
- **Network**: Mobile hotspot or venue WiFi
- **Storage**: High-speed SD card + backup drive
- **Cameras**: Multiple event photographers

### 4. Multi-Location Chain
**Best for**: Photography chains, multiple studios
- **Hardware**: Standardized Pi deployments
- **Network**: Site-to-site VPN for management
- **Storage**: Centralized cloud storage
- **Cameras**: Standardized camera configurations

## 🎯 Deployment Methods

### Method 1: USB Installer (Fastest)

**Use case**: Raspberry Pi deployments, multiple identical setups

1. **Create USB Installer**
```bash
# On development machine
sudo ./raspberry-pi/scripts/create-usb-installer.sh /dev/sdX
```

2. **Deploy to Target Device**
```bash
# On Raspberry Pi
sudo ./quick-setup.sh
# System reboots automatically
```

**Pros**:
- Fastest deployment (15-20 minutes)
- Consistent configuration
- Works offline after initial setup
- Perfect for multiple identical deployments

**Cons**:
- Requires USB drive creation
- Pi-specific only

### Method 2: Network Installation

**Use case**: Remote deployment, existing systems

1. **Remote Package Installation**
```bash
# Via SSH to target device
curl -sSL https://github.com/your-repo/camera-bridge/raw/main/scripts/install-packages.sh | sudo bash
```

2. **Configuration Transfer**
```bash
# From management machine
scp -r config/ user@target-ip:/tmp/
ssh user@target-ip "sudo cp -r /tmp/config/* /opt/camera-bridge/config/"
```

**Pros**:
- No physical access needed
- Can be scripted/automated
- Works on any supported platform

**Cons**:
- Requires network access
- More complex troubleshooting

### Method 3: Manual Installation

**Use case**: Custom configurations, development environments

1. **System Preparation**
```bash
sudo apt update && sudo apt upgrade -y
git clone <repository-url> camera-bridge
cd camera-bridge
```

2. **Platform-Specific Installation**
```bash
# For Ubuntu/Debian
sudo ./scripts/install-packages.sh

# For Raspberry Pi
sudo ./raspberry-pi/scripts/install-rpi.sh
sudo ./raspberry-pi/scripts/setup-rpi.sh
```

**Pros**:
- Maximum control
- Custom configurations possible
- Best for development

**Cons**:
- Takes longest (30-45 minutes)
- More error-prone
- Requires technical knowledge

## 🔧 Configuration Management

### Centralized Configuration

For multiple deployments, create configuration templates:

1. **Create Configuration Package**
```bash
# On management machine
mkdir camera-bridge-config
cd camera-bridge-config

# Copy base configurations
cp ../camera-bridge/config/* .

# Customize for deployment
sed -i 's/CameraBridge-Setup/Studio-Camera-01/' hostapd.conf
sed -i 's/camera123/SecurePass123/' smb.conf
```

2. **Deploy Configuration**
```bash
# Package configuration
tar czf camera-bridge-config.tar.gz *

# Deploy to target
scp camera-bridge-config.tar.gz user@target-ip:/tmp/
ssh user@target-ip "cd /tmp && tar xzf camera-bridge-config.tar.gz && sudo cp * /opt/camera-bridge/config/"
```

### Environment-Specific Configurations

**Development Environment**
```bash
# Minimal logging, debug enabled
export CAMERA_BRIDGE_DEBUG=1
export CAMERA_BRIDGE_LOG_LEVEL=debug
```

**Production Environment**
```bash
# Performance optimized, secure defaults
export CAMERA_BRIDGE_LOG_LEVEL=info
export CAMERA_BRIDGE_MAX_SYNC_CONCURRENT=5
```

**Event Environment**
```bash
# Battery optimized, local storage priority
export CAMERA_BRIDGE_POWER_SAVE=1
export CAMERA_BRIDGE_SYNC_INTERVAL=300
```

## 📊 Monitoring and Management

### Single Device Management

**Local Management**
```bash
# Terminal interface
camera-bridge-ui

# Quick status
systemctl status camera-bridge
df -h
free -h
```

**Web Management**
- Access: `http://device-ip`
- Features: Status, basic configuration
- Mobile friendly for on-site checks

### Multi-Device Management

**Centralized Monitoring Setup**
1. Install monitoring tools on management server
2. Configure SSH key authentication
3. Deploy monitoring scripts to all devices

**Management Script Example**
```bash
#!/bin/bash
# deploy-monitor.sh

DEVICES=(
    "192.168.1.100:studio-1"
    "192.168.1.101:studio-2"
    "192.168.1.102:mobile-1"
)

for device in "${DEVICES[@]}"; do
    IP="${device%:*}"
    NAME="${device#*:}"

    echo "Checking $NAME ($IP)..."
    ssh pi@$IP "systemctl is-active camera-bridge" || echo "$NAME: Service down!"
done
```

**Health Check Automation**
```bash
# Add to cron on management server
*/15 * * * * /opt/monitor/deploy-monitor.sh > /var/log/camera-bridge-fleet.log
```

## 🔒 Security Hardening

### Network Security

**WiFi Security**
```bash
# Strong WPA2/WPA3 passwords
wifi-manager.sh connect "StudioWiFi" "ComplexPassword123!"

# Hide SSID broadcast (optional)
echo "ignore_broadcast_ssid=1" >> /etc/hostapd/hostapd.conf
```

**SMB Security**
```bash
# Change default passwords
sudo smbpasswd camera
# Enter strong password

# Restrict SMB access
echo "hosts allow = 192.168.1.0/24" >> /etc/samba/smb.conf
```

**SSH Security**
```bash
# Disable password authentication
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Use key-based authentication only
ssh-copy-id user@camera-bridge-device
```

### Application Security

**Service Isolation**
```bash
# Run services with minimal privileges
systemctl edit camera-bridge
```
Add to override:
```ini
[Service]
User=camerabridge
Group=camerabridge
NoNewPrivileges=true
```

**File System Security**
```bash
# Encrypt sensitive directories
sudo apt install ecryptfs-utils
sudo mount -t ecryptfs /home/camerabridge/.config/rclone /home/camerabridge/.config/rclone
```

## 📦 Backup and Recovery

### Configuration Backup

**Automated Backup Script**
```bash
#!/bin/bash
# backup-config.sh

BACKUP_DIR="/var/backups/camera-bridge"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup configurations
tar czf "$BACKUP_DIR/config-$DATE.tar.gz" \
    /opt/camera-bridge/config/ \
    /home/camerabridge/.config/rclone/ \
    /etc/samba/smb.conf \
    /etc/systemd/system/camera-bridge.service

# Keep only last 30 days
find "$BACKUP_DIR" -name "config-*.tar.gz" -mtime +30 -delete

echo "Configuration backed up to $BACKUP_DIR/config-$DATE.tar.gz"
```

**Recovery Process**
```bash
# Stop services
sudo systemctl stop camera-bridge smbd

# Restore configuration
sudo tar xzf /var/backups/camera-bridge/config-YYYYMMDD_HHMMSS.tar.gz -C /

# Restart services
sudo systemctl start camera-bridge smbd
```

### System Image Backup (Raspberry Pi)

**Create System Image**
```bash
# On another Linux machine
sudo dd if=/dev/sdX of=camera-bridge-backup.img bs=4M status=progress
gzip camera-bridge-backup.img
```

**Restore System Image**
```bash
# Restore to new SD card
gunzip camera-bridge-backup.img.gz
sudo dd if=camera-bridge-backup.img of=/dev/sdX bs=4M status=progress
```

## ⚡ Performance Optimization

### Raspberry Pi Optimizations

**SD Card Longevity**
```bash
# Run optimization script
sudo /opt/camera-bridge/scripts/sd-card-maintenance.sh

# Move logs to RAM (optional)
sudo /opt/camera-bridge/scripts/sd-card-maintenance.sh --minimal-logging
```

**CPU/Memory Optimization**
```bash
# Increase GPU memory split for headless operation
echo "gpu_mem=16" >> /boot/firmware/config.txt

# Disable unused services
sudo systemctl disable bluetooth
sudo systemctl disable cups
```

### Network Optimization

**Bandwidth Management**
```bash
# Limit sync bandwidth during business hours
# Add to crontab
0 9 * * * echo "100" > /sys/class/net/wlan0/queues/tx-0/tx_maxrate
0 17 * * * echo "0" > /sys/class/net/wlan0/queues/tx-0/tx_maxrate
```

**Connection Prioritization**
```bash
# Prioritize wired over wireless
echo "metric 100" >> /etc/dhcpcd.conf  # Ethernet
echo "metric 200" >> /etc/dhcpcd.conf  # WiFi
```

## 📈 Scaling Considerations

### Horizontal Scaling

**Load Distribution**
- Deploy multiple devices per location
- Use different Dropbox accounts/folders
- Implement camera-to-device assignment

**Geographic Distribution**
- Deploy devices in multiple locations
- Use site-specific Dropbox folders
- Implement centralized monitoring

### Vertical Scaling

**Hardware Upgrades**
- Raspberry Pi 4 → High-end Pi or PC
- Faster SD cards → SSD storage
- USB 3.0 storage for local buffering

**Software Optimization**
- Increase concurrent sync jobs
- Implement compression before upload
- Add local caching layers

## 🚀 Automation and Integration

### Deployment Automation

**Ansible Playbook Example**
```yaml
# camera-bridge-deploy.yml
- hosts: camera_bridges
  become: yes
  tasks:
    - name: Update system
      apt:
        update_cache: yes
        upgrade: yes

    - name: Install Camera Bridge
      script: /path/to/install-packages.sh

    - name: Configure services
      systemd:
        name: "{{ item }}"
        enabled: yes
        state: started
      loop:
        - camera-bridge
        - smbd
        - nginx
```

**Deploy with Ansible**
```bash
ansible-playbook -i inventory camera-bridge-deploy.yml
```

### Integration APIs

**Status API**
```bash
# Get status via web API
curl http://camera-bridge-ip/api/status.php

# Get logs via API
curl http://camera-bridge-ip/api/logs.php?lines=50
```

**Webhook Integration**
```bash
# Configure webhooks for events
echo "WEBHOOK_URL=https://your-monitoring-system/webhook" >> /opt/camera-bridge/.env
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Hardware requirements verified
- [ ] Network architecture planned
- [ ] Security requirements defined
- [ ] Dropbox accounts created
- [ ] Installation method chosen

### Deployment
- [ ] System installed and updated
- [ ] Camera Bridge installed
- [ ] Network configured
- [ ] Dropbox connected
- [ ] Cameras configured
- [ ] Testing completed

### Post-Deployment
- [ ] Monitoring configured
- [ ] Backup strategy implemented
- [ ] Security hardening applied
- [ ] Documentation updated
- [ ] User training completed

### Ongoing Maintenance
- [ ] Regular health checks
- [ ] Log rotation configured
- [ ] Update procedures defined
- [ ] Backup testing scheduled
- [ ] Performance monitoring active

## 🔄 Update Procedures

### Rolling Updates

**For Multiple Devices**
```bash
#!/bin/bash
# rolling-update.sh

DEVICES=("192.168.1.100" "192.168.1.101" "192.168.1.102")

for device in "${DEVICES[@]}"; do
    echo "Updating $device..."

    # Upload new code
    scp -r camera-bridge/ pi@$device:/tmp/

    # Install update
    ssh pi@$device "sudo /tmp/camera-bridge/scripts/update.sh"

    # Verify update
    sleep 30
    ssh pi@$device "systemctl is-active camera-bridge" || {
        echo "Update failed on $device"
        exit 1
    }

    echo "$device updated successfully"
done
```

### Rollback Procedures

**Quick Rollback**
```bash
# Stop current version
sudo systemctl stop camera-bridge

# Restore previous version
sudo tar xzf /var/backups/camera-bridge/camera-bridge-previous.tar.gz -C /opt/

# Restart service
sudo systemctl start camera-bridge
```

This deployment guide ensures reliable, scalable, and secure Camera Bridge deployments across various scenarios and environments.