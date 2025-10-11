#!/bin/bash

# Complete Camera Bridge Deployment with Scanner Support
# Usage: sudo ./deploy-complete.sh [--no-scanner]

set -e

# Configuration
INSTALL_SCANNER=true  # Scanner enabled by default

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-scanner)
            INSTALL_SCANNER=false
            shift
            ;;
        --with-scanner)
            INSTALL_SCANNER=true
            shift
            ;;
        --help|-h)
            echo "Usage: sudo ./deploy-complete.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-scanner      Skip Brother DS-640 scanner support"
            echo "  --with-scanner    Install Brother DS-640 scanner support (DEFAULT)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Examples:"
            echo "  sudo ./deploy-complete.sh                  # Install with scanner (default)"
            echo "  sudo ./deploy-complete.sh --no-scanner     # Install without scanner"
            exit 0
            ;;
    esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Camera Bridge Complete Deployment${NC}"
if [ "$INSTALL_SCANNER" = "true" ]; then
    echo -e "${GREEN}With Brother DS-640 Scanner Support${NC}"
fi
echo -e "${GREEN}================================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Run main installation
echo -e "${GREEN}Step 1: Installing Camera Bridge...${NC}"
cd "$SCRIPT_DIR"
export INSTALL_SCANNER="$INSTALL_SCANNER"
./scripts/install-complete.sh

# Step 2: Install scanner if requested
if [ "$INSTALL_SCANNER" = "true" ]; then
    echo ""
    echo -e "${GREEN}Step 2: Installing Brother DS-640 Scanner Support...${NC}"
    ./scripts/setup-brother-scanner.sh

    # Update monitoring service to use scanner-enabled version
    echo -e "${GREEN}Step 3: Updating monitoring service for scanner...${NC}"
    cp "$SCRIPT_DIR/scripts/monitor-service-with-scanner.sh" /opt/camera-bridge/scripts/monitor-service.sh
    chmod +x /opt/camera-bridge/scripts/monitor-service.sh
    chown camerabridge:camerabridge /opt/camera-bridge/scripts/monitor-service.sh

    systemctl daemon-reload
    echo -e "${GREEN}Monitoring service updated to watch scanner directory${NC}"
fi

# Final status
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

if [ "$INSTALL_SCANNER" = "true" ]; then
    echo "✓ Camera Bridge installed"
    echo "✓ Brother DS-640 Scanner support installed"
    echo ""
    echo "Scanner Setup:"
    echo "  1. Connect Brother DS-640 via USB"
    echo "  2. Verify: lsusb | grep Brother"
    echo "  3. Configure: sudo brsaneconfig4 -a name=DS640 model=DS-640"
    echo "  4. Test scan: scanimage --test"
    echo ""
    echo "Scan Directory: /srv/scanner/scans"
    echo "SMB Share: \\\\192.168.10.1\\scanner"
    echo "Dropbox Folder: Scanned-Documents"
    echo ""
fi

echo "Web Interface: http://192.168.10.1"
echo "SMB Photo Share: \\\\192.168.10.1\\photos"
echo "Monitor Logs: sudo journalctl -u camera-bridge -f"
echo ""
echo "To start sync service (after configuring Dropbox):"
echo "  sudo systemctl start camera-bridge"
echo ""
echo -e "${GREEN}================================================${NC}"
