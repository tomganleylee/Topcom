# Update Guide - For Already Configured Machine

## Overview
Since your second machine is **already configured and working**, you only need to pull the latest updates from this repository.

---

## Quick Update (For Working Systems)

### Step 1: Pull Latest Changes

```bash
# On the second machine, navigate to the camera-bridge directory
cd /opt/camera-bridge

# Pull latest changes
git pull origin main
```

### Step 2: Review What Changed

```bash
# See what files were updated
git log --oneline -10
git diff HEAD~5 HEAD --stat
```

### Step 3: Update Only Changed Components

**If configuration files changed:**
```bash
# Backup current configs
sudo cp /etc/systemd/system/camera-bridge.service /etc/systemd/system/camera-bridge.service.backup

# Copy updated configs (only if needed)
sudo cp config/camera-bridge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart camera-bridge
```

**If scripts changed:**
```bash
# Scripts are automatically updated by git pull
# Just restart the service
sudo systemctl restart camera-bridge
```

**If WiFi hotspot configs changed:**
```bash
sudo cp config/hostapd.conf /etc/hostapd/
sudo cp config/dnsmasq-ap.conf /etc/dnsmasq.d/
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq
```

---

## What You DON'T Need to Re-install

If your second machine already has these working, you don't need to re-run installation:

- ✅ WiFi Hotspot (hostapd/dnsmasq) - already installed
- ✅ Brother Scanner drivers - already installed
- ✅ Camera Bridge service - already installed
- ✅ Nginx web interface - already installed
- ✅ Dropbox integration - already configured

---

## What Might Need Updating

### Recent Changes From This Machine

Based on recent work, here's what might have changed:

1. **Boot fixes** - See [BOOT_FIXES_APPLIED.md](BOOT_FIXES_APPLIED.md)
2. **Sudo configuration** - See [SUDOERS_FIX.md](SUDOERS_FIX.md)
3. **Scanner integration improvements** - May have updated scripts
4. **WiFi hotspot configuration** - May have tweaked settings

### Selective Update Commands

**Only update boot configuration if you're having boot issues:**
```bash
cd /opt/camera-bridge
sudo bash scripts/fix-boot-issues.sh
```

**Only update scanner setup if scanner isn't working:**
```bash
# No need if scanner already works
# But if you want latest scanner scripts:
sudo bash Topcom-main/scripts/setup-brother-scanner.sh
```

**Only update WiFi if you're having WiFi issues:**
```bash
# No need if WiFi hotspot already works
# But if you want to sync WiFi settings:
sudo cp config/hostapd.conf /etc/hostapd/
sudo systemctl restart hostapd
```

---

## Recommended Update Process

### For a Working System:

```bash
# 1. Pull updates
cd /opt/camera-bridge
git pull origin main

# 2. Check if any service files changed
git diff HEAD~1 config/camera-bridge.service

# 3. If service files changed, update them
sudo cp config/camera-bridge.service /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Restart only if changes affect running services
sudo systemctl restart camera-bridge

# 5. Verify everything still works
sudo systemctl status camera-bridge
sudo systemctl status hostapd
sudo systemctl status dnsmasq
```

---

## New Features to Consider

If this machine has new features the second machine doesn't have:

### Check for new systemd services:
```bash
ls -la config/*.service
```

### Check for new scripts:
```bash
ls -la scripts/
```

### Install only new features you want:
```bash
# Example: If there's a new monitoring script
sudo cp scripts/new-monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/new-monitor.sh
```

---

## Troubleshooting After Update

### Service won't start:
```bash
# Check logs
sudo journalctl -u camera-bridge -n 50

# Reset to last working state
git log --oneline -5
git checkout <previous-commit-hash>
sudo systemctl restart camera-bridge
```

### Configuration conflicts:
```bash
# Keep your current config
git checkout --ours config/your-file.conf

# Or take the new config
git checkout --theirs config/your-file.conf
```

---

## Full Fresh Install (Only If Needed)

**Only do this if the system is broken and you want to start fresh:**

```bash
# Full reinstall
cd /opt/camera-bridge

# WiFi Hotspot
sudo bash Topcom-main/scripts/setup-wifi-hotspot.sh

# Scanner
sudo bash Topcom-main/scripts/setup-brother-scanner.sh

# Camera Bridge
sudo bash Topcom-main/scripts/install-complete.sh
```

But this is **not necessary** if your system is already working!

---

## Summary

**For an already working machine:**
1. `git pull origin main` - Get updates
2. Review what changed
3. Only restart services if configs changed
4. Don't re-run installation scripts unless something is broken

**The main benefit of git:** You can now keep both machines synchronized by pulling updates, without having to re-install everything.

---

## Quick Reference

```bash
# Update code only
git pull

# Update and restart service
git pull && sudo systemctl restart camera-bridge

# Update configs and restart all services
git pull
sudo cp config/*.service /etc/systemd/system/
sudo cp config/hostapd.conf /etc/hostapd/
sudo cp config/dnsmasq-ap.conf /etc/dnsmasq.d/
sudo systemctl daemon-reload
sudo systemctl restart camera-bridge hostapd dnsmasq

# Check what changed
git log --oneline -10
git diff HEAD~5 HEAD

# Roll back if something breaks
git log --oneline
git checkout <previous-commit-hash>
sudo systemctl restart camera-bridge
```

---

Last Updated: 2025-10-11
