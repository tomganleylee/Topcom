#!/bin/bash
# Simple scanner script for Brother DS-640
# Scans documents and saves to the Samba share

SCAN_DIR="/srv/samba/camera-share/scans"
SCANNER_DEVICE="brother4:bus2;dev5"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_FILE="$SCAN_DIR/scan_$TIMESTAMP.jpg"

# Create scan directory if it doesn't exist
mkdir -p "$SCAN_DIR"

# Ensure proper permissions
chown camerabridge:scanner "$SCAN_DIR"
chmod 775 "$SCAN_DIR"

echo "Starting scan..."
echo "Output: $OUTPUT_FILE"

# Perform the scan
scanimage -d "$SCANNER_DEVICE" \
    --format=jpeg \
    --resolution 300 \
    --output-file="$OUTPUT_FILE" \
    2>&1 | tee /var/log/camera-bridge/scanner.log

if [ -f "$OUTPUT_FILE" ]; then
    # Set proper permissions
    chown camerabridge:scanner "$OUTPUT_FILE"
    chmod 664 "$OUTPUT_FILE"
    echo "Scan complete: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
    exit 0
else
    echo "ERROR: Scan failed - no output file created"
    exit 1
fi
