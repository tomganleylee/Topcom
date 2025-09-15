# Camera Bridge Pi Zero 2W - PowerShell SD Card Preparation Script
# This script automates the SD card preparation process for Windows users

param(
    [Parameter(Mandatory=$false)]
    [string]$DriveLetter,

    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
)

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    CAMERA BRIDGE SETUP                      ║" -ForegroundColor Green
Write-Host "║                PowerShell SD Card Preparation               ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║  Automated SD Card Setup for Pi Zero 2W                     ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Function to log messages with timestamp
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Get available drives
function Get-RemovableDrives {
    Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 } | Select-Object DeviceID, Size, FreeSpace, VolumeName
}

# Main setup process
try {
    Write-Log "Starting Camera Bridge SD card preparation" "INFO"

    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Log "Script is not running as Administrator. Some operations may fail." "WARNING"
        Write-Log "Consider running PowerShell as Administrator for best results." "WARNING"
        Write-Host ""
    }

    # Verify project files exist
    if (-not (Test-Path "$ProjectPath\scripts")) {
        Write-Log "Camera Bridge project files not found at: $ProjectPath" "ERROR"
        Write-Log "Please ensure you've extracted the Camera Bridge ZIP file completely." "ERROR"
        exit 1
    }

    Write-Log "Camera Bridge files found at: $ProjectPath" "SUCCESS"

    # Get SD card drive if not specified
    if (-not $DriveLetter) {
        Write-Host ""
        Write-Log "Detecting removable drives..." "INFO"
        $drives = Get-RemovableDrives

        if ($drives.Count -eq 0) {
            Write-Log "No removable drives detected. Please insert your SD card." "ERROR"
            exit 1
        }

        Write-Host ""
        Write-Host "Available removable drives:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $drives.Count; $i++) {
            $drive = $drives[$i]
            $sizeGB = [math]::Round($drive.Size / 1GB, 2)
            $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            Write-Host "  [$i] $($drive.DeviceID) - $($drive.VolumeName) ($sizeGB GB, $freeGB GB free)"
        }

        Write-Host ""
        $selection = Read-Host "Select drive number (0-$($drives.Count-1))"

        if ($selection -lt 0 -or $selection -ge $drives.Count) {
            Write-Log "Invalid selection" "ERROR"
            exit 1
        }

        $DriveLetter = $drives[$selection].DeviceID.TrimEnd(':')
    }

    $drivePath = "${DriveLetter}:\"

    if (-not (Test-Path $drivePath)) {
        Write-Log "Drive $drivePath not accessible" "ERROR"
        exit 1
    }

    Write-Log "Using drive: $drivePath" "INFO"

    # Create camera-bridge directory
    $cameraBridgePath = Join-Path $drivePath "camera-bridge"
    Write-Log "Creating camera-bridge directory..." "INFO"

    if (-not (Test-Path $cameraBridgePath)) {
        New-Item -ItemType Directory -Path $cameraBridgePath -Force | Out-Null
    }

    # Copy Camera Bridge files
    Write-Log "Copying Camera Bridge files (this may take several minutes)..." "INFO"

    $sourceFiles = Get-ChildItem -Path $ProjectPath -Recurse
    $totalFiles = $sourceFiles.Count
    $copiedFiles = 0

    foreach ($file in $sourceFiles) {
        $relativePath = $file.FullName.Substring($ProjectPath.Length)
        $destPath = Join-Path $cameraBridgePath $relativePath

        if ($file.PSIsContainer) {
            if (-not (Test-Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath -Force | Out-Null
            }
        } else {
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $file.FullName -Destination $destPath -Force
        }

        $copiedFiles++
        if ($copiedFiles % 50 -eq 0) {
            $percent = [math]::Round(($copiedFiles / $totalFiles) * 100, 1)
            Write-Log "Progress: $percent% ($copiedFiles/$totalFiles files)" "INFO"
        }
    }

    Write-Log "File copy completed successfully" "SUCCESS"

    # Create auto-installation trigger
    Write-Log "Creating auto-installation trigger..." "INFO"
    $triggerFile = Join-Path $drivePath "auto-install-camera-bridge.txt"
    "Auto-install Camera Bridge on first boot" | Out-File -FilePath $triggerFile -Encoding ASCII

    # Create firstrun.sh script
    Write-Log "Creating first-run script..." "INFO"
    $firstRunScript = Join-Path $drivePath "firstrun.sh"

    $firstRunContent = @"
#!/bin/bash
# Camera Bridge Auto-Installation Trigger
if [ -f /boot/auto-install-camera-bridge.txt ]; then
    echo "Starting Camera Bridge auto-installation..." > /var/log/camera-bridge-setup.log
    chmod +x /boot/camera-bridge/raspberry-pi/pi-zero-2w/scripts/auto-install-first-boot.sh
    /boot/camera-bridge/raspberry-pi/pi-zero-2w/scripts/auto-install-first-boot.sh
fi
"@

    $firstRunContent | Out-File -FilePath $firstRunScript -Encoding ASCII

    # Create setup completion marker
    $setupMarker = Join-Path $drivePath "camera-bridge-setup-complete.txt"
    "SD card prepared by Camera Bridge PowerShell script on $(Get-Date)" | Out-File -FilePath $setupMarker -Encoding ASCII

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    SETUP COMPLETE!                          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    Write-Log "SD card preparation completed successfully!" "SUCCESS"
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Safely eject the SD card from Windows" -ForegroundColor White
    Write-Host "2. Insert SD card into Pi Zero 2W" -ForegroundColor White
    Write-Host "3. Connect power (USB-C cable)" -ForegroundColor White
    Write-Host "4. Wait 10-15 minutes for automatic installation" -ForegroundColor White
    Write-Host "5. Connect to WiFi: 'CameraBridge-Setup' (password: setup123)" -ForegroundColor White
    Write-Host "6. Open browser: http://192.168.4.1" -ForegroundColor White
    Write-Host ""
    Write-Host "WHAT HAPPENS AUTOMATICALLY:" -ForegroundColor Cyan
    Write-Host "• Pi boots and detects auto-installation trigger" -ForegroundColor White
    Write-Host "• Camera Bridge software installs automatically" -ForegroundColor White
    Write-Host "• WiFi hotspot 'CameraBridge-Setup' is created" -ForegroundColor White
    Write-Host "• Web interface becomes available at http://192.168.4.1" -ForegroundColor White
    Write-Host "• System optimizes for USB gadget mode operation" -ForegroundColor White
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "• If no hotspot appears after 20 minutes, check power and SD card" -ForegroundColor White
    Write-Host "• Red LED solid = Normal boot process" -ForegroundColor White
    Write-Host "• Green LED activity = SD card being accessed" -ForegroundColor White
    Write-Host "• For support, check the logs at /var/log/camera-bridge-setup.log" -ForegroundColor White
    Write-Host ""

} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")