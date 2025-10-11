#!/bin/bash

# USB Gadget Mode Manager for Pi Zero 2 W
# Manages USB OTG functionality to act as mass storage device

set -e

# Configuration
GADGET_NAME="camera_bridge_storage"
GADGET_DIR="/sys/kernel/config/usb_gadget/$GADGET_NAME"
STORAGE_FILE="/home/camerabridge/usb_storage.img"
MOUNT_POINT="/mnt/camera-bridge-usb"
CONFIG_FILE="/opt/camera-bridge/config/usb-gadget.conf"
LOG_FILE="/var/log/camera-bridge/usb-gadget.log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): INFO: $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): WARN: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): ERROR: $1" >> "$LOG_FILE"
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): DEBUG: $1" >> "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if Pi Zero 2 W
check_pi_zero() {
    if ! grep -q "Pi Zero 2" /proc/device-tree/model 2>/dev/null; then
        warn "This script is optimized for Pi Zero 2 W. Other models may not support USB gadget mode."
    fi
}

# Load default configuration
load_config() {
    # Default settings
    STORAGE_SIZE_MB=2048  # 2GB default
    VENDOR_ID="0x1d6b"    # Linux Foundation
    PRODUCT_ID="0x0104"   # Multifunction Composite Gadget
    DEVICE_BCD="0x0100"   # v1.0.0
    USB_BCD="0x0200"      # USB 2.0
    DEVICE_CLASS="0x00"   # Defined at Interface level
    DEVICE_SUBCLASS="0x00"
    DEVICE_PROTOCOL="0x00"
    MAX_POWER="250"       # 250mA

    # Device strings
    MANUFACTURER="Camera Bridge"
    PRODUCT="Photo Storage Device"
    SERIAL_NUMBER="CB$(cat /proc/cpuinfo | grep Serial | cut -d' ' -f2 | tail -c 9)"

    # Load custom config if exists
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        debug "Loaded configuration from $CONFIG_FILE"
    fi
}

