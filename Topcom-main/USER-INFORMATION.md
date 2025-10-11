# Camera Bridge - User Information Display

## What Users See on Terminal UI

When users access the terminal UI (via `sudo /opt/camera-bridge/scripts/terminal-ui.sh`), they see:

### Main Screen Display

```
📷 Camera Bridge Manager

📶 Network: Bridge Mode (WiFi + Ethernet)
   IP: 192.168.10.1
   WiFi AP: ✓ Active
   SSID: Camera-Bridge
   Password: camera123

📁 SMB Shares:
   Photos: \\192.168.10.1\photos
   Scanner: \\192.168.10.1\scanner
   Username: camera
   Password: camera123

👥 Connected: 2 client(s)

Choose an option:
1. WiFi Status & Management
2. Dropbox Configuration
3. System Status
4. View Logs
5. Network Settings
6. Service Management
7. File Management
8. System Information
9. Maintenance Tools
```

### Information Shown

| Category | Information Displayed | Example Value |
|----------|----------------------|---------------|
| **Network Mode** | Bridge or Ethernet Only | `Bridge Mode (WiFi + Ethernet)` |
| **IP Address** | System IP | `192.168.10.1` |
| **WiFi Hotspot** | Status, SSID, Password | `✓ Active` / `Camera-Bridge` / `camera123` |
| **SMB Photo Share** | Network path | `\\192.168.10.1\photos` |
| **SMB Scanner Share** | Network path (if scanner installed) | `\\192.168.10.1\scanner` |
| **SMB Credentials** | Username and password | `camera` / `camera123` |
| **Connected Clients** | Number of DHCP leases | `2 client(s)` |

---

## What Users See on Web Interface

When users visit `http://192.168.10.1` in a web browser:

### Landing Page

Shows:
- Camera Bridge logo/title
- Setup wizard or status page
- Dropbox configuration interface
- QR code for easy mobile access

### Status Page (`status.php`)

Shows:
- System status (running/stopped)
- Network information
- Dropbox connection status
- Recent sync activity
- SMB share information

---

## Critical Information Summary

### For Cameras Connecting via WiFi

**Network to Join:**
- SSID: `Camera-Bridge`
- Password: `camera123`
- Security: WPA2

**After Connection:**
- Camera gets IP via DHCP: `192.168.10.10` - `192.168.10.50`
- SMB share available at: `\\192.168.10.1\photos`
- Scanner share available at: `\\192.168.10.1\scanner` (if installed)

### For Cameras Connecting via Ethernet

**Network Configuration:**
- Camera gets IP via DHCP: `192.168.10.10` - `192.168.10.50`
- Gateway: `192.168.10.1`
- DNS: `8.8.8.8`, `8.8.4.4`

**SMB Shares:**
- Photos: `\\192.168.10.1\photos`
- Scanner: `\\192.168.10.1\scanner` (if installed)

### SMB Access Credentials

**For all devices (cameras, phones, computers):**
- Username: `camera`
- Password: `camera123`

---

## Network Diagram (Displayed Conceptually)

```
                    Internet
                       ↓
           [Internal WiFi - wlp1s0]
                       ↓
                  [Router/NAT]
                       ↓
        [Bridge: br0 - 192.168.10.1/24]
         ├─ Ethernet (eno1)
         │   └─ Wired Cameras
         │
         └─ WiFi AP (wlx* - USB AC600)
             └─ SSID: Camera-Bridge
                 └─ Wireless Cameras
                       ↓
              [All devices on 192.168.10.0/24]
                       ↓
                 SMB Shares + Dropbox Sync
```

---

## User-Facing Documentation Locations

### Terminal UI (Main Menu)

Located at: `/opt/camera-bridge/scripts/terminal-ui.sh`

**Information displayed:**
- ✅ Real-time network status
- ✅ WiFi hotspot SSID and password (read from `/etc/hostapd/hostapd.conf`)
- ✅ SMB share paths and credentials
- ✅ Scanner share (if `/srv/scanner/scans` exists)
- ✅ Connected device count
- ✅ IP address information

### Web Interface

Located at: `/opt/camera-bridge/web/index.php`

**Information displayed:**
- Dropbox setup interface
- System status
- Quick reference card (planned)

---

## Scanner Information (If Installed)

### When Brother DS-640 is installed:

**Terminal UI Shows:**
```
📁 SMB Shares:
   Photos: \\192.168.10.1\photos
   Scanner: \\192.168.10.1\scanner
   Username: camera
   Password: camera123
```

**Dropbox Folders:**
- Camera photos → `Dropbox:/Camera-Photos/`
- Scanned documents → `Dropbox:/Scanned-Documents/`

---

## Quick Reference Card for Users

### Connecting Your Camera

**Option 1: WiFi**
1. On camera, go to WiFi settings
2. Connect to: `Camera-Bridge`
3. Enter password: `camera123`
4. In camera's network settings, add SMB share:
   - Path: `\\192.168.10.1\photos`
   - Username: `camera`
   - Password: `camera123`

**Option 2: Ethernet**
1. Plug ethernet cable from camera to Camera Bridge
2. Camera gets IP automatically
3. In camera's network settings, add SMB share:
   - Path: `\\192.168.10.1\photos`
   - Username: `camera`
   - Password: `camera123`

### Using the Scanner (If Installed)

1. Connect Brother DS-640 to USB port
2. Place document in scanner
3. Press scan button on scanner
4. Document automatically saves to:
   - Local: `/srv/scanner/scans/`
   - SMB: `\\192.168.10.1\scanner`
   - Dropbox: `Scanned-Documents/`

### Accessing Files

**From Windows:**
1. Open File Explorer
2. Type in address bar: `\\192.168.10.1\photos`
3. Login with: `camera` / `camera123`

**From Mac:**
1. Finder → Go → Connect to Server
2. Enter: `smb://192.168.10.1/photos`
3. Login with: `camera` / `camera123`

**From Phone:**
- iOS: Use Files app → Connect to Server → `smb://192.168.10.1/photos`
- Android: Use file manager with SMB support

---

## Updating User-Facing Information

### To Change WiFi Hotspot Name/Password

Edit: `/etc/hostapd/hostapd.conf`

```ini
ssid=Your-New-SSID
wpa_passphrase=YourNewPassword
```

Then restart:
```bash
sudo systemctl restart hostapd
```

**Note:** Terminal UI automatically reads these values and displays them!

### To Change SMB Password

```bash
sudo smbpasswd camera
```

Enter new password when prompted.

**Note:** You'll need to update the Terminal UI display manually if you change this.

### To Add Scanner Information

Scanner info automatically appears when `/srv/scanner/scans` directory exists.

No manual configuration needed - the terminal UI detects it automatically!

---

## Summary

**Everything a user needs is displayed on the Terminal UI main screen:**

✅ WiFi hotspot name and password
✅ SMB share paths (photos and scanner)
✅ SMB username and password
✅ IP address
✅ Connection status
✅ Number of connected devices

**No need to remember or look up configuration files - it's all right there!**

---

**Version:** 2.1
**Last Updated:** October 2025
**Maintained in:** `/opt/camera-bridge/Topcom-main/scripts/terminal-ui.sh`
