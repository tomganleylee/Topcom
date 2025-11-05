# Camera Bridge - Changelog

## [Unreleased] - 2025-11-05

### Added - WiFi Access Point Feature
- **WiFi Hotspot Configuration**: USB WiFi dongle (wlx24ec99bfe35b) configured as access point
  - SSID: `CameraBridge-Setup`
  - Password: `camera123`
  - Network: 192.168.50.0/24 (separate from Ethernet bridge)
  - Automatic DHCP server for WiFi clients
  - Configuration files:
    - `/etc/hostapd/hostapd-camera-bridge.conf`
    - `/etc/dnsmasq.d/camera-bridge-wifi.conf`
    - `/etc/systemd/network/10-camera-bridge-usb-wifi.network`
    - `/etc/systemd/system/hostapd.service.d/override.conf`

### Added - PDF Sync Support
- Camera bridge service now syncs PDF files in addition to images
- Updated file filter in `/opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh`
- Supports: JPG, JPEG, PNG, TIFF, RAW, DNG, CR2, NEF, ORF, ARW, and **PDF**

### Enhanced - Samba Configuration
- **Windows XP Compatibility**: Enabled SMB1/NT1 protocol support
  - `server min protocol = NT1`
  - `ntlm auth = yes`
  - `lanman auth = yes`
- **Multi-Domain Support**: Accept connections from any workgroup/domain
  - Primary workgroup: `ANGIOPLEX`
  - Also accepts: `WORKGROUP` and others
  - Username mapping file: `/etc/samba/smbusers`
- **WiFi AP Network Support**: Added wlx24ec99bfe35b interface to Samba bindings
  - Share accessible via both Ethernet (192.168.10.1) and WiFi (192.168.50.1)

### Enhanced - Terminal UI
- **Startup Network Information Screen**:
  - Shows Ethernet bridge IP and network
  - Shows WiFi AP status, SSID, password, and IP
  - Shows client WiFi connection status
  - Added to both `/usr/local/bin/camera-bridge-ui` and `/opt/camera-bridge/scripts/terminal-ui-enhanced.sh`
- **System Information Menu**: Enhanced with network details
  - WiFi Access Point configuration
  - Ethernet Bridge configuration
  - Real-time service status

### Fixed
- Samba now listens on all configured interfaces (Ethernet + WiFi AP)
- hostapd service configured correctly with Type=simple for reliable startup
- PDF files now properly detected and synced to Dropbox

### Configuration Files Modified
1. `/etc/samba/smb.conf` - Multi-domain, Windows XP, WiFi interface support
2. `/etc/hostapd/hostapd-camera-bridge.conf` - WiFi AP configuration
3. `/etc/dnsmasq.d/camera-bridge-wifi.conf` - WiFi DHCP server
4. `/etc/systemd/system/hostapd.service.d/override.conf` - Service reliability fix
5. `/opt/camera-bridge/scripts/camera-bridge-service-with-refresh.sh` - PDF support
6. `/opt/camera-bridge/scripts/terminal-ui-enhanced.sh` - Network info display
7. `/usr/local/bin/camera-bridge-ui` - Network info display
8. `/etc/netplan/50-cloud-init.yaml` - USB WiFi interface configuration
9. `/etc/samba/smbusers` - Username mapping for cross-domain access

### Network Architecture
```
Internet (via wlp1s0) → Camera Bridge Server → Two Networks:

  1. Ethernet Bridge (eno1)
     - Network: 192.168.10.0/24
     - Gateway: 192.168.10.1
     - DHCP: 192.168.10.10-100
     - Purpose: Cameras via Ethernet

  2. WiFi Access Point (wlx24ec99bfe35b)
     - Network: 192.168.50.0/24
     - Gateway: 192.168.50.1
     - DHCP: 192.168.50.10-100
     - Purpose: Wireless device access
     - SSID: CameraBridge-Setup
     - Password: camera123

  Both networks have access to Samba share at \\<respective-gateway-ip>\photos
```

### Credentials
- **Samba Share**:
  - Username: `camera`
  - Password: `camera`
  - Domain: `ANGIOPLEX` (or leave blank)
  - Share name: `photos`
  - Path: `/srv/samba/camera-share`

- **WiFi Hotspot**:
  - SSID: `CameraBridge-Setup`
  - Password: `camera123`

### Testing Notes
- Tested with Windows XP clients on both networks
- Verified PDF sync to Dropbox
- Confirmed multi-domain authentication works
- WiFi AP stable and accessible
- Ethernet bridge unaffected by WiFi dongle removal (isolated networks)

---

## Previous Versions
See git history for earlier changes.
