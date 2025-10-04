# Remote Deployment Guide

This guide explains how to deploy Camera Bridge to a new machine with minimal effort.

## Prerequisites

### On Source Machine (Current Setup)
- ✓ Working Camera Bridge installation
- ✓ SSH access to remote machine
- ✓ SSH keys configured (passwordless login recommended)

### On Target Machine (New Setup)
- Ubuntu/Debian Linux installation
- SSH server running
- User with sudo privileges
- Internet connection
- Minimum 10GB free disk space

## Method 1: Automated One-Command Deployment (Recommended)

### Quick Start

```bash
# From your current machine with Camera Bridge installed
cd /opt/camera-bridge
sudo ./scripts/deploy-remote.sh <remote-host> [remote-user]
```

### Examples

```bash
# Deploy to IP address (uses current username)
sudo ./scripts/deploy-remote.sh 192.168.1.100

# Deploy with specific username
sudo ./scripts/deploy-remote.sh 192.168.1.100 ubuntu

# Deploy using user@host format
sudo ./scripts/deploy-remote.sh ubuntu@camera-bridge-2.local
```

### What It Does

The deployment script automatically:

1. **Tests SSH Connection** - Verifies you can connect to remote machine
2. **Clones Repository** - Downloads Camera Bridge from GitHub to `/opt/camera-bridge`
3. **Installs Packages** - Runs `install-packages.sh` to install all dependencies
4. **Configures Services** - Sets up Samba, nginx, dnsmasq, systemd services
5. **Copies Dropbox Credentials** (optional) - Transfers rclone config from current machine
6. **Starts Services** - Enables and starts all camera-bridge services
7. **Verifies Installation** - Checks that everything is running

### Setup SSH Keys (First Time)

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "camera-bridge-deployment"

# Copy SSH key to remote machine
ssh-copy-id user@remote-host

# Test connection
ssh user@remote-host
```

### Post-Deployment Steps

After automated deployment:

1. **SSH to remote machine:**
   ```bash
   ssh user@remote-host
   ```

2. **Verify Dropbox connection:**
   ```bash
   sudo -u camerabridge rclone lsd dropbox:
   ```

   If credentials weren't copied, configure manually:
   ```bash
   sudo -u camerabridge rclone config
   ```

3. **Check service status:**
   ```bash
   sudo /usr/local/bin/terminal-ui
   ```

4. **Adjust network configuration if needed:**
   ```bash
   # Check interfaces
   ip addr show

   # Update dnsmasq config if interface names differ
   sudo nano /etc/dnsmasq.d/camera-bridge.conf

   # Update Samba config
   sudo nano /opt/camera-bridge/config/smb.conf
   ```

5. **Configure WiFi (if needed):**
   ```bash
   sudo /opt/camera-bridge/scripts/wifi-manager.sh
   ```

## Method 2: Manual Step-by-Step Deployment

If you prefer manual control or the automated script doesn't work:

### Step 1: Prepare Remote Machine

SSH to the remote machine:
```bash
ssh user@remote-host
```

### Step 2: Clone Repository

```bash
cd /tmp
git clone https://github.com/tomganleylee/Topcom.git
sudo mv Topcom /opt/camera-bridge
cd /opt/camera-bridge
```

### Step 3: Run Installation

```bash
sudo bash scripts/install-packages.sh
```

This installs:
- System packages (hostapd, dnsmasq, nginx, samba, etc.)
- rclone for Dropbox sync
- Creates users (camerabridge, camera)
- Sets up directory structure
- Configures services

### Step 4: Configure Dropbox

Option A - Copy credentials from existing machine:
```bash
# On source machine
scp /home/camerabridge/.config/rclone/rclone.conf user@remote-host:/tmp/

