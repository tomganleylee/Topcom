# Camera Bridge - Automatic Photo Sync System

A complete solution for automatically syncing camera photos to cloud storage via SMB network sharing. Designed for professional photographers who need reliable, hands-off photo backup.

## 🎯 Features

- **Automatic Photo Sync**: Real-time sync of photos from cameras to Dropbox
- **QR Code Setup**: Mobile-friendly Dropbox token entry via QR code + web interface
- **SMB Network Share**: Professional-grade file sharing for camera connectivity
- **USB Gadget Mode**: Pi Zero 2 W acts as smart USB drive for direct camera connection
- **Smart Installation**: Auto-detecting installer that preserves configurations
- **Web Interface**: Easy setup and monitoring via web browser
- **Terminal Interface**: Advanced management and troubleshooting tools
- **WiFi Management**: Flexible network configuration with hotspot fallback
- **Dual Mode Operation**: Switch between network SMB and USB gadget modes
- **Raspberry Pi Optimized**: Special optimizations for Pi deployment
- **USB Installer**: Create bootable USB drives for easy deployment
- **Multi-Platform**: Works on Ubuntu/Debian systems and Raspberry Pi

## 🚀 Quick Start

> **📖 NEW: See [QUICK_START.md](../QUICK_START.md) for the simplest setup experience!**

### Recommended: One-Command Interactive Setup

```bash
# Clone and run interactive setup
git clone https://github.com/tomganleylee/Topcom.git /opt/camera-bridge
cd /opt/camera-bridge
sudo bash setup-new-machine.sh
```

The interactive script will:
- ✓ Install camera bridge base system
- Ask: Install WiFi hotspot? (optional)
- Ask: Install scanner support? (optional)
- Configure and enable all services

**Takes 5 minutes instead of 30!**

---

### Option 1: Standard Raspberry Pi Setup (MANUAL)
**Complete setup for Pi 4, Pi 3B+, or any Linux system:**

```bash
# 1. Clone repository
git clone https://github.com/tomganleylee/Topcon.git camera-bridge
cd camera-bridge

# 2. Install Camera Bridge
sudo ./scripts/install-packages.sh

# 3. Setup remote access (IMPORTANT for deployment)
setup-remote-access

# 4. Configure via terminal UI
sudo /opt/camera-bridge/scripts/terminal-ui.sh
# → WiFi Status & Management
# → Dropbox Configuration (use QR code option!)

# 5. Test web interface
# Open browser: http://[pi-ip-address]/
```

### Option 2: Pi Zero 2 W USB Gadget Mode (ADVANCED)
Transform your Pi Zero 2 W into a smart USB drive:
```bash
cd raspberry-pi/pi-zero-2w
sudo ./scripts/install-pi-zero-2w.sh
# Configure Dropbox, enable USB gadget mode
# Connect to camera via USB-C - photos auto-sync!
```
See [pi-zero-2w/QUICK-START.md](raspberry-pi/pi-zero-2w/QUICK-START.md)

### Option 3: Raspberry Pi USB Installer
1. Create USB installer: `sudo ./raspberry-pi/scripts/create-usb-installer.sh /dev/sdX`
2. Insert USB into Raspberry Pi
3. Run: `sudo ./quick-setup.sh`
4. System reboots automatically when complete

### Option 3: Manual Installation
```bash
# Clone and setup
git clone <repository-url> camera-bridge
cd camera-bridge

# For Ubuntu/Debian
sudo ./scripts/install-packages.sh

# For Raspberry Pi
sudo ./raspberry-pi/scripts/install-rpi.sh
sudo ./raspberry-pi/scripts/setup-rpi.sh
```

### Option 4: Step-by-Step
See [INSTALLATION.md](docs/INSTALLATION.md) for detailed instructions.

## 📋 Requirements

### Hardware
- **Standard PC**: Ubuntu/Debian system with WiFi and Ethernet
- **Raspberry Pi**: Pi 4 recommended (4GB+ RAM), Pi 3B+ may work
- **Pi Zero 2 W**: For USB gadget mode (direct camera connection)
- **Storage**: 8GB+ SD card/storage, 16GB+ recommended
- **Network**: Ethernet port + WiFi capability (network modes)
- **Camera**: Network-capable camera with SMB/CIFS support OR USB storage support

### Software
- Ubuntu 20.04+ or Debian 11+
- Raspberry Pi OS (32-bit or 64-bit)
- Internet connection for setup
- Dropbox account (free tier works)

## 🎛️ Management Interfaces

### Web Interface
- **URL**: `http://[device-ip]`
- **Features**: Initial setup, status monitoring, configuration
- **Mobile**: Responsive design works on phones/tablets

