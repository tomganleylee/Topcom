# WiFi Extension Plan for Camera Bridge DHCP Network

## Overview

Plan to extend the camera DHCP network (currently on `eno1` at 192.168.10.0/24) to WiFi using the new TP-Link USB adapter. This is an **addition** to the existing ethernet setup - the ethernet port will continue to work alongside the new WiFi capability.

## Current Setup Analysis

- **Ethernet (eno1)**: 192.168.10.1/24 - Running DHCP server (192.168.10.10-50)
- **Built-in WiFi (wlp1s0)**: 192.168.0.60/24 - Connected to home network for internet
- **New USB WiFi**: TP-Link 802.11ac adapter (Bus 001 Device 002: ID 2357:011f)
- **DHCP/DNS**: dnsmasq serving 192.168.10.0/24 network on eno1
- **SMB Share**: Cameras connect to `/srv/samba/camera-share`

## Proposed Architecture

### Option 1: Bridged Network (Recommended)

```
                    ┌─────────────────────────┐
                    │  Bridge (br0)           │
                    │  192.168.10.1/24        │
                    │  DHCP: .10-.50          │
                    └────────┬────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
         ┌──────▼──────┐          ┌──────▼──────┐
         │ Ethernet    │          │ USB WiFi AP │
         │ eno1        │          │ (wlan1)     │
         │ (no IP)     │          │ (no IP)     │
         └──────┬──────┘          └──────┬──────┘
                │                        │
         ┌──────▼──────┐          ┌──────▼──────────┐
         │ Camera A    │          │ Camera B        │
         │ (Ethernet)  │          │ (WiFi)          │
         │ 192.168.10. │          │ 192.168.10.     │
         │ 15          │          │ 22              │
         └─────────────┘          └─────────────────┘
```

**Network Flow:**
```
Cameras (WiFi) → USB WiFi AP (192.168.10.x) → Bridge to eno1 → Camera Bridge → Dropbox
Cameras (Ethernet) → eno1 (192.168.10.1) → Camera Bridge → Dropbox
```

**Benefits:**
- Single unified 192.168.10.0/24 network for all cameras
- Both WiFi and Ethernet cameras see the same SMB share
- Seamless failover between WiFi and Ethernet
- No routing complexity
- Ethernet port continues to work exactly as before
- Can mix ethernet and WiFi cameras simultaneously

## How Cameras Will Connect

### Ethernet Cameras (Current Setup - Continues Working)
1. Plug ethernet cable into `eno1`
2. Get DHCP lease (192.168.10.x)
3. Connect to SMB share `\\192.168.10.1\photos`
4. Files sync to Dropbox ✓

### WiFi Cameras (New Capability)
1. Connect to WiFi AP "CameraBridge-Photos"
2. Get DHCP lease (192.168.10.x) - **same pool**
3. Connect to SMB share `\\192.168.10.1\photos` - **same share**
4. Files sync to Dropbox ✓

## Interface Configuration Summary

| Interface | Purpose | Network | Status |
|-----------|---------|---------|--------|
| `eno1` | Camera ethernet | 192.168.10.0/24 | ✓ Still works (bridged) |
| USB WiFi | Camera WiFi AP | 192.168.10.0/24 | ✓ New addition (bridged) |
| `wlp1s0` | Internet uplink | 192.168.0.0/24 | ✓ Unchanged |
| `br0` | Virtual bridge | 192.168.10.1/24 | ✓ New (combines eno1+WiFi) |

## Implementation Plan

### Phase 1: Identify and Configure USB WiFi Interface

1. Install wireless tools if needed:
   ```bash
   sudo apt-get install wireless-tools hostapd bridge-utils
   ```

2. Identify the USB WiFi adapter's interface name:
   ```bash
   ip link show
   iw dev
   lsusb | grep -i wireless
   ```

