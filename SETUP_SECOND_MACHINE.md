# Setup Guide - Second Machine with WiFi Hotspot & Scanner

## Overview
This guide will help you set up the second machine with:
- ✅ WiFi Hotspot (hostapd + dnsmasq)
- ✅ Brother Scanner drivers
- ✅ Camera Bridge system (already working)

---

## Prerequisites

- Second machine with Ubuntu/Debian Linux
- WiFi adapter that supports AP mode (check with `iw list | grep "Supported interface modes" -A 8`)
- Brother scanner (USB or network connected)
- Internet connection for initial setup
- Sudo/root access

---

## Step-by-Step Setup

### Step 1: Clone the Repository

```bash
# Clone repository to /opt/camera-bridge
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/tomganleylee/Topcom.git camera-bridge
sudo chown -R $USER:$USER /opt/camera-bridge
cd /opt/camera-bridge
```

**If you need authentication:**
```bash
git clone https://tomganleylee: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@github.com/tomganleylee/Topcom.git camera-bridge
```

---

### Step 2: Install WiFi Hotspot

```bash
cd /opt/camera-bridge
sudo bash Topcom-main/scripts/setup-wifi-hotspot.sh
```

**What this script does:**
- Installs `hostapd` (WiFi access point daemon)
- Installs `dnsmasq` (DHCP + DNS server)
- Configures WiFi AP on wlan0
- Sets up DHCP server (192.168.4.1/24)
- Creates systemd services for auto-start
- Configures network interfaces

**Default WiFi Settings:**
- SSID: `CameraBridge`
- Password: `camera2024` (or check [config/hostapd.conf](config/hostapd.conf))
- IP Address: `192.168.4.1`
- DHCP Range: `192.168.4.2 - 192.168.4.20`

**To customize WiFi settings:**
```bash
# Edit before running setup script
nano /opt/camera-bridge/config/hostapd.conf

# Change these lines:
ssid=YourNetworkName          # Change WiFi name
wpa_passphrase=YourPassword   # Change password (min 8 chars)
channel=6                      # Change WiFi channel if needed

# Then run the setup script
sudo bash Topcom-main/scripts/setup-wifi-hotspot.sh
```

**Verify WiFi Hotspot:**
```bash
# Check if services are running
sudo systemctl status hostapd
sudo systemctl status dnsmasq

# Check WiFi interface
ip addr show wlan0

# Try connecting with another device
# Look for "CameraBridge" WiFi network
```

---

### Step 3: Install Brother Scanner Drivers

```bash
cd /opt/camera-bridge
sudo bash Topcom-main/scripts/setup-brother-scanner.sh
```

**What this script does:**
- Installs SANE (Scanner Access Now Easy)
- Downloads Brother brscan4 drivers
- Configures scanner permissions
- Adds user to scanner group
- Tests scanner connectivity

**For different Brother scanner models:**

The script works for most Brother scanners, but if you have a specific model, you may need to download the correct driver:

1. **Find your scanner model** (look on the scanner)
   - Examples: DCP-L2530DW, MFC-L2710DW, DCP-L2550DW

2. **Visit Brother support:**
   ```
   https://support.brother.com/
   ```

3. **Download the correct driver:**
   - Search for your model
   - Select "Downloads" → "Linux" → "Driver"
   - Download the `brscan4` or `brscan-skey` .deb file

4. **Manual installation if needed:**
   ```bash
   # Example for DCP-L2530DW
   cd /tmp
   wget https://download.brother.com/welcome/dlf105200/brscan4-0.4.11-1.amd64.deb
   sudo dpkg -i brscan4-0.4.11-1.amd64.deb

   # Configure scanner (USB scanner)
   sudo brsaneconfig4 -a name=Brother model=DCP-L2530DW

   # Or for network scanner
   sudo brsaneconfig4 -a name=Brother model=DCP-L2530DW ip=192.168.1.100
   ```

**Test Scanner:**
```bash
# List detected scanners
scanimage -L

# Expected output:
# device `brother4:net1;dev0' is a Brother DCP-L2530DW

# Test scan (creates test.pnm file)
scanimage --test

# Do actual scan
scanimage --format=png --output-file=test.png
```

**Troubleshooting Scanner:**

If scanner is not detected:

```bash
# Check USB connection
lsusb | grep -i brother

