#!/bin/bash

# Dropbox Folder Cleanup Script
# Moves files from weird subdirectories to the root Camera-Photos folder
# Handles special characters like fullwidth period "．" and others

LOG_FILE="/var/log/camera-bridge/cleanup.log"
DROPBOX_ROOT="dropbox:Camera-Photos"

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "Starting Dropbox folder cleanup..."

# List of problematic subdirectory patterns to clean up
# These are directories that shouldn't exist and contain files that belong in root
PROBLEM_FOLDERS=(
    "．/"           # Fullwidth period
    "./"            # Regular dot (if it appears as a folder)
    "．"            # Just the fullwidth period
)

# Function to move files from a subdirectory to root
cleanup_folder() {
    local folder="$1"
    local folder_path="$DROPBOX_ROOT/$folder"

    log_message "Checking folder: $folder_path"

    # List files in this folder
    local files=$(sudo -u camerabridge rclone lsf "$folder_path" 2>/dev/null)

    if [ -z "$files" ]; then
        log_message "  No files found in $folder"
        return 0
    fi

    local count=0

    # Move each file to root
    while IFS= read -r file; do
        # Skip if it's a directory
        if [[ "$file" == */ ]]; then
            log_message "  Skipping directory: $file"
            continue
        fi

        local source="$folder_path$file"
        local dest="$DROPBOX_ROOT/$file"

        log_message "  Moving: $file"

        # Check if file already exists at destination
        if sudo -u camerabridge rclone lsf "$dest" 2>/dev/null | grep -q "^$(basename "$file")$"; then
            log_message "  WARNING: File already exists at destination, skipping: $file"
            continue
        fi

        # Move the file
        if sudo -u camerabridge rclone moveto "$source" "$dest" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "  SUCCESS: Moved $file"
            ((count++))
        else
            log_message "  ERROR: Failed to move $file"
        fi
    done <<< "$files"

    if [ $count -gt 0 ]; then
        log_message "Moved $count files from $folder"
    fi

    # Try to remove the empty folder (will fail if not empty, which is fine)
    sudo -u camerabridge rclone rmdir "$folder_path" 2>/dev/null && \
        log_message "Removed empty folder: $folder" || \
        log_message "Folder not empty or already gone: $folder"

    return 0
}

# Clean up each problematic folder
for folder in "${PROBLEM_FOLDERS[@]}"; do
    cleanup_folder "$folder"
done

# Also check for any other single-character folders that might be problematic
log_message "Checking for other single-character folders..."
other_folders=$(sudo -u camerabridge rclone lsf "$DROPBOX_ROOT" --dirs-only 2>/dev/null | grep -E '^./$')

if [ -n "$other_folders" ]; then
    while IFS= read -r folder; do
        # Skip known good folders
        if [[ "$folder" == "Old/" ]]; then
            continue
        fi

        log_message "Found suspicious single-char folder: $folder"
        cleanup_folder "$folder"
    done <<< "$other_folders"
fi

log_message "Cleanup complete!"