3. Verify driver support for AP mode:
   ```bash
   iw list | grep -A 10 "Supported interface modes"
   ```
   - Must show "AP" in supported modes

4. Disable any conflicting network management on USB adapter:
   ```bash
   # Add to /etc/NetworkManager/NetworkManager.conf if using NetworkManager
   [keyfile]
   unmanaged-devices=interface-name:wlan1
   ```

### Phase 2: Network Bridge Setup

1. Create network bridge configuration:
   ```bash
   # For systems using netplan (/etc/netplan/01-camera-bridge.yaml)
   network:
     version: 2
     renderer: networkd
     ethernets:
       eno1:
         dhcp4: no
       wlan1:
         dhcp4: no
     bridges:
       br0:
         interfaces:
           - eno1
           - wlan1
         addresses:
           - 192.168.10.1/24
         parameters:
           stp: false
           forward-delay: 0
   ```

   ```bash
   # OR for /etc/network/interfaces
   auto br0
   iface br0 inet static
       address 192.168.10.1
       netmask 255.255.255.0
       bridge_ports eno1 wlan1
       bridge_stp off
       bridge_fd 0
   ```

2. Install bridge utilities:
   ```bash
   sudo apt-get install bridge-utils
   ```

3. Apply configuration:
   ```bash
   sudo netplan apply  # for netplan
   # OR
   sudo systemctl restart networking  # for /etc/network/interfaces
   ```

### Phase 3: Access Point Configuration

1. Create hostapd configuration `/etc/hostapd/camera-bridge-ap.conf`:
   ```
   # Interface configuration
   interface=wlan1
   bridge=br0

   # WiFi configuration
   ssid=CameraBridge-Photos
   hw_mode=g
   channel=6
   ieee80211n=1
   wmm_enabled=1

   # Security
   wpa=2
   wpa_passphrase=YourSecurePassword123
   wpa_key_mgmt=WPA-PSK
   wpa_pairwise=CCMP
   rsn_pairwise=CCMP

   # Access Point settings
   macaddr_acl=0
   auth_algs=1
   ignore_broadcast_ssid=0

   # Performance tuning
   ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40]
   ```

2. Update hostapd default config `/etc/default/hostapd`:
   ```bash
   DAEMON_CONF="/etc/hostapd/camera-bridge-ap.conf"
   ```

3. Enable and test hostapd:
   ```bash
   sudo systemctl unmask hostapd
   sudo systemctl enable hostapd
   sudo systemctl start hostapd
   ```

### Phase 4: DHCP Configuration Update

1. Update `/etc/dnsmasq.d/camera-bridge.conf`:
   ```
   # Camera Bridge DHCP Configuration

   # Bridge interface (replaces eno1)
   interface=br0
   dhcp-range=interface:br0,192.168.10.10,192.168.10.50,255.255.255.0,24h

   # General options
   bind-dynamic
   except-interface=lo
   except-interface=wlp1s0
   dhcp-option=3,192.168.10.1
   dhcp-option=6,8.8.8.8,8.8.4.4

   # Enable DNS forwarding
   server=8.8.8.8
   server=8.8.4.4
   ```

2. Restart dnsmasq:
   ```bash
   sudo systemctl restart dnsmasq
   ```

### Phase 5: Routing and NAT (Optional - for camera internet access)

1. Enable IP forwarding in `/etc/sysctl.d/99-camera-bridge.conf`:
   ```
   net.ipv4.ip_forward=1
   ```

2. Apply sysctl changes:
   ```bash
   sudo sysctl -p /etc/sysctl.d/99-camera-bridge.conf
   ```

3. Configure NAT/masquerading (if cameras need internet):
   ```bash
   sudo iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o wlp1s0 -j MASQUERADE
   sudo iptables -A FORWARD -i br0 -o wlp1s0 -j ACCEPT
   sudo iptables -A FORWARD -i wlp1s0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT

   # Make persistent
   sudo apt-get install iptables-persistent
   sudo netfilter-persistent save
   ```

