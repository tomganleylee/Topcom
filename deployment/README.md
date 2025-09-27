# Camera Bridge Deployment Scripts

This directory contains all scripts needed for deploying Camera Bridge to new machines.

## Directory Structure

```
deployment/
├── tailscale/               # Remote access via Tailscale
│   ├── install-tailscale-safe.sh
│   ├── configure-tailscale-ssh.sh
│   ├── tailscale-permanent-setup.sh
│   └── tailscale-deploy-with-key.sh
│
└── autostart/              # Auto-start and auto-login
    ├── camera-bridge-autostart.sh
    ├── setup-camera-bridge-autostart.sh
    └── setup-camerabridge-autologin.sh
```

## Quick Deployment

From the root camera-bridge directory:

```bash
sudo ./deploy-system.sh
```

## Tailscale Scripts

### Initial Setup
1. `install-tailscale-safe.sh` - Installs Tailscale without affecting network
2. `configure-tailscale-ssh.sh` - Configures SSH-only access
3. `tailscale-permanent-setup.sh` - Sets up permanent connection

### Automated Deployment
Use `tailscale-deploy-with-key.sh` with a pre-auth key:
```bash
TAILSCALE_AUTH_KEY='tskey-auth-XXX' sudo ./tailscale-deploy-with-key.sh
```

Get auth keys from: https://login.tailscale.com/admin/settings/keys

## Auto-Start Scripts

### Setup Auto-Login
```bash
sudo ./autostart/setup-camerabridge-autologin.sh
```

### Configure Boot Auto-Start
```bash
sudo ./autostart/setup-camera-bridge-autostart.sh
```

### Manual Auto-Start Script
The `camera-bridge-autostart.sh` script can be run manually or at boot.

## Important Notes

- All scripts require sudo/root access
- Test in a development environment first
- Keep Tailscale auth keys secure
- Default SMB password is 'camera' - change in production
- Check logs at `/var/log/camera-bridge/` for issues

## Support

See the main [COMPLETE_DEPLOYMENT.md](../COMPLETE_DEPLOYMENT.md) for detailed instructions.