# Changelog

All notable changes to the Camera Bridge project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-09-15

### Added
- Initial release of Camera Bridge automatic photo sync system
- Core photo synchronization service with inotify monitoring
- SMB/CIFS network sharing for camera connectivity
- Web-based setup wizard and status dashboard
- Comprehensive terminal UI for system management
- WiFi management with hotspot fallback mode
- Dropbox integration via rclone with OAuth2 tokens
- Raspberry Pi optimized installation and configuration
- USB installer creation for easy Pi deployment
- Multi-platform support (Ubuntu, Debian, Raspberry Pi OS)
- Complete documentation and deployment guides
- Service management via systemd
- Security hardening and user isolation
- Performance monitoring and health checks
- Log rotation and system maintenance tools

### Features
- **Automatic Photo Sync**: Real-time file monitoring and cloud upload
- **Network Sharing**: Professional SMB server configuration
- **Web Interface**: Modern, responsive setup and monitoring interface
- **Terminal Interface**: Full-featured ncurses management system
- **WiFi Management**: Complete network configuration tools
- **Multi-Platform**: Support for various Linux distributions
- **USB Deployment**: Bootable USB installer for Raspberry Pi
- **Security**: Secure token-based authentication and service isolation
- **Monitoring**: Comprehensive status monitoring and diagnostics
- **Documentation**: Complete installation, deployment, and troubleshooting guides

### Supported Platforms
- Ubuntu 20.04+
- Debian 11+
- Raspberry Pi OS (32-bit and 64-bit)
- Raspberry Pi 4/5 (primary target)
- Raspberry Pi 3B+ (may work with limitations)

### Dependencies
- rclone (Dropbox sync)
- Samba (SMB/CIFS sharing)
- nginx (Web interface)
- PHP 8.2+ (Web interface backend)
- inotify-tools (File monitoring)
- hostapd (WiFi hotspot)
- dnsmasq (DHCP server)
- dialog (Terminal interface)
- wireless-tools (WiFi management)

### Installation Methods
1. Package installer script
2. Raspberry Pi specific installer
3. USB bootable installer
4. Manual step-by-step installation

### Management Interfaces
1. Web interface (setup and monitoring)
2. Terminal UI (complete system management)
3. Command line tools (quick operations)
4. Service control (systemd integration)

## [Planned for 1.1.0]
- USB gadget mode support for Pi Zero 2 W
- Direct USB connection as mass storage device
- Enhanced mobile web interface
- Advanced sync filtering options
- Multiple cloud provider support
- Performance analytics and reporting

## [Future Enhancements]
- Docker containerization
- Multiple camera management
- Advanced networking options
- Integration APIs
- Mobile application
- Enterprise deployment tools