### Phase 6: Firewall Rules

1. Allow traffic within bridge:
   ```bash
   sudo iptables -A FORWARD -i br0 -o br0 -j ACCEPT
   ```

2. Allow SMB traffic:
   ```bash
   sudo iptables -A INPUT -i br0 -p tcp --dport 445 -j ACCEPT
   sudo iptables -A INPUT -i br0 -p tcp --dport 139 -j ACCEPT
   ```

3. Optional: Client isolation (prevent camera-to-camera communication):
   ```bash
   # Add to hostapd config
   ap_isolate=1
   ```

### Phase 7: Samba Configuration Update

1. Update `/opt/camera-bridge/config/smb.conf`:
   ```
   [global]
       # Change from:
       # interfaces = lo eth0 wlan0
       # To:
       interfaces = lo br0 wlp1s0
       bind interfaces only = yes
   ```

2. Restart Samba:
   ```bash
   sudo systemctl restart smbd
   sudo systemctl restart nmbd
   ```

### Phase 8: Service Integration

1. Create systemd service `/etc/systemd/system/camera-bridge-ap.service`:
   ```ini
   [Unit]
   Description=Camera Bridge WiFi Access Point
   After=network.target hostapd.service
   Wants=hostapd.service

   [Service]
   Type=oneshot
   RemainAfterExit=yes
   ExecStart=/opt/camera-bridge/scripts/setup-wifi-ap.sh start
   ExecStop=/opt/camera-bridge/scripts/setup-wifi-ap.sh stop

   [Install]
   WantedBy=multi-user.target
   ```

2. Update `wifi-manager.sh` to include AP management commands

3. Add WiFi AP status to terminal UI

4. Add monitoring for WiFi AP status

## Alternative Option 2: Separate WiFi Network with Routing

**Use case:** If you want to segment WiFi and Ethernet cameras

```
Cameras (WiFi) → USB WiFi AP (192.168.11.0/24) → Router → eno1 (192.168.10.0/24)
Cameras (Ethernet) → eno1 (192.168.10.1)
```

**Implementation:**
1. Configure USB WiFi as separate AP on 192.168.11.0/24
2. Run second DHCP range for WiFi cameras
3. Setup routing between 192.168.11.0/24 and 192.168.10.0/24
4. Configure SMB to listen on both networks
5. More complex but provides network segmentation

## Key Technical Considerations

### 1. Driver Compatibility
- **Critical:** Verify TP-Link adapter supports AP mode
- Check with: `iw list | grep -A 10 "Supported interface modes"`
- Many USB adapters don't support AP mode
- TP-Link 2357:011f should support AP mode (verify first)

### 2. Performance
- **USB Bandwidth**: USB 2.0 (~480 Mbps) vs 3.0 (~5 Gbps)
- **CPU Overhead**: WiFi processing may increase CPU usage
- **Concurrent Clients**: Typical limit 10-20 devices
- **Photo Transfer Speed**: Should be sufficient for camera uploads

### 3. Built-in WiFi Conflict
- Keep `wlp1s0` for internet connection only
- Ensure it doesn't interfere with USB WiFi AP
- Use different WiFi bands if possible:
  - Built-in: Connected to 5GHz home network
  - USB AP: Operate on 2.4GHz for camera compatibility

### 4. Channel Selection
- **2.4GHz**: Channels 1, 6, or 11 (non-overlapping)
- **5GHz**: Less congestion, better for photo transfer
- **Recommendation**: Check camera WiFi capabilities first
- Avoid interference with `wlp1s0` channel

### 5. Samba Performance
- Bridge mode requires no special Samba configuration
- Same performance as direct ethernet
- Both interfaces serve same share

## Configuration Files Reference

