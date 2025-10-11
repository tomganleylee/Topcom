# Camera Bridge Boot Issues - Fixes Applied

**Date:** 2025-10-10
**Status:** All issues fixed and installation scripts updated

---

## Issues Found and Fixed

### 1. Camera Bridge Service Script - Malformed Functions
**Problem:**
- `periodic_sync()` function was called before being defined
- Function structure had nested definitions
- Caused error: `periodic_sync: command not found`

**Files Fixed:**
- `/opt/camera-bridge/scripts/camera-bridge-service.sh`

**Changes:**
- Restructured functions to be defined before use
- Removed duplicate function definitions
- Fixed `monitor_files()` function structure

---

### 2. Camera Bridge Service Configuration - Type Mismatch
**Problem:**
- Service configured as `Type=forking` but script doesn't actually fork
- Script uses `wait` command, keeping it in foreground
- Caused 30-second timeout and service failure

**Files Fixed:**
- `/opt/camera-bridge/config/camera-bridge.service` (template)
- `/etc/systemd/system/camera-bridge.service` (active)

**Changes:**
- Changed `Type=forking` to `Type=simple`
- Increased `TimeoutStartSec` from 30 to 90 seconds
- Service now starts successfully

---

### 3. Tailscale Configuration - Missing PORT Variable
**Problem:**
- `/etc/default/tailscaled` missing `PORT` variable
- Caused error: "invalid value "" for flag -port: can't be the empty string"
- Service failed to start with exit code 2

**Files Fixed:**
- `/opt/camera-bridge/scripts/setup-remote-access.sh`

**Changes:**
- Added automatic creation of `/etc/default/tailscaled` with `PORT="41641"`
- Added systemd daemon-reload after configuration
- Future Tailscale installations will have correct configuration

---

### 4. WiFi Auto-Connect Service - Not Installed
**Problem:**
- Service file existed in `/opt/camera-bridge/config/` but not installed to systemd
- WiFi would not auto-connect on boot
- Had to manually connect after each reboot

**Files Fixed:**
- `/opt/camera-bridge/scripts/install-wifi-features.sh`

**Changes:**
- Script now automatically installs service to `/etc/systemd/system/`
- Automatically enables service for boot
- Automatically starts service
- Future installations will have auto-connect working

---

### 5. Terminal UI Auto-Launch - Already Configured Correctly
**Status:** ✅ No fix needed

**Configuration:**
- Auto-login configured in `/etc/systemd/system/getty@tty1.service.d/override.conf`
- Auto-launch configured in `/home/camerabridge/.profile`
- Checks for `/opt/camera-bridge/config/autostart-enabled` file (exists)
- Should work correctly after other fixes are applied

---

## Fix Script Created

### Quick Fix Script
**Location:** `/opt/camera-bridge/scripts/fix-boot-issues.sh`

**Usage:**
```bash
sudo /opt/camera-bridge/scripts/fix-boot-issues.sh
```

**What it does:**
1. Creates backup of existing configurations
2. Fixes Tailscale PORT configuration
3. Installs WiFi auto-connect service
4. Updates camera-bridge service type and timeout
5. Reloads systemd daemon
6. Resets failed service states
7. Enables and starts all services
8. Verifies all services are running
9. Offers to reboot system

---

## Installation Scripts Updated

The following installation scripts have been updated to prevent these issues in future installations:

### 1. `/opt/camera-bridge/config/camera-bridge.service`
- Template service file used by installation scripts
- Updated to use `Type=simple` instead of `Type=forking`
- Updated to use `TimeoutStartSec=90` instead of 30

### 2. `/opt/camera-bridge/scripts/setup-remote-access.sh`
- Updated `install_tailscale()` function
- Now creates `/etc/default/tailscaled` with correct PORT configuration
- Reloads systemd after installation

### 3. `/opt/camera-bridge/scripts/install-wifi-features.sh`
- Now automatically enables WiFi auto-connect service
- Automatically starts the service after installation
- Provides feedback on service status

---

## Verification Checklist

After running the fix script and rebooting, verify:

- [ ] Camera Bridge service is running: `systemctl status camera-bridge`
- [ ] Tailscale service is running: `systemctl status tailscaled`
- [ ] WiFi auto-connect service is running: `systemctl status wifi-auto-connect`
- [ ] System auto-logged in as camerabridge user
- [ ] WiFi auto-connected to saved network
- [ ] Terminal UI launched automatically
- [ ] All services enabled for boot: `systemctl is-enabled camera-bridge tailscaled wifi-auto-connect`

---

## Expected Boot Sequence

1. System boots
2. WiFi auto-connect service starts and connects to saved network
3. Camera Bridge service starts and begins monitoring
4. Tailscale service starts (if configured)
5. Auto-login to camerabridge user on tty1
6. Terminal UI launches automatically
7. User sees Camera Bridge welcome screen

---

## Troubleshooting

If issues persist after running fix script:

### Check Service Logs
```bash
# Camera Bridge
sudo journalctl -u camera-bridge -n 50

# Tailscale
sudo journalctl -u tailscaled -n 50

# WiFi Auto-Connect
sudo journalctl -u wifi-auto-connect -n 50
```

### Manual Service Control
```bash
# Restart services
sudo systemctl restart camera-bridge
sudo systemctl restart tailscaled
sudo systemctl restart wifi-auto-connect

# Check status
sudo systemctl status camera-bridge
sudo systemctl status tailscaled
sudo systemctl status wifi-auto-connect
```

### Verify Configurations
```bash
# Check Tailscale config
cat /etc/default/tailscaled

# Check camera-bridge service
cat /etc/systemd/system/camera-bridge.service

# Check WiFi saved networks
cat /opt/camera-bridge/config/saved_networks.json
```

---

## Backups

All original configurations are backed up before changes:
- Location: `/opt/camera-bridge/backups/YYYYMMDD_HHMMSS/`
- Files backed up:
  - `camera-bridge.service`
  - `tailscaled` config

To restore from backup:
```bash
# List backups
ls -la /opt/camera-bridge/backups/

# Restore (example)
sudo cp /opt/camera-bridge/backups/20251010_*/camera-bridge.service /etc/systemd/system/
sudo systemctl daemon-reload
```

---

## Summary

All identified boot issues have been:
1. ✅ Fixed in the current system
2. ✅ Fixed in installation scripts for future deployments
3. ✅ Documented with fix script for easy replication
4. ✅ Backed up for safety

The system should now boot correctly with:
- Auto-login
- Auto WiFi connection
- Auto service startup
- Auto Terminal UI launch