# On remote machine
sudo mkdir -p /home/camerabridge/.config/rclone
sudo mv /tmp/rclone.conf /home/camerabridge/.config/rclone/
sudo chown -R camerabridge:camerabridge /home/camerabridge/.config
sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf
```

Option B - Configure fresh Dropbox connection:
```bash
sudo -u camerabridge rclone config
# Follow prompts to set up Dropbox
```

### Step 5: Adjust Network Configuration

Check your network interface names:
```bash
ip addr show
```

Update dnsmasq configuration:
```bash
sudo nano /etc/dnsmasq.d/camera-bridge.conf
```

Update interface name if different from `eno1`:
```
interface=YOUR_INTERFACE_NAME
dhcp-range=interface:YOUR_INTERFACE_NAME,192.168.10.10,192.168.10.50,255.255.255.0,24h
```

Update Samba configuration:
```bash
sudo nano /opt/camera-bridge/config/smb.conf
```

### Step 6: Start Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable camera-bridge
sudo systemctl start camera-bridge
sudo systemctl enable smbd nmbd
sudo systemctl restart smbd nmbd
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq
```

### Step 7: Verify Installation

```bash
# Check services
sudo systemctl status camera-bridge
sudo systemctl status smbd
sudo systemctl status dnsmasq

# Test Dropbox
sudo -u camerabridge rclone lsd dropbox:

# Check SMB share
ls -la /srv/samba/camera-share

# Open terminal UI
sudo /usr/local/bin/terminal-ui
```

## Method 3: Clone Entire System (Advanced)

For identical hardware, you can clone the entire disk:

### Option A: Using dd (Requires Downtime)

```bash
# On source machine (boot from USB)
sudo dd if=/dev/sda of=/path/to/backup.img bs=64K conv=sync,noerror status=progress

# On target machine (boot from USB)
sudo dd if=/path/to/backup.img of=/dev/sda bs=64K status=progress
```

### Option B: Using Clonezilla

1. Boot source machine with Clonezilla
2. Create disk image
3. Boot target machine with Clonezilla
4. Restore disk image
5. Adjust network configuration (hostname, IP, etc.)

### Post-Clone Adjustments

```bash
# Change hostname
sudo hostnamectl set-hostname camera-bridge-2

# Regenerate SSH host keys
sudo rm /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server

# Update network configuration if needed
sudo nano /etc/netplan/*.yaml
```

## Method 4: Export/Import Configuration Only

If target machine already has Ubuntu installed:

### Export Configuration (Source Machine)

```bash
# Create backup archive
cd /opt/camera-bridge
sudo tar -czf camera-bridge-config.tar.gz \
    scripts/ \
    web/ \
    config/ \
    docs/ \
    /etc/dnsmasq.d/camera-bridge.conf \
    /etc/systemd/system/camera-bridge*.service \
    /home/camerabridge/.config/rclone/rclone.conf

# Transfer to target
scp camera-bridge-config.tar.gz user@remote-host:/tmp/
```

### Import Configuration (Target Machine)

```bash
# Install base packages
sudo apt update
sudo apt install -y samba nginx rclone dnsmasq hostapd

# Extract configuration
cd /
sudo tar -xzf /tmp/camera-bridge-config.tar.gz

# Run remaining setup
cd /opt/camera-bridge
sudo bash scripts/install-packages.sh

# Start services
sudo systemctl daemon-reload
sudo systemctl enable --now camera-bridge smbd nmbd nginx dnsmasq
```

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -v user@remote-host

# If password required, copy SSH key
ssh-copy-id user@remote-host

# If different SSH port
ssh -p 2222 user@remote-host
```

### Permission Denied on Remote

```bash
# Add user to sudo group on remote machine
ssh user@remote-host
sudo usermod -aG sudo $USER
# Log out and back in
```

### Service Won't Start

```bash
# Check service logs
sudo journalctl -u camera-bridge -n 50
sudo journalctl -u smbd -n 50
sudo journalctl -u dnsmasq -n 50

# Verify configuration
sudo systemctl status camera-bridge
```

### Network Interface Name Mismatch

```bash
# Find actual interface names
ip link show

# Update configurations
sudo nano /etc/dnsmasq.d/camera-bridge.conf
sudo nano /opt/camera-bridge/config/smb.conf
sudo systemctl restart dnsmasq smbd
```

### Dropbox Connection Fails

```bash
# Test connection
sudo -u camerabridge rclone lsd dropbox:

# Reconfigure if needed
sudo -u camerabridge rclone config