# Check SANE backends
cat /etc/sane.d/dll.conf | grep brother

# Add user to scanner group
sudo usermod -a -G scanner $USER
sudo usermod -a -G lp $USER

# Reboot (sometimes required)
sudo reboot

# After reboot, test again
scanimage -L
```

---

### Step 4: Update Camera Bridge Service (If Needed)

If your camera bridge needs the latest scripts:

```bash
cd /opt/camera-bridge

# Copy updated service file
sudo cp config/camera-bridge.service /etc/systemd/system/

# Copy updated scripts
sudo cp scripts/camera-bridge-service.sh /usr/local/bin/ 2>/dev/null || true

# Reload systemd
sudo systemctl daemon-reload

# Restart service
sudo systemctl restart camera-bridge

# Check status
sudo systemctl status camera-bridge
```

---

### Step 5: Enable Services on Boot

```bash
# Enable all services to start automatically
sudo systemctl enable camera-bridge
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable nginx

# Verify enabled
systemctl is-enabled camera-bridge
systemctl is-enabled hostapd
systemctl is-enabled dnsmasq
```

---

### Step 6: Verify Everything Works

```bash
# Check all services
sudo systemctl status camera-bridge
sudo systemctl status hostapd
sudo systemctl status dnsmasq
sudo systemctl status nginx

# Check WiFi hotspot
ip addr show wlan0
# Should show: 192.168.4.1

# Check scanner
scanimage -L

# Check web interface
curl http://192.168.4.1/
```

**Connect to the WiFi hotspot:**
1. On your phone/laptop, look for WiFi network: `CameraBridge`
2. Password: `camera2024` (or what you set)
3. Once connected, open browser: `http://192.168.4.1/`

---

## Configuration Files Reference

### WiFi Hotspot Configuration

**[config/hostapd.conf](config/hostapd.conf)** - WiFi Access Point settings
```bash
# Key settings:
interface=wlan0               # WiFi interface
ssid=CameraBridge            # Network name
wpa_passphrase=camera2024    # Password
channel=6                     # WiFi channel
```

**[config/dnsmasq-ap.conf](config/dnsmasq-ap.conf)** - DHCP Server settings
```bash
# Key settings:
interface=wlan0              # WiFi interface
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
address=/camera.local/192.168.4.1
```

### Scanner Configuration

After installation, scanner config is in:
- `/etc/sane.d/` - SANE configuration
- `/opt/brother/scanner/` - Brother scanner software
- `/etc/opt/brother/scanner/` - Brother config files

### Camera Bridge Configuration

**[config/camera-bridge.service](config/camera-bridge.service)** - Systemd service
**[scripts/camera-bridge-service.sh](scripts/camera-bridge-service.sh)** - Main service script

---

## Post-Installation Tasks

### 1. Configure Dropbox Token

```bash
# Using web interface (easiest)
# Connect to: http://192.168.4.1/
# Follow the setup wizard

# OR using terminal
sudo bash /opt/camera-bridge/scripts/terminal-ui.sh
```

### 2. Customize WiFi Settings

```bash
# Edit hostapd config
sudo nano /etc/hostapd/hostapd.conf

# Change SSID/password:
ssid=MyCamera2
wpa_passphrase=MySecurePass123

# Restart
sudo systemctl restart hostapd
```

### 3. Add WiFi Networks (for client mode)

```bash
# Run terminal UI
sudo bash /opt/camera-bridge/scripts/terminal-ui.sh

# Select: WiFi Management → Add Network
```

---

## Network Modes

Your machine can operate in two modes:

### Mode 1: Access Point (Hotspot) Mode
- Machine creates its own WiFi network
- SSID: `CameraBridge`
- IP: `192.168.4.1`
- Other devices connect to it
- **Use case:** Standalone operation, no existing WiFi

### Mode 2: Client Mode (Connected to WiFi)
- Machine connects to existing WiFi
- Gets IP via DHCP
- Can still run camera bridge service
- **Use case:** When you have existing WiFi network

**To switch between modes:**
```bash
# Switch to Client mode (connect to existing WiFi)
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo bash /opt/camera-bridge/scripts/wifi-manager.sh

# Switch back to AP mode (hotspot)
sudo systemctl start hostapd
sudo systemctl start dnsmasq
```