# Check required kernel modules
check_kernel_modules() {
    local required_modules=("dwc2" "libcomposite")
    local missing_modules=()

    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^$module"; then
            missing_modules+=("$module")
        fi
    done

    if [ ${#missing_modules[@]} -gt 0 ]; then
        warn "Missing kernel modules: ${missing_modules[*]}"
        log "Attempting to load missing modules..."
        for module in "${missing_modules[@]}"; do
            modprobe "$module" || {
                error "Failed to load module: $module"
                return 1
            }
        done
    fi

    log "All required kernel modules are loaded"
    return 0
}

# Create storage file
create_storage_file() {
    local size_mb=${1:-$STORAGE_SIZE_MB}

    if [ -f "$STORAGE_FILE" ]; then
        log "Storage file already exists: $STORAGE_FILE"
        return 0
    fi

    log "Creating storage file: $STORAGE_FILE ($size_mb MB)"

    # Ensure directory exists
    mkdir -p "$(dirname "$STORAGE_FILE")"

    # Create sparse file for efficiency
    dd if=/dev/zero of="$STORAGE_FILE" bs=1M count=0 seek="$size_mb" 2>/dev/null

    # Format as FAT32 for maximum compatibility
    log "Formatting storage file as FAT32..."
    mkfs.vfat -F 32 -n "CAMERA-BRIDGE" "$STORAGE_FILE"

    # Set proper ownership
    chown camerabridge:camerabridge "$STORAGE_FILE"
    chmod 664 "$STORAGE_FILE"

    log "Storage file created successfully"
}

# Setup USB gadget
setup_usb_gadget() {
    log "Setting up USB gadget: $GADGET_NAME"

    # Remove existing gadget if it exists
    cleanup_usb_gadget 2>/dev/null || true

    # Ensure configfs is mounted
    if ! mount | grep -q configfs; then
        mount -t configfs none /sys/kernel/config
    fi

    # Create gadget directory
    mkdir -p "$GADGET_DIR"
    cd "$GADGET_DIR"

    # Set up device descriptor
    echo "$VENDOR_ID" > idVendor
    echo "$PRODUCT_ID" > idProduct
    echo "$DEVICE_BCD" > bcdDevice
    echo "$USB_BCD" > bcdUSB
    echo "$DEVICE_CLASS" > bDeviceClass
    echo "$DEVICE_SUBCLASS" > bDeviceSubClass
    echo "$DEVICE_PROTOCOL" > bDeviceProtocol
    echo "$MAX_POWER" > bMaxPower0

    # Create English strings
    mkdir -p strings/0x409
    echo "$MANUFACTURER" > strings/0x409/manufacturer
    echo "$PRODUCT" > strings/0x409/product
    echo "$SERIAL_NUMBER" > strings/0x409/serialnumber

    # Create mass storage function
    mkdir -p functions/mass_storage.usb0

    # Configure mass storage
    echo 1 > functions/mass_storage.usb0/stall
    echo 0 > functions/mass_storage.usb0/lun.0/cdrom
    echo 0 > functions/mass_storage.usb0/lun.0/ro
    echo 1 > functions/mass_storage.usb0/lun.0/removable
    echo "$STORAGE_FILE" > functions/mass_storage.usb0/lun.0/file

    # Create configuration
    mkdir -p configs/c.1/strings/0x409
    echo "Camera Bridge Mass Storage" > configs/c.1/strings/0x409/configuration
    echo 250 > configs/c.1/MaxPower

    # Link function to configuration
    ln -s functions/mass_storage.usb0 configs/c.1/

    log "USB gadget configured successfully"
}

# Enable USB gadget
enable_usb_gadget() {
    log "Enabling USB gadget..."

    # Find USB device controller
    local udc
    udc=$(ls /sys/class/udc | head -n 1)

    if [ -z "$udc" ]; then
        error "No USB device controller found"
        return 1
    fi

    debug "Using UDC: $udc"

    # Enable the gadget
    echo "$udc" > "$GADGET_DIR/UDC"

    log "USB gadget enabled on $udc"

    # Wait for device to be ready
    sleep 2

    # Verify gadget is active
    if [ -f "$GADGET_DIR/UDC" ] && [ -s "$GADGET_DIR/UDC" ]; then
        log "✓ USB gadget is active and ready"
        return 0
    else
        error "USB gadget failed to activate"
        return 1
    fi
}

# Disable USB gadget
disable_usb_gadget() {
    log "Disabling USB gadget..."

    if [ -f "$GADGET_DIR/UDC" ]; then
        echo "" > "$GADGET_DIR/UDC" 2>/dev/null || true
    fi

    log "USB gadget disabled"
}

# Cleanup USB gadget
cleanup_usb_gadget() {
    log "Cleaning up USB gadget configuration..."

    # Disable first
    disable_usb_gadget

    if [ -d "$GADGET_DIR" ]; then
        cd "$GADGET_DIR"

        # Remove symlinks
        find configs -name "*.usb0" -type l -delete 2>/dev/null || true

        # Remove directories in reverse order
        find . -depth -type d -name "*.usb0" -exec rmdir {} \; 2>/dev/null || true
        find . -depth -type d -name "configs" -exec rmdir {} \; 2>/dev/null || true
        find . -depth -type d -name "strings" -exec rmdir {} \; 2>/dev/null || true
        find . -depth -type d -name "functions" -exec rmdir {} \; 2>/dev/null || true

        # Remove gadget directory
        cd ..
        rmdir "$GADGET_NAME" 2>/dev/null || true
    fi

    log "USB gadget cleanup completed"
}

# Mount storage for local access
mount_storage() {
    log "Mounting storage file for local access..."

    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log "Storage already mounted at $MOUNT_POINT"
        return 0
    fi

    mkdir -p "$MOUNT_POINT"

    # Mount with proper permissions for camera bridge user
    mount -o loop,uid=camerabridge,gid=camerabridge,umask=000 "$STORAGE_FILE" "$MOUNT_POINT"

    if mountpoint -q "$MOUNT_POINT"; then
        log "Storage mounted successfully at $MOUNT_POINT"
        return 0
    else
        error "Failed to mount storage"
        return 1
    fi
}

# Unmount storage
unmount_storage() {
    log "Unmounting storage..."

    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        umount "$MOUNT_POINT"
        log "Storage unmounted"
    else
        debug "Storage was not mounted"
    fi

    # Remove mount point if empty
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}

# Get gadget status
get_status() {
    echo "USB Gadget Mode Status"
    echo "====================="
    echo ""

    # Check Pi model
    local pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Unknown")
    echo "Device: $pi_model"

    # Check if gadget is configured
    if [ -d "$GADGET_DIR" ]; then
        echo "Gadget: Configured ✓"

        # Check if enabled
        if [ -f "$GADGET_DIR/UDC" ] && [ -s "$GADGET_DIR/UDC" ]; then
            local udc=$(cat "$GADGET_DIR/UDC")
            echo "Status: Active on $udc ✓"
        else
            echo "Status: Configured but not active"
        fi
    else
        echo "Gadget: Not configured"
        echo "Status: Inactive"
    fi

    # Check storage file
    if [ -f "$STORAGE_FILE" ]; then
        local size=$(du -h "$STORAGE_FILE" | cut -f1)
        echo "Storage: $STORAGE_FILE ($size) ✓"
    else
        echo "Storage: Not created"
    fi

    # Check mount status
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        echo "Mount: $MOUNT_POINT ✓"
        local files=$(find "$MOUNT_POINT" -type f 2>/dev/null | wc -l)
        echo "Files: $files files in storage"
    else
        echo "Mount: Not mounted"
    fi

    # Check kernel modules
    echo ""
    echo "Kernel Modules:"
    for module in dwc2 libcomposite; do
        if lsmod | grep -q "^$module"; then
            echo "  ✓ $module loaded"
        else
            echo "  ✗ $module not loaded"
        fi
    done

    # Check USB controller
    echo ""
    echo "USB Controllers:"
    ls /sys/class/udc 2>/dev/null | while read -r udc; do
        echo "  • $udc"
    done || echo "  No USB controllers found"
}

# Monitor storage for changes
monitor_storage() {
    log "Starting storage monitoring..."

    if [ ! -d "$MOUNT_POINT" ]; then
        error "Storage not mounted. Run 'enable' first."
        return 1
    fi

    # Monitor for file changes
    inotifywait -m -r -e create,moved_to,modify "$MOUNT_POINT" --format '%w%f %e' 2>/dev/null |
    while read -r file event; do
        # Only process image files
        if [[ "$file" =~ \.(jpg|jpeg|png|tiff|raw|dng|cr2|nef|orf|arw|JPG|JPEG|PNG|TIFF|RAW|DNG|CR2|NEF|ORF|ARW)$ ]]; then
            log "New photo detected: $file (event: $event)"

            # Notify main camera bridge service
            if systemctl is-active --quiet camera-bridge; then
                # Signal the main service about new files
                pkill -USR1 -f camera-bridge-service.sh 2>/dev/null || true
            fi
        fi
    done
}

# Show help
show_help() {
    echo "USB Gadget Mode Manager for Pi Zero 2 W"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup [size]      Set up USB gadget (size in MB, default: 2048)"
    echo "  enable            Enable USB gadget mode"
    echo "  disable           Disable USB gadget mode"
    echo "  cleanup           Remove USB gadget configuration"
    echo "  mount             Mount storage for local access"
    echo "  unmount           Unmount storage"
    echo "  status            Show gadget status"
    echo "  monitor           Monitor storage for file changes"
    echo "  reset             Complete reset (cleanup and setup)"
    echo "  help              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 setup 4096     # Create 4GB storage"
    echo "  $0 enable         # Enable USB gadget mode"
    echo "  $0 status         # Check current status"
    echo "  $0 monitor        # Watch for new files"
    echo ""
    echo "Files:"
    echo "  Storage: $STORAGE_FILE"
    echo "  Mount: $MOUNT_POINT"
    echo "  Config: $CONFIG_FILE"
    echo "  Log: $LOG_FILE"
}

# Main function
main() {
    check_root
    check_pi_zero
    load_config

    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"

    case "${1:-help}" in
        "setup")
            check_kernel_modules
            create_storage_file "$2"
            setup_usb_gadget
            log "USB gadget setup completed. Run '$0 enable' to activate."
            ;;
        "enable")
            if [ ! -d "$GADGET_DIR" ]; then
                error "USB gadget not configured. Run '$0 setup' first."
                exit 1
            fi
            enable_usb_gadget
            mount_storage
            log "USB gadget enabled and ready for camera connection"
            ;;
        "disable")
            disable_usb_gadget
            unmount_storage
            log "USB gadget disabled"
            ;;
        "cleanup")
            unmount_storage
            cleanup_usb_gadget
            log "USB gadget configuration removed"
            ;;
        "mount")
            mount_storage
            ;;
        "unmount")
            unmount_storage
            ;;
        "status")
            get_status
            ;;
        "monitor")
            monitor_storage
            ;;
        "reset")
            cleanup_usb_gadget
            sleep 1
            check_kernel_modules
            create_storage_file "$2"
            setup_usb_gadget
            enable_usb_gadget
            mount_storage
            log "USB gadget reset completed"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"