### Terminal Interface
- **Command**: `camera-bridge-ui` (or direct path)
- **Features**: Complete system management, diagnostics, troubleshooting
- **Access**: Local console or SSH

### Command Line Tools
```bash
# Quick status check
camera-bridge-status

# WiFi management
wifi-manager.sh status|scan|connect

# Service control
systemctl status camera-bridge
systemctl restart camera-bridge

# Logs
tail -f /var/log/camera-bridge/service.log
```

## 📁 Project Structure

```
camera-bridge/
├── scripts/                 # Core scripts
│   ├── install-packages.sh  # Package installation
│   ├── camera-bridge-service.sh  # Main sync service
│   ├── wifi-manager.sh      # WiFi management
│   └── terminal-ui.sh       # Terminal interface
├── web/                     # Web interface
│   ├── index.php           # Setup wizard
│   ├── status.php          # Status dashboard
│   └── token-entry.php     # QR code token entry
├── config/                  # Configuration files
│   ├── smb.conf            # Samba configuration
│   ├── camera-bridge.service  # Systemd service
│   ├── hostapd.conf        # Access point config
│   └── nginx-camera-bridge.conf  # Web server config
├── raspberry-pi/            # Raspberry Pi specific
│   ├── scripts/            # Pi installation scripts
│   ├── config/             # Pi configurations
│   └── boot-files/         # Boot-time setup files
└── docs/                   # Documentation
    ├── INSTALLATION.md     # Installation guide
    ├── TROUBLESHOOTING.md  # Problem solving
    └── API.md             # API documentation
```

## 🔧 Setup Process

### 1. System Installation
Choose your installation method:
- **USB Installer**: Plug and play for Raspberry Pi
- **Package Script**: `sudo ./scripts/install-packages.sh`
- **Manual Setup**: Follow step-by-step instructions

### 2. Network Configuration
Configure network connectivity:
- **Ethernet**: Usually automatic
- **WiFi**: Use web interface or terminal UI
- **Hotspot**: "CameraBridge-Setup" password "setup123"

