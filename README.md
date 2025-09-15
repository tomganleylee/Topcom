# Camera Bridge - Automatic Photo Sync System

A complete solution for automatically syncing camera photos to cloud storage via SMB network sharing. Designed for professional photographers who need reliable, hands-off photo backup.

## 🎯 Features

- **Automatic Photo Sync**: Real-time sync of photos from cameras to Dropbox
- **SMB Network Share**: Professional-grade file sharing for camera connectivity
- **Web Interface**: Easy setup and monitoring via web browser
- **Terminal Interface**: Advanced management and troubleshooting tools
- **WiFi Management**: Flexible network configuration with hotspot fallback
- **Raspberry Pi Optimized**: Special optimizations for Pi deployment
- **USB Installer**: Create bootable USB drives for easy deployment
- **Multi-Platform**: Works on Ubuntu/Debian systems and Raspberry Pi

## 🚀 Quick Start

### Option 1: Raspberry Pi USB Installer (Recommended)
1. Create USB installer: `sudo ./raspberry-pi/scripts/create-usb-installer.sh /dev/sdX`
2. Insert USB into Raspberry Pi
3. Run: `sudo ./quick-setup.sh`
4. System reboots automatically when complete

### Option 2: Manual Installation
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

### Option 3: Step-by-Step
See [INSTALLATION.md](docs/INSTALLATION.md) for detailed instructions.

## 📋 Requirements

### Hardware
- **Standard PC**: Ubuntu/Debian system with WiFi and Ethernet
- **Raspberry Pi**: Pi 4 recommended (4GB+ RAM), Pi 3B+ may work
- **Storage**: 8GB+ SD card/storage, 16GB+ recommended
- **Network**: Ethernet port + WiFi capability
- **Camera**: Network-capable camera with SMB/CIFS support

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
│   └── status.php          # Status dashboard
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
3. Generate access token
4. Enter token via web interface
5. Photos sync to `/Apps/CameraBridge/` folder

### 4. Camera Configuration
Configure your camera:
- **SMB Server**: Device IP address
- **Share Path**: `\\[device-ip]\photos`
- **Username**: `camera`
- **Password**: `camera123`
- **Protocol**: SMB/CIFS

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