# Check token expiration
sudo -u camerabridge rclone about dropbox:
```

## Network Configuration Checklist

After deployment, verify/adjust these network settings:

- [ ] Ethernet interface name matches configuration
- [ ] WiFi interface name (if used) matches configuration
- [ ] Static IP configured correctly (192.168.10.1/24)
- [ ] DHCP range appropriate for network
- [ ] SMB listening on correct interfaces
- [ ] Firewall allows SMB (ports 445, 139)
- [ ] Internet connectivity for Dropbox sync

## Performance Considerations

### Minimal Deployment (Fastest)
- Copy repository + run install script
- Time: ~5-10 minutes
- Network transfer: ~3MB
- Requires: Internet connection on target

### Full Deployment (Most Complete)
- Clone repository + install packages + copy all configs
- Time: ~10-20 minutes
- Network transfer: ~50-100MB (package downloads)
- Requires: Internet connection on target

### Disk Clone (Slowest but Most Identical)
- Clone entire disk image
- Time: 30-60 minutes (depending on disk size)
- Network transfer: Entire disk (10GB-100GB+)
- Requires: Downtime on source machine

## Security Considerations

### Before Deployment

1. **SSH Keys**: Use key-based authentication, not passwords
2. **Sudo Access**: Verify sudo permissions on target
3. **Firewall**: Consider firewall rules on target machine
4. **Secrets**: Dropbox tokens are sensitive - secure transfer

### After Deployment

1. **Change Default Passwords**:
   ```bash
   # SMB camera user password
   sudo smbpasswd camera

   # System user password
   sudo passwd camerabridge
   ```

2. **Unique Hostname**:
   ```bash
   sudo hostnamectl set-hostname camera-bridge-2
   ```

3. **SSH Hardening**:
   ```bash
   # Disable password authentication
   sudo nano /etc/ssh/sshd_config
   # Set: PasswordAuthentication no
   sudo systemctl restart sshd
   ```

## Multi-Site Deployment

If deploying to multiple locations:

### Create Deployment Package

```bash
# On source machine
cd /opt/camera-bridge
sudo bash scripts/create-deployment-package.sh

# This creates: camera-bridge-deploy.tar.gz
```

### Use Ansible (Advanced)

Create an Ansible playbook for automated multi-machine deployment:

```yaml
# deploy-camera-bridge.yml
- hosts: camera_bridges
  become: yes
  tasks:
    - name: Clone repository
      git:
        repo: https://github.com/tomganleylee/Topcom.git
        dest: /opt/camera-bridge

    - name: Run installation
      shell: bash /opt/camera-bridge/scripts/install-packages.sh

    - name: Start services
      systemd:
        name: "{{ item }}"
        enabled: yes
        state: started
      loop:
        - camera-bridge
        - smbd
        - nmbd
        - nginx
        - dnsmasq
```

## Post-Deployment Checklist

- [ ] All services running (`systemctl status`)
- [ ] Dropbox connection working
- [ ] SMB share accessible from network
- [ ] DHCP server assigning addresses
- [ ] Web interface accessible
- [ ] Terminal UI working
- [ ] Log files being created
- [ ] Auto-start on boot configured
- [ ] WiFi (if used) configured
- [ ] Test file upload and sync to Dropbox

## Quick Reference

### One-Line Remote Deployment
```bash
sudo /opt/camera-bridge/scripts/deploy-remote.sh user@remote-host
```

### Manual Quick Deploy
```bash
ssh user@remote-host "cd /tmp && git clone https://github.com/tomganleylee/Topcom.git && sudo mv Topcom /opt/camera-bridge && cd /opt/camera-bridge && sudo bash scripts/install-packages.sh"
```

### Verify Remote Installation
```bash
ssh user@remote-host "sudo systemctl status camera-bridge smbd dnsmasq nginx"
```

### Copy Dropbox Credentials
```bash
scp /home/camerabridge/.config/rclone/rclone.conf user@remote-host:/tmp/ && ssh user@remote-host "sudo mkdir -p /home/camerabridge/.config/rclone && sudo mv /tmp/rclone.conf /home/camerabridge/.config/rclone/ && sudo chown -R camerabridge:camerabridge /home/camerabridge/.config && sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf"
```

---

**Recommended Method**: Use the automated deployment script (`deploy-remote.sh`) for fastest and most reliable results.