### 3. Dropbox Setup
1. Visit [Dropbox Developers](https://dropbox.com/developers/apps)
2. Create new app → Scoped access → App folder
3. Enable permissions: `files.metadata.read`, `files.content.read`, `files.content.write`
4. Generate access token (1400+ characters, starts with 'sl.')

**Token Entry Options:**
- **QR Code + Web (Recommended)**: Terminal shows QR code → scan with phone → paste token on mobile browser
- **Manual Entry**: Paste token directly in terminal dialog
- **Web Interface**: Enter token via setup wizard at device IP

5. Photos sync to `/Apps/CameraBridge/` folder

### 4. Remote Access Setup (CRITICAL for deployment)
For international deployment, set up remote access:

```bash
setup-remote-access
# Choose your option:
# 1) Tailscale (Recommended) - Zero-config VPN
# 2) Cloudflare Tunnel - Secure tunneling
# 3) Both (Maximum redundancy)
```

**Tailscale Setup:**
```bash
# After choosing Tailscale:
sudo tailscale up
# Copy URL to browser, authenticate
# Install Tailscale on your devices
# SSH from anywhere: ssh tom@[tailscale-ip]
```

### 5. Camera Configuration
Configure your camera:
- **SMB Server**: Device IP address
- **Share Path**: `\\[device-ip]\photos`
- **Username**: `camera`
- **Password**: `camera123`
- **Protocol**: SMB/CIFS

## 🧪 Testing Your Setup

### Pre-Deployment Testing Checklist

**1. Basic System Test:**
```bash
# Check all services are running
sudo systemctl status nginx smbd camera-bridge

# Test terminal UI
sudo /opt/camera-bridge/scripts/terminal-ui.sh

# Check web interface
curl -I http://localhost/
```

**2. WiFi & Network Test:**
```bash
# Test WiFi management
sudo /opt/camera-bridge/scripts/terminal-ui.sh
# → WiFi Status & Management → Show WiFi Status
# Should show interface details and connection info

# Test network connectivity
ping -c 3 google.com
```

**3. Dropbox Integration Test:**
```bash
# Test Dropbox connection
sudo /opt/camera-bridge/scripts/terminal-ui.sh
# → Dropbox Configuration → Test Dropbox Connection
# Should show "✓ Dropbox Connection: SUCCESSFUL"

# Manual sync test
sudo -u camerabridge rclone lsd dropbox:
```

**4. SMB Share Test:**
```bash
# Test SMB locally
smbclient -L localhost -U camera%camera123

# Create test file
echo "Test photo" > /srv/samba/camera-share/test.jpg

# Verify sync (check Dropbox after ~30 seconds)
tail -f /var/log/camera-bridge/service.log
```

**5. Remote Access Test:**
```bash
# Test Tailscale connection
tailscale status
tailscale ip -4

# Test SSH from another device
ssh tom@[tailscale-ip]
```

**6. Camera Test:**
From a computer on same network:
- Connect to `\\[pi-ip]\photos` (Windows) or `smb://[pi-ip]/photos` (Mac/Linux)
- Username: `camera`, Password: `camera123`
- Copy a test image file
- Verify it appears in Dropbox within 1 minute

**7. Emergency Fallback Test:**
```bash
# Disconnect WiFi to test hotspot fallback
sudo /opt/camera-bridge/scripts/wifi-manager.sh disconnect

# Should automatically create "CameraBridge-Setup" hotspot
# Connect to it and SSH to 192.168.4.1
```

### 🚨 **CRITICAL: Test Everything Before International Deployment!**

## 📊 Monitoring & Status

### Web Dashboard
- Real-time system status
- Service health monitoring
- Network connectivity status
- Recent file activity
- Resource utilization
- Auto-refresh every 30 seconds

### Terminal Interface
- Complete system diagnostics
- WiFi network scanner and manager
- Dropbox connection testing
- Log file viewing
- Service management
- System maintenance tools

### Logging
- **Service Log**: `/var/log/camera-bridge/service.log`
- **WiFi Log**: `/var/log/camera-bridge/wifi.log`
- **System Logs**: `journalctl -u camera-bridge`

## 🔒 Security Features

### Network Security
- WPA2 WiFi encryption
- SMB authentication required
- Web interface on private networks only
- Optional HTTPS support

### Data Security
- Local storage until cloud sync
- Dropbox app-folder access (limited scope)
- No plain-text password storage
- Secure token-based authentication

### System Security
- Minimal privilege services
- Regular security updates
- Optional firewall configuration
- SSH key authentication support

## 📈 Performance

### Optimization Features
- Real-time file monitoring with inotify
- Efficient incremental sync
- Network bandwidth management
- SD card longevity optimizations (Pi)
- Resource usage monitoring

### Supported File Formats
- **Images**: JPG, JPEG, PNG, TIFF, RAW
- **RAW Formats**: DNG, CR2, NEF, ORF, ARW
- **Videos**: MP4, MOV, AVI (if enabled)

### Capacity Guidelines
- **Raspberry Pi**: 100-1000 photos/day typical
- **Standard PC**: 1000+ photos/day capable
- **Storage**: Plan for 2-3 days local storage
- **Network**: 100Mbps+ recommended for high volume

## 🛠️ Troubleshooting

### Common Issues
1. **WiFi Connection Problems**
   - Use WiFi scanner in terminal UI
   - Check signal strength and password
   - Try manual connection with SSID input

2. **Dropbox Sync Failures**
   - Verify token hasn't expired
   - Test connection manually
   - Check internet connectivity

3. **Camera Connection Issues**
   - Verify SMB credentials
   - Check network connectivity
   - Test from another computer first

4. **Performance Problems**
   - Monitor system temperature
   - Check SD card health (Pi)
   - Review resource usage

### Diagnostic Tools
```bash
# System health
camera-bridge-ui → System Status

# Network diagnostics
wifi-manager.sh status
wifi-manager.sh scan

# Service diagnostics
systemctl status camera-bridge
journalctl -u camera-bridge -f

# Manual testing
sudo -u camerabridge rclone ls dropbox:
```

## 📚 Documentation

- **[Installation Guide](docs/INSTALLATION.md)**: Detailed setup instructions
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Problem solving guide
- **[API Documentation](docs/API.md)**: Integration and automation
- **[Raspberry Pi Guide](raspberry-pi/README.md)**: Pi-specific information

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Make changes and test thoroughly
4. Submit pull request with detailed description

### Testing
- Test on multiple platforms (Ubuntu, Debian, Raspberry Pi OS)
- Verify all installation methods work
- Test network configurations
- Validate Dropbox sync functionality

### Documentation
- Update README for new features
- Add troubleshooting entries for new issues
- Keep API documentation current
- Include examples for common use cases

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the photography community
- Utilizes open-source technologies: Linux, Samba, nginx, PHP, rclone
- Optimized for Raspberry Pi Foundation hardware
- Tested by professional photographers worldwide

## 📞 Support

### Community Support
- Check the troubleshooting guide first
- Use terminal interface diagnostics
- Review log files for error messages
- Search existing GitHub issues

### Professional Support
- Custom deployment assistance available
- Enterprise integration consulting
- Performance optimization services
- Training and documentation services

---

**Camera Bridge** - Making photo workflow automation simple and reliable.

*For professional photographers who demand reliability in their backup workflow.*