---

## Troubleshooting

### WiFi Hotspot Not Working

**Check WiFi adapter supports AP mode:**
```bash
iw list | grep "Supported interface modes" -A 8
# Should show "AP" in the list
```

**Check for NetworkManager conflicts:**
```bash
# Stop NetworkManager (it conflicts with hostapd)
sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager

# Restart services
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq
```

**Check interface is up:**
```bash
ip link set wlan0 up
ip addr show wlan0
```

**View logs:**
```bash
sudo journalctl -u hostapd -f
sudo journalctl -u dnsmasq -f
```

### Scanner Not Detected

**USB Scanner:**
```bash
# Check USB connection
lsusb | grep -i brother

# Check permissions
ls -la /dev/bus/usb/

# Add to scanner group
sudo usermod -a -G scanner $USER
sudo usermod -a -G lp $USER

# Logout and login (or reboot)
```

**Network Scanner:**
```bash
# Check network connectivity
ping <scanner-ip>

# Reconfigure scanner
sudo brsaneconfig4 -a name=Brother model=YOUR-MODEL ip=<scanner-ip>

# Test
scanimage -L
```

**Check SANE configuration:**
```bash
# Check if brother4 backend is enabled
cat /etc/sane.d/dll.conf | grep brother

# If not, add it:
echo "brother4" | sudo tee -a /etc/sane.d/dll.conf
```

### Services Not Starting

```bash
# Check service status
sudo systemctl status camera-bridge
sudo systemctl status hostapd
sudo systemctl status dnsmasq

# Check logs
sudo journalctl -u camera-bridge -n 50
sudo journalctl -u hostapd -n 50

# Check permissions
ls -la /opt/camera-bridge/scripts/
sudo chmod +x /opt/camera-bridge/scripts/*.sh

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart camera-bridge
```

### Can't Access Web Interface

```bash
# Check nginx is running
sudo systemctl status nginx

# Check nginx config
sudo nginx -t

# Check if listening on correct port
sudo netstat -tlnp | grep nginx

# Restart nginx
sudo systemctl restart nginx

# Try accessing
curl http://192.168.4.1/
```

---

## Quick Reference Commands

```bash
# View all service status
sudo systemctl status camera-bridge hostapd dnsmasq nginx

# Restart all services
sudo systemctl restart camera-bridge hostapd dnsmasq nginx

# View logs
sudo journalctl -u camera-bridge -f
sudo journalctl -u hostapd -f

# Check WiFi status
ip addr show wlan0
iw wlan0 info

# List connected WiFi clients
iw dev wlan0 station dump

# Test scanner
scanimage -L
scanimage --test

# Access terminal UI
sudo bash /opt/camera-bridge/scripts/terminal-ui.sh

# Pull latest updates
cd /opt/camera-bridge
git pull origin main
sudo systemctl restart camera-bridge
```

---

## Summary Checklist

- [ ] Repository cloned to /opt/camera-bridge
- [ ] WiFi hotspot installed and running (hostapd + dnsmasq)
- [ ] Can connect to "CameraBridge" WiFi network
- [ ] Brother scanner drivers installed
- [ ] Scanner detected with `scanimage -L`
- [ ] Camera bridge service running
- [ ] Web interface accessible at http://192.168.4.1/
- [ ] All services enabled on boot
- [ ] Dropbox token configured

---

## Next Steps

1. **Configure Dropbox:** Access http://192.168.4.1/ and set up Dropbox token
2. **Test scanning:** Try scanning a document
3. **Test file sync:** Place files in camera folder and verify upload
4. **Customize settings:** Adjust WiFi name, scanner settings as needed

---

## Getting Help

- Check logs: `sudo journalctl -u <service-name> -f`
- View documentation:
  - [BOOT_FIXES_APPLIED.md](BOOT_FIXES_APPLIED.md) - Boot issues
  - [SUDOERS_FIX.md](SUDOERS_FIX.md) - Permission issues
  - [Topcom-main/SCANNER-SETUP.md](Topcom-main/SCANNER-SETUP.md) - Scanner details
  - [Topcom-main/docs/WIFI-AP-SETUP-GUIDE.md](Topcom-main/docs/WIFI-AP-SETUP-GUIDE.md) - WiFi AP guide

---

Last Updated: 2025-10-11
