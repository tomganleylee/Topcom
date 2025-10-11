# WiFi Hotspot Research - TP-Link AC600 (RTL8821AU)

## Current Situation

**Hardware Detected:**
- Device ID: `2357:011f` TP-Link 802.11ac WLAN Adapter
- Chipset: Realtek RTL8821AU
- Current Interface: `wlp1s0` (internal WiFi, currently connected to "Toogle")
- Target: Use TP-Link AC600 USB adapter as hotspot

**System:**
- Ubuntu kernel 6.8.0-85-generic
- hostapd, dnsmasq, wireless-tools already installed
- Ethernet: `eno1` (192.168.10.1)

## Problem Analysis

### Why Previous Attempts Failed

Based on research, the typical issues with RTL8821AU hotspot setups are:

1. **No Driver Installed**
   - The RTL8821AU requires a custom driver (morrownr/8821au-20210708)
   - Without it, the adapter can't function properly

2. **NetworkManager Conflicts**
   - NetworkManager fights with hostapd for control of the interface
   - Must mark the hotspot interface as "unmanaged"

3. **Wrong Driver Configuration**
   - RTL8821AU needs specific module parameters for AP mode
   - Must load with `rtw_vht_enable=2` for 5GHz 80MHz channels

4. **Interface Naming Issues**
   - USB WiFi adapters may get different names (wlan0, wlx*, etc.)
   - Scripts must detect the interface dynamically

5. **Dual WiFi Confusion**
   - Having 2 WiFi interfaces (internal + USB) causes confusion
   - Must explicitly configure which interface does what

## Recommended Architecture

### Network Layout

```
Internet
    ↓
[wlp1s0] Internal WiFi (Client mode - connects to internet)
    ↓
[Linux Bridge/NAT]
    ↓
[eno1] Ethernet ← → Cameras
[wlx*] USB AC600 (AP mode - hotspot for WiFi cameras)
```

### Interface Roles

| Interface | Role | IP | Description |
|-----------|------|-----|-------------|
| wlp1s0 | Client | DHCP | Connects to existing WiFi for internet |
| eno1 | Server | 192.168.10.1 | Serves wired cameras via DHCP |
| wlx* | AP | 192.168.10.1 | Hotspot for wireless cameras (bridged with eno1) |

**Key Point:** The USB AC600 and ethernet should be on the SAME network (192.168.10.0/24) so cameras can connect via either method.

## Solution Requirements

### 1. Install RTL8821AU Driver

**Best Driver:** morrownr/8821au-20210708
- Proven to work with hostapd
- Supports AP mode, WPA3-SAE
- Uses DKMS (auto-recompiles on kernel updates)

**Installation:**
```bash
sudo apt install -y build-essential dkms git iw
git clone https://github.com/morrownr/8821au-20210708.git
cd 8821au-20210708
sudo ./install-driver.sh
```

### 2. Configure NetworkManager

**Problem:** NetworkManager will try to manage the USB WiFi adapter and conflict with hostapd.

**Solution:** Mark USB WiFi as unmanaged

`/etc/NetworkManager/conf.d/unmanaged-wifi.conf`:
```ini
[keyfile]
unmanaged-devices=interface-name:wlx*;interface-name:wlan1
```

This allows:
- `wlp1s0` (internal WiFi) → Managed by NetworkManager (for internet)
- `wlx*` (USB WiFi) → Unmanaged, controlled by hostapd (for hotspot)

### 3. Configure hostapd

**Critical Settings for RTL8821AU:**

`/etc/hostapd/hostapd.conf`:
```ini
# Interface and driver
interface=wlx???????????????  # Detected at runtime
driver=nl80211
bridge=br0

# Network settings
ssid=Camera-Bridge
hw_mode=g              # 2.4GHz (better compatibility with cameras)
channel=6              # Non-overlapping channel
ieee80211n=1           # Enable N mode
wmm_enabled=1

# Security
wpa=2
wpa_passphrase=camera123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

# Country and regulations
country_code=US
ieee80211d=1
ieee80211h=0

# Performance
beacon_int=100
dtim_period=2
max_num_sta=10
rts_threshold=2347
fragm_threshold=2346
```

**Note:** Must use `bridge=br0` to share the 192.168.10.0/24 network with ethernet.

### 4. Configure Bridge

**Problem:** Cameras on WiFi and ethernet need to be on the same network.

**Solution:** Create a bridge between eno1 and the WiFi AP.

`/etc/netplan/01-camera-bridge.yaml` or equivalent:
```yaml
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: no

  bridges:
    br0:
      interfaces: [eno1]
      addresses: [192.168.10.1/24]
      dhcp4: no
      parameters:
        stp: false
        forward-delay: 0
```

**Note:** The WiFi interface (wlx*) will be added to the bridge by hostapd automatically when using `bridge=br0` in hostapd.conf.

### 5. Update dnsmasq

**Current:** Only listening on eno1
**Need:** Listen on br0 (which includes both eno1 and WiFi)

`/etc/dnsmasq.d/camera-bridge.conf`:
```ini
# Bridge interface (includes eno1 + WiFi AP)
interface=br0
bind-dynamic
dhcp-range=interface:br0,192.168.10.10,192.168.10.50,255.255.255.0,24h

# DNS servers
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4

# Don't listen on loopback
except-interface=lo
```

### 6. Update iptables/NAT

**Current:** Forwarding from eno1 to wlp1s0
**Need:** Forwarding from br0 (eno1+WiFi) to wlp1s0

```bash
# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT for internet access (via internal WiFi)
iptables -t nat -A POSTROUTING -o wlp1s0 -j MASQUERADE
iptables -A FORWARD -i br0 -o wlp1s0 -j ACCEPT
iptables -A FORWARD -i wlp1s0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Known Issues and Solutions

### Issue 1: USB WiFi interface name changes

**Problem:** USB adapters can get different names: wlan0, wlan1, wlx00e04c??????

**Solution:** Detect dynamically at runtime:
```bash
USB_WIFI=$(iw dev | awk '/phy#1/{getline; print $2}')
```

Or use MAC-based naming in NetworkManager.

### Issue 2: hostapd fails to start

**Causes:**
1. Interface already in use by NetworkManager
2. Driver doesn't support AP mode
3. Wrong channel/frequency for region

**Solutions:**
1. Ensure interface is unmanaged
2. Verify driver supports AP mode: `iw list | grep "Supported interface modes"`
3. Use 2.4GHz channels 1-11 for US

### Issue 3: Clients can connect but no internet

**Cause:** NAT/forwarding not configured properly

**Solution:** Verify:
```bash
# Check forwarding enabled
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# Check iptables rules
iptables -t nat -L -n -v
iptables -L FORWARD -n -v

# Check routing
ip route show
```

### Issue 4: Bridge fails with "can't add to bridge"

**Cause:** Interface is up/configured before adding to bridge

**Solution:** Bring interface down first:
```bash
ip link set eno1 down
ip link set eno1 master br0
ip link set eno1 up
```

### Issue 5: 5GHz channels don't work

**Cause:** Regional restrictions, DFS channels require radar detection

**Solution:** Stick to 2.4GHz for better camera compatibility:
- Channels 1, 6, 11 (non-overlapping)
- Better range and wall penetration
- Better device compatibility

## Step-by-Step Implementation Plan

### Phase 1: Install Driver
1. Install prerequisites (build-essential, dkms, git, iw)
2. Clone morrownr/8821au-20210708
3. Run install-driver.sh
4. Reboot
5. Verify: `lsmod | grep 8821au`

### Phase 2: Detect USB WiFi Interface
1. Plug in TP-Link AC600
2. Run: `iw dev` to find interface name
3. Verify: `iw list` shows AP mode support

### Phase 3: Configure NetworkManager
1. Create unmanaged-wifi.conf
2. Restart NetworkManager
3. Verify USB WiFi is unmanaged

### Phase 4: Create Bridge
1. Configure netplan/networkd for br0
2. Add eno1 to bridge
3. Assign 192.168.10.1/24 to br0
4. Apply configuration

### Phase 5: Configure hostapd
1. Update /etc/hostapd/hostapd.conf with correct interface
2. Set bridge=br0
3. Test: `sudo hostapd -d /etc/hostapd/hostapd.conf`
4. Enable service if successful

### Phase 6: Update dnsmasq
1. Change interface from eno1 to br0
2. Restart dnsmasq
3. Verify DHCP works on both ethernet and WiFi

### Phase 7: Update NAT/Forwarding
1. Change iptables rules from eno1 to br0
2. Save rules
3. Test internet access from both interfaces

### Phase 8: Testing
1. Connect camera via ethernet → verify DHCP, internet, SMB access
2. Connect phone via WiFi → verify DHCP, internet
3. Upload photo from both → verify Dropbox sync
4. Scan document → verify sync

## Automation Strategy

Create a single setup script that:
1. Detects if RTL8821AU driver is installed (checks `modinfo 8821au`)
2. If not, offers to install it automatically
3. Detects USB WiFi interface name dynamically
4. Configures NetworkManager, hostapd, bridge, dnsmasq automatically
5. Provides clear status messages and troubleshooting hints

## Alternative: Use Internal WiFi for AP

**If USB WiFi continues to cause issues:**

Consider using internal WiFi (wlp1s0) as the AP and USB WiFi for internet (if supported).

**Pros:**
- Internal WiFi likely has better driver support
- May have better AP mode compatibility

**Cons:**
- Requires disconnecting from current WiFi network
- Need alternative internet connection (ethernet, USB tethering, etc.)

## Testing Checklist

- [ ] RTL8821AU driver loads without errors
- [ ] USB WiFi interface detected and has unique name
- [ ] `iw list` shows "AP" in supported modes
- [ ] Interface is unmanaged by NetworkManager
- [ ] Bridge br0 created successfully
- [ ] eno1 added to bridge without errors
- [ ] hostapd starts without errors (test with -d flag)
- [ ] SSID "Camera-Bridge" visible on phone
- [ ] Can connect to WiFi with password "camera123"
- [ ] Connected device gets 192.168.10.x IP
- [ ] Can ping 192.168.10.1 from WiFi device
- [ ] Can access internet from WiFi device
- [ ] Can access SMB share from WiFi device
- [ ] Can upload photo from WiFi device
- [ ] Photo syncs to Dropbox correctly

## Conclusion

The TP-Link AC600 can work as a hotspot, but requires:
1. Proper driver installation (morrownr/8821au-20210708)
2. NetworkManager configuration to avoid conflicts
3. Bridge configuration to share network with ethernet
4. Careful hostapd configuration for RTL8821AU chipset

The biggest past issues were likely:
- Missing/wrong driver
- NetworkManager conflicts
- No bridge configuration (WiFi and ethernet on separate networks)

With proper setup, both ethernet and WiFi cameras will be on the same 192.168.10.0/24 network and can access SMB + Dropbox sync.
