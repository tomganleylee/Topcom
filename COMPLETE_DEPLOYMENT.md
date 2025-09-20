# Camera Bridge Complete Deployment Guide

This guide provides step-by-step instructions for deploying the Camera Bridge system to a new Ubuntu/Debian machine, including all services, auto-start configurations, and remote access via Tailscale.

## Prerequisites

- Ubuntu 20.04+ or Debian 11+ (tested on Ubuntu 24.04)
- Minimum 2GB RAM, 8GB storage
- Internet connection for initial setup
- sudo/root access
- Git installed (`sudo apt install git`)

## Quick Deployment

For fastest deployment, use the master deployment script after cloning:

```bash
git clone https://github.com/yourusername/camera-bridge.git
cd camera-bridge
sudo ./deploy-system.sh
```

## Detailed Deployment Steps

### Step 1: Clone Repository

```bash
cd ~
git clone https://github.com/yourusername/camera-bridge.git
cd camera-bridge
```

### Step 2: Install Camera Bridge System

```bash
# Install all required packages
sudo ./scripts/install-packages.sh

# Create system user and directories
sudo useradd -r -s /bin/false camerabridge || true
sudo mkdir -p /srv/samba/camera-share
sudo mkdir -p /opt/camera-bridge/{scripts,web,config}
sudo mkdir -p /var/log/camera-bridge
sudo chown -R camerabridge:camerabridge /srv/samba/camera-share
sudo chown -R camerabridge:camerabridge /var/log/camera-bridge
```

### Step 3: Copy System Files

```bash
# Copy scripts
sudo cp scripts/*.sh /opt/camera-bridge/scripts/
sudo chmod +x /opt/camera-bridge/scripts/*.sh
sudo chown -R camerabridge:camerabridge /opt/camera-bridge/scripts/

# Copy web interface
sudo cp -r web/* /opt/camera-bridge/web/
sudo chown -R www-data:www-data /opt/camera-bridge/web/

# Copy configurations
sudo cp config/* /opt/camera-bridge/config/
```

### Step 4: Configure Services

#### 4.1 Samba (File Sharing)
```bash
# Backup original config
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Apply our configuration
sudo cp config/smb.conf /etc/samba/smb.conf

# Set Samba password (use 'camera' for default)
echo -e "camera\ncamera" | sudo smbpasswd -a -s camera

# Restart Samba
sudo systemctl restart smbd
sudo systemctl enable smbd
```

#### 4.2 Nginx (Web Server)
```bash
# Copy nginx configuration
sudo cp config/nginx-camera-bridge.conf /etc/nginx/sites-available/camera-bridge
sudo ln -sf /etc/nginx/sites-available/camera-bridge /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl enable nginx
```

#### 4.3 Camera Bridge Service
```bash
# Copy systemd service file
sudo cp config/camera-bridge.service /etc/systemd/system/

# Copy token refresh service and timer
sudo cp config/dropbox-token-refresh.service /etc/systemd/system/
sudo cp config/dropbox-token-refresh.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable services (don't start yet - need Dropbox token first)
sudo systemctl enable camera-bridge.service
sudo systemctl enable dropbox-token-refresh.timer
```

### Step 5: Configure Dropbox

```bash
# Install rclone if not already installed
curl https://rclone.org/install.sh | sudo bash

# Configure Dropbox
sudo -u camerabridge rclone config
```

Follow the prompts:
1. Type 'n' for new remote
2. Name: `dropbox`
3. Storage: Choose Dropbox number
4. Leave client_id and client_secret blank
5. Follow OAuth2 authorization
6. Confirm configuration

Test the connection:
```bash
sudo -u camerabridge rclone lsd dropbox:
```

### Step 6: Set Up Auto-Start and Auto-Login

```bash
# Run the auto-start setup script
sudo ./deployment/autostart/setup-camera-bridge-autostart.sh

# For auto-login (if needed for desktop systems)
sudo ./deployment/autostart/setup-camerabridge-autologin.sh
```

### Step 7: Install and Configure Tailscale (Remote Access)

#### 7.1 Initial Installation
```bash
# Install Tailscale
sudo ./deployment/tailscale/install-tailscale-safe.sh

# Configure for SSH access
sudo ./deployment/tailscale/configure-tailscale-ssh.sh
```

#### 7.2 Set Up Permanent Connection
```bash
# Run permanent setup
sudo ./deployment/tailscale/tailscale-permanent-setup.sh
```

**IMPORTANT**: After running the script, go to https://login.tailscale.com/admin/machines and disable key expiry for this machine.

#### 7.3 For Future Deployments
Get a pre-auth key from https://login.tailscale.com/admin/settings/keys and use:
```bash
TAILSCALE_AUTH_KEY='tskey-auth-XXX' sudo ./deployment/tailscale/tailscale-deploy-with-key.sh
```

### Step 8: Start All Services

```bash
# Start Camera Bridge service
sudo systemctl start camera-bridge
sudo systemctl start dropbox-token-refresh.timer

# Check status
sudo systemctl status camera-bridge
sudo systemctl status smbd
sudo systemctl status nginx
sudo systemctl status tailscaled
```

### Step 9: Verify Installation

#### Check Services
```bash
# All services should be active
systemctl is-active camera-bridge smbd nginx tailscaled
```

#### Check Web Interface
- Local: http://localhost or http://[machine-ip]
- Via Tailscale: http://[tailscale-ip]

#### Check SMB Share
- Windows: `\\[machine-ip]\camera-share`
- Linux: `smb://[machine-ip]/camera-share`
- Credentials: username `camera`, password `camera`

#### Check Tailscale Access
```bash
# Get Tailscale IP
tailscale ip -4

# SSH from another machine
ssh user@[tailscale-ip]
```

## System Monitoring

### Monitor Services
```bash
# Camera Bridge logs
tail -f /var/log/camera-bridge/service.log

# Tailscale keepalive
tail -f /var/log/tailscale-keepalive.log

# Service status
./simple-monitor.sh
```

### Manual Operations
```bash
# Force sync now
./sync-now.sh

# Manual sync with specific folder
./manual-sync.sh /path/to/photos

# Check system info
/opt/camera-bridge/scripts/pi-system-info.sh
```

## File Locations Reference

### Configuration Files
- Dropbox config: `/home/camerabridge/.config/rclone/rclone.conf`
- Samba config: `/etc/samba/smb.conf`
- Nginx config: `/etc/nginx/sites-available/camera-bridge`
- Service config: `/etc/systemd/system/camera-bridge.service`

### Data Locations
- Photo share: `/srv/samba/camera-share/`
- Logs: `/var/log/camera-bridge/`
- Scripts: `/opt/camera-bridge/scripts/`
- Web files: `/opt/camera-bridge/web/`

### Tailscale Files
- Keepalive: `/usr/local/bin/tailscale-keepalive.sh`
- Recovery: `/usr/local/bin/tailscale-recover.sh`
- State: `/var/lib/tailscale/`

## Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u camera-bridge -n 50

# Verify permissions
ls -la /srv/samba/camera-share
ls -la /var/log/camera-bridge

# Test Dropbox connection
sudo -u camerabridge rclone lsd dropbox:
```

### SMB Share Not Accessible
```bash
# Check Samba status
sudo systemctl status smbd
testparm

# Check network binding
netstat -an | grep :445
```

### Tailscale Connection Issues
```bash
# Check status
tailscale status

# Restart keepalive
sudo systemctl restart tailscale-keepalive

# Manual recovery
sudo /usr/local/bin/tailscale-recover.sh
```

### Web Interface Not Loading
```bash
# Check Nginx
sudo nginx -t
sudo systemctl status nginx

# Check PHP
sudo systemctl status php*-fpm
```

## Security Considerations

### Change Default Passwords
```bash
# Change Samba password
sudo smbpasswd camera

# Set strong system passwords
sudo passwd camerabridge
```

### Firewall Configuration
```bash
# Allow necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 445/tcp   # SMB
sudo ufw allow 41641/udp # Tailscale
sudo ufw enable
```

### Restrict Access
- Use Tailscale ACLs to limit SSH access
- Configure Samba to only allow local network
- Set up fail2ban for brute force protection

## Backup and Recovery

### Backup Configuration
```bash
# Create backup
tar czf camera-bridge-backup-$(date +%Y%m%d).tar.gz \
  /opt/camera-bridge/config/ \
  /home/camerabridge/.config/rclone/ \
  /etc/samba/smb.conf \
  /etc/systemd/system/camera-bridge* \
  /etc/nginx/sites-available/camera-bridge
```

### Restore from Backup
```bash
# Extract backup
tar xzf camera-bridge-backup-*.tar.gz -C /

# Reload services
sudo systemctl daemon-reload
sudo systemctl restart camera-bridge smbd nginx
```

## Updating the System

```bash
# Pull latest changes
cd ~/camera-bridge
git pull

# Update scripts
sudo cp scripts/*.sh /opt/camera-bridge/scripts/
sudo chmod +x /opt/camera-bridge/scripts/*.sh

# Restart services
sudo systemctl restart camera-bridge
```

## Uninstallation

If you need to remove the system:

```bash
# Stop services
sudo systemctl stop camera-bridge
sudo systemctl disable camera-bridge
sudo systemctl stop dropbox-token-refresh.timer
sudo systemctl disable dropbox-token-refresh.timer

# Remove files
sudo rm -rf /opt/camera-bridge
sudo rm -rf /srv/samba/camera-share
sudo rm /etc/systemd/system/camera-bridge*
sudo rm /etc/nginx/sites-enabled/camera-bridge

# Remove user
sudo userdel camerabridge

# Remove Tailscale (optional)
sudo tailscale down
sudo systemctl disable tailscaled
sudo apt remove tailscale
```

## Support

For issues or questions:
1. Check logs: `/var/log/camera-bridge/service.log`
2. Run diagnostics: `./test-ready.sh`
3. Review this documentation
4. Check service status: `systemctl status camera-bridge`

---

Last updated: September 2024
Version: 2.0