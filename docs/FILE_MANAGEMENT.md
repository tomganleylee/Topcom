# Camera Bridge - File Management System

## Overview
Complete file browsing and management system with both terminal and GUI interfaces for managing camera photos and copying to USB drives.

## Features

### 📁 Terminal File Browser
- **Date-based filtering**: Today, Yesterday, Last 7/30 days, This/Last Month, Custom range
- **Multi-file selection**: Select multiple files using checkboxes (SPACE to select)
- **Batch operations**: Copy to USB, View list, Delete files
- **Progress tracking**: Real-time copy/delete progress with percentage
- **Safe operations**: Double confirmation for destructive actions

### 🖼️ GUI File Browser
- **Thunar file manager**: Lightweight GUI with drag-and-drop support
- **Auto-installation**: Automatically installs X11 and Thunar if needed (~25MB)
- **Visual preview**: See photo thumbnails and file details
- **Easy USB copy**: Drag files directly to USB drives
- **Fallback**: Automatically uses terminal browser if GUI unavailable

### 💾 Quick USB Copy
- **One-click operations**: Today's photos, Last 7 days, This month, All photos
- **Fast workflow**: Minimal clicks from selection to copy
- **Auto-dated folders**: Creates timestamped folders on USB (CameraBridge-YYYYMMDD_HHMMSS)
- **Verification**: Confirms successful copy with file count check

### 🔍 File Statistics
- **Storage overview**: Total files, size, disk usage
- **Date breakdown**: Files by Today, Yesterday, Last 7 days, Older
- **Date range**: Oldest and newest file dates
- **Disk health**: Total/used/free space with percentages

### 🗑️ File Cleanup
- **Age-based cleanup**: Delete files older than 30/60/90 days
- **Archive & cleanup**: Copy to USB then delete from local storage
- **Custom cleanup**: Use terminal browser for selective deletion
- **Safety checks**: Double confirmation before deletion

### 💿 USB Management
- **Auto-detection**: Automatically finds and lists USB drives
- **Auto-mounting**: Mounts USB drives automatically when needed
- **Device information**: Shows model, size, filesystem, free space
- **Safe ejection**: Guides for proper USB unmounting

## Usage

### Access File Management
1. Run terminal UI: `sudo /opt/camera-bridge/scripts/terminal-ui.sh`
2. Select: `7. File Management`

### Terminal File Browser Workflow
1. Select: `1. 📁 Terminal File Browser`
2. Choose date filter (e.g., "Last 7 Days")
3. Use SPACE to select files, ENTER to confirm
4. Choose action: Copy to USB, View list, or Delete
5. If copying:
   - Insert USB drive
   - Select USB device from list
   - Confirm copy operation
   - Wait for progress to complete

### GUI File Browser Workflow
1. Select: `2. 🖼️ GUI File Browser`
2. If not installed, choose to install Thunar
3. Wait for GUI to launch
4. Browse photos visually
5. Drag files to USB drive in sidebar

### Quick USB Copy Workflow
1. Insert USB drive first
2. Select: `3. 💾 Quick USB Copy`
3. Choose time range (e.g., "Today's Photos")
4. Confirm file count and size
5. Select USB device
6. Files copied automatically

## File Locations

**Photo Storage**: `/srv/samba/camera-share`
**USB Mount Points**: `/media/usb_*`
**Temp Selection**: `/tmp/camera-bridge-selected-files`

## Configuration

```bash
PHOTO_DIR="/srv/samba/camera-share"        # Photo storage location
USB_MOUNT_BASE="/media"                    # USB mount point base
MAX_FILES_PER_PAGE=100                     # Max files shown per page
```

## Tips & Tricks

### Efficient Workflows

**Daily USB Backup**:
1. File Management → Quick USB Copy → Today's Photos
2. Takes ~30 seconds for typical daily volume

**Weekly Archive**:
1. File Management → Terminal Browser → Last 7 Days
2. Select all files
3. Copy to USB
4. Verify count matches
5. Optionally delete from local storage

**Space Management**:
1. File Management → File Statistics (check disk usage)
2. File Management → File Cleanup → Delete files older than 30 days
3. Or: Archive to USB then delete

### Keyboard Shortcuts (Terminal Browser)

- **SPACE**: Select/deselect file in checklist
- **ENTER**: Confirm selection
- **ESC**: Cancel operation
- **Arrow keys**: Navigate menu items
- **Number keys**: Quick menu selection

### USB Tips

- **Always eject properly**: Use "USB Management → Eject USB Safely"
- **Check free space**: USB free space shown before copy
- **Dated folders**: Files copied to timestamped folders for organization
- **Multiple USBs**: Can have multiple USB drives connected, choose which to use

### Performance

- **Large directories**: Only first 100 files shown per page (configurable)
- **Fast scanning**: Date filters optimize file searches
- **Progress feedback**: Real-time progress for all operations
- **Efficient copying**: Uses standard cp with progress tracking

## Troubleshooting

### USB Not Detected
- Wait 5-10 seconds after inserting USB
- Try "USB Management → Detect USB Devices" to refresh
- Check USB is not damaged: `lsblk` in shell
- Some USBs need manual mounting

### GUI Won't Launch
- Check if X11 is running: `echo $DISPLAY`
- Install Thunar: `sudo apt install thunar xorg`
- Use terminal browser as fallback

### Files Not Showing
- Check date filter selection
- Verify files exist: File Management → File Statistics
- Try "All Files" filter
- Check permissions on photo directory

### Copy Failed
- Check USB has enough free space
- Verify USB is not write-protected
- Check USB filesystem is supported (FAT32, ext4, NTFS)
- Try different USB drive

### Slow Performance
- Reduce MAX_FILES_PER_PAGE in config
- Use more specific date filters
- Consider archiving old files to USB
- Check disk is not full

## Advanced Usage

### Shell Access
File Management → Open in Shell
- Direct command-line access to photo directory
- Useful for advanced operations
- Type `exit` to return to menu

### Custom Date Ranges
Currently uses preset ranges. For custom dates:
1. Use "Open in Shell"
2. Use find commands: `find . -type f -newermt "2025-01-01" ! -newermt "2025-02-01"`

### Batch Processing
For very large operations:
1. Use terminal browser to create selection
2. Selection saved to: `/tmp/camera-bridge-selected-files`
3. Process with custom scripts if needed

## Safety Features

- **Double confirmation**: Destructive operations require two confirmations
- **Progress feedback**: Always shows what's happening
- **Verification**: Copy operations verify file counts
- **No overwrite prompts**: Files copied to unique timestamped folders
- **Automatic backups**: wpa_supplicant config backed up before WiFi changes

## Integration

The file management system integrates with:
- **Camera Bridge Service**: Monitors /srv/samba/camera-share
- **Dropbox Sync**: Synced files also accessible via file browser
- **Samba Share**: Same files accessible via network (\\\\IP\\camera-share)
- **Terminal UI**: Seamless integration with other system functions

## Future Enhancements

Planned features:
- Calendar-based custom date picker
- File preview thumbnails in terminal
- Advanced sorting (size, type, name)
- Network copy (to other machines)
- Automatic cleanup schedules
- Email notifications for low space
- Cloud upload integration

## Support

For issues or questions:
- Check troubleshooting section above
- Review system logs: View Logs menu
- Check disk space: File Statistics
- GitHub: https://github.com/anthropics/claude-code/issues