| File | Purpose |
|------|---------|
| `/etc/netplan/01-camera-bridge.yaml` | Bridge network configuration (netplan) |
| `/etc/network/interfaces` | Bridge network configuration (ifupdown) |
| `/etc/hostapd/camera-bridge-ap.conf` | WiFi AP configuration |
| `/etc/default/hostapd` | Hostapd service configuration |
| `/etc/dnsmasq.d/camera-bridge.conf` | DHCP server configuration |
| `/etc/sysctl.d/99-camera-bridge.conf` | IP forwarding settings |
| `/opt/camera-bridge/config/smb.conf` | Samba interface binding |
| `/etc/systemd/system/camera-bridge-ap.service` | AP service management |
| `/opt/camera-bridge/scripts/setup-wifi-ap.sh` | AP setup/teardown script |

## Testing Strategy

### Pre-Implementation Tests
1. ✓ Verify USB WiFi adapter detected: `lsusb`
2. ✓ Check driver support: `lsmod | grep 80211`
3. ✓ Verify AP mode support: `iw list`
4. ✓ Test USB adapter independently

### Post-Implementation Tests
1. **Bridge Creation**
   ```bash
   brctl show
   ip addr show br0
   ping 192.168.10.1  # from external device
   ```

2. **Access Point**
   ```bash
   sudo systemctl status hostapd
   # Scan for SSID from another device
   ```

3. **DHCP Assignment**
   ```bash
   # Connect WiFi device and check:
   cat /var/lib/misc/dnsmasq.leases
   ```

4. **SMB Share Access**
   ```bash
   # From WiFi client:
   smbclient -L 192.168.10.1 -U camera
   ```

5. **Concurrent Connections**
   - Connect camera via ethernet
   - Connect camera via WiFi
   - Verify both get DHCP
   - Verify both can access SMB share

6. **File Transfer Performance**
   - Upload test images over WiFi
   - Upload test images over ethernet
   - Verify sync to Dropbox works for both

7. **Persistence**
   ```bash
   sudo reboot
   # Verify all services start automatically
   # Verify bridge is created
   # Verify AP is broadcasting
   ```

### Load Testing
- Connect multiple WiFi clients simultaneously
- Transfer files from multiple sources
- Monitor CPU/memory usage
- Check for packet drops

## Rollback Plan

### Backup Commands
```bash
# Backup current network config
sudo cp /etc/netplan/*.yaml /opt/camera-bridge/backup/
sudo cp /etc/network/interfaces /opt/camera-bridge/backup/
sudo cp /etc/dnsmasq.d/camera-bridge.conf /opt/camera-bridge/backup/
sudo cp /opt/camera-bridge/config/smb.conf /opt/camera-bridge/backup/
```

### Rollback Steps
1. Stop new services:
   ```bash
   sudo systemctl stop hostapd
   sudo systemctl stop camera-bridge-ap
   ```

2. Remove bridge:
   ```bash
   sudo ip link set br0 down
   sudo brctl delbr br0
   ```

3. Restore original network config:
   ```bash
   sudo cp /opt/camera-bridge/backup/*.yaml /etc/netplan/
   sudo netplan apply
   ```

4. Restore dnsmasq config:
   ```bash
   sudo cp /opt/camera-bridge/backup/camera-bridge.conf /etc/dnsmasq.d/
   sudo systemctl restart dnsmasq
   ```

5. Restore Samba config:
   ```bash
   sudo cp /opt/camera-bridge/backup/smb.conf /opt/camera-bridge/config/
   sudo systemctl restart smbd nmbd
   ```

### Rollback Verification
- Ethernet cameras can connect
- DHCP still works on eno1
- SMB share accessible
- Sync to Dropbox working

## Troubleshooting Guide

### Issue: USB WiFi not detected
```bash
lsusb  # Verify device appears
dmesg | tail -50  # Check for driver errors
modprobe -r rtl8xxxu  # Reload driver (example)
modprobe rtl8xxxu
```

