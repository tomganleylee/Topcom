# Git Commands to Push Camera Bridge to Repository

Execute these commands in order to push all the Camera Bridge files to your git repository.

## Step 1: Check Current Status

```bash
cd ~/camera-bridge
git status
```

## Step 2: Add All New Files

```bash
# Add the new deployment directories and files
git add deployment/
git add deploy-system.sh
git add COMPLETE_DEPLOYMENT.md
git add GIT_PUSH_COMMANDS.md

# Add the untracked service files
git add config/dropbox-token-refresh.service
git add config/dropbox-token-refresh.timer
git add scripts/camera-bridge-service-with-refresh.sh
git add scripts/dropbox-token-manager.sh
git add scripts/install-token-refresh.sh
git add scripts/update-camera-bridge-token-refresh.sh
git add scripts/camera-bridge-service-oauth2.sh

# Add any other modified files
git add -A
```

## Step 3: Review What Will Be Committed

```bash
git status
git diff --cached
```

## Step 4: Commit Changes

```bash
git commit -m "Add complete deployment system with Tailscale remote access

- Added master deployment script (deploy-system.sh)
- Added comprehensive deployment documentation (COMPLETE_DEPLOYMENT.md)
- Added Tailscale installation and configuration scripts for remote SSH access
- Added auto-start and auto-login scripts for appliance-like operation
- Added Dropbox token refresh service for OAuth2 token management
- Added deployment/ directory with organized scripts
- Scripts support permanent Tailscale connection without key expiry
- Includes pre-auth key deployment for automated setup
- All services configured to auto-start on boot
- Complete documentation for deploying to new machines"
```

## Step 5: Push to Remote Repository

```bash
# Push to the main branch
git push origin main

# Or if you're on a different branch
git push origin your-branch-name
```

## Step 6: Verify Push

```bash
# Check remote status
git remote -v

# Check if push was successful
git log --oneline -5

# Check remote tracking
git branch -vv
```

## Alternative: Single Command Push

If you want to add and push everything at once:

```bash
cd ~/camera-bridge
git add -A
git commit -m "Add complete deployment system with Tailscale and auto-start"
git push origin main
```

## If You Need to Set Up Remote First

If you haven't set up the remote repository yet:

```bash
# Add remote (replace with your repository URL)
git remote add origin https://github.com/yourusername/camera-bridge.git

# Or if using SSH
git remote add origin git@github.com:yourusername/camera-bridge.git

# Set upstream and push
git push -u origin main
```

## Files That Will Be Pushed

### New Deployment Files
- `deploy-system.sh` - Master deployment script
- `COMPLETE_DEPLOYMENT.md` - Full deployment documentation
- `deployment/tailscale/*.sh` - Tailscale setup scripts
- `deployment/autostart/*.sh` - Auto-start configuration
- `deployment/README.md` - Deployment scripts documentation

### Service Files
- `config/dropbox-token-refresh.service`
- `config/dropbox-token-refresh.timer`
- `scripts/camera-bridge-service-with-refresh.sh`
- `scripts/dropbox-token-manager.sh`
- `scripts/install-token-refresh.sh`
- `scripts/update-camera-bridge-token-refresh.sh`
- `scripts/camera-bridge-service-oauth2.sh`

## Troubleshooting

### Authentication Issues
```bash
# Check your git configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# If using HTTPS, you may need a personal access token
# GitHub: Settings → Developer settings → Personal access tokens
```

### Large File Issues
If you get errors about large files:
```bash
# Check file sizes
find . -size +100M -type f

# Add large files to .gitignore if needed
echo "large-file-name" >> .gitignore
```

### Permission Issues
```bash
# Ensure you own the repository
sudo chown -R $USER:$USER ~/camera-bridge
```

## After Pushing

1. Verify on GitHub/GitLab that all files are present
2. Test cloning to a new directory:
   ```bash
   cd /tmp
   git clone https://github.com/yourusername/camera-bridge.git test-clone
   cd test-clone
   ls -la
   ```
3. Document the repository URL in your deployment notes

---

Remember to update the repository URL in the deployment scripts and documentation with your actual repository URL!