### Issue: AP mode not supported
- Check driver: `iw list | grep "Supported interface modes"`
- May need different driver or different USB adapter
- Some adapters require proprietary drivers

### Issue: Bridge not forwarding packets
```bash
sudo sysctl net.bridge.bridge-nf-call-iptables=0
sudo sysctl net.bridge.bridge-nf-call-ip6tables=0
```

### Issue: DHCP not working on WiFi
```bash
sudo systemctl status dnsmasq
journalctl -u dnsmasq -n 50
# Check interface binding
sudo tcpdump -i br0 port 67 or port 68
```

### Issue: Hostapd won't start
```bash
sudo systemctl status hostapd
journalctl -u hostapd -n 50
# Test config
sudo hostapd -dd /etc/hostapd/camera-bridge-ap.conf
```

### Issue: SMB not accessible over WiFi
```bash
# Check Samba is listening on bridge
sudo netstat -tlnp | grep smbd
# Verify firewall
sudo iptables -L -n -v
# Test from WiFi client
smbclient -L 192.168.10.1 -U camera
```

## Security Considerations

1. **WiFi Password Strength**
   - Use WPA2 minimum (WPA3 if supported)
   - Password: 12+ characters, mixed case, numbers, symbols
   - Don't use default passwords

2. **Client Isolation**
   - Consider enabling `ap_isolate=1` in hostapd
   - Prevents cameras from seeing each other
   - Reduces attack surface

3. **SSID Broadcasting**
   - Keep `ignore_broadcast_ssid=0` for camera convenience
   - Hidden SSIDs don't provide real security

4. **MAC Filtering (Optional)**
   - Can restrict to known camera MACs
   - Add to hostapd config: `macaddr_acl=1`
   - Maintain MAC whitelist file

5. **Network Segmentation**
   - Keep camera network (192.168.10.x) separate from home network
   - Only allow necessary traffic to/from wlp1s0
   - Firewall rules to protect camera bridge system

## Performance Expectations

### WiFi Transfer Speeds
- **2.4GHz 802.11n**: ~50-100 Mbps real-world
- **5GHz 802.11ac**: ~200-400 Mbps real-world
- **Sufficient for**: JPEG uploads (2-10MB), RAW files (20-50MB)
- **Upload time**: 10MB JPEG ~1-2 seconds on good WiFi

### Concurrent Camera Support
- **Recommended**: 5-10 cameras simultaneously
- **Maximum**: 15-20 (depends on USB adapter)
- **Bottleneck**: Usually USB bandwidth, not WiFi

### CPU/Memory Impact
- **Idle**: Minimal (~1-2% CPU increase)
- **Active Transfer**: 10-20% CPU increase
- **Memory**: ~50-100MB additional for hostapd/bridge

## Future Enhancements

1. **Band Steering**: Prefer 5GHz when available
2. **Load Balancing**: Multiple USB WiFi adapters
3. **WiFi Roaming**: Multiple APs with same SSID
4. **Guest Network**: Separate SSID for temporary access
5. **Monitoring Dashboard**: WiFi clients, signal strength, throughput
6. **Auto-channel Selection**: Dynamic channel based on interference
7. **Captive Portal**: For camera registration/setup

## Documentation Updates Needed

After implementation, update:
- `/opt/camera-bridge/docs/INSTALLATION.md`
- `/opt/camera-bridge/CLAUDE.md`
- `/opt/camera-bridge/README.md` (if exists)
- Terminal UI help text
- Web interface documentation

## Notes

- Date created: 2025-10-04
- System: Ubuntu/Debian on PC hardware
- USB WiFi: TP-Link 802.11ac (2357:011f)
- Ethernet: Intel eno1
- Built-in WiFi: wlp1s0 (for internet)
- Current network: 192.168.10.0/24
- This is an ADDITION - ethernet will continue to work

---

**Status**: Planning phase - ready for implementation
**Next Step**: Verify USB WiFi AP mode support, then proceed with Phase 1
