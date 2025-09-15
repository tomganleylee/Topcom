@echo off
title Camera Bridge Pi Zero 2W - Automated Setup
color 0A

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    CAMERA BRIDGE SETUP                      ║
echo  ║                   Pi Zero 2W Edition                        ║
echo  ║                                                              ║
echo  ║  Fully Automated - No Display or Keyboard Required!         ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\..\.."

echo [INFO] Starting Camera Bridge setup for Windows...
echo [INFO] Script location: %SCRIPT_DIR%
echo.

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] This script may need administrator privileges for some operations.
    echo [INFO] If you encounter permission errors, right-click and "Run as administrator"
    echo.
    pause
)

:: Check for required tools
echo [STEP 1] Checking requirements...
echo.

:: Check if Raspberry Pi Imager is installed
where rpi-imager >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Raspberry Pi Imager not found!
    echo.
    echo Please download and install Raspberry Pi Imager:
    echo https://www.raspberrypi.com/software/
    echo.
    echo After installation, restart this script.
    pause
    exit /b 1
) else (
    echo [OK] Raspberry Pi Imager found
)

:: Check if project files exist
if not exist "%PROJECT_ROOT%\scripts" (
    echo [ERROR] Camera Bridge project files not found!
    echo.
    echo Expected location: %PROJECT_ROOT%
    echo.
    echo Please ensure you've extracted the Camera Bridge ZIP file completely.
    pause
    exit /b 1
) else (
    echo [OK] Camera Bridge files found
)

echo.
echo [STEP 2] SD Card Setup Instructions
echo.
echo This setup process will create a FULLY AUTOMATED Pi Zero 2W that:
echo   • Requires NO display or keyboard
echo   • Automatically installs Camera Bridge
echo   • Creates WiFi hotspot for configuration
echo   • Provides web interface at http://192.168.4.1
echo.

pause

echo.
echo ┌─────────────────────────────────────────────────────────────┐
echo │                  SD CARD FLASHING STEPS                    │
echo └─────────────────────────────────────────────────────────────┘
echo.
echo 1. Insert your SD card (16GB+ recommended)
echo 2. Open Raspberry Pi Imager (we'll launch it for you)
echo 3. Follow the configuration below:
echo.
echo    OS SELECTION:
echo    • Choose OS → Raspberry Pi OS (other) → Raspberry Pi OS Lite (64-bit)
echo.
echo    GEAR ICON (⚙️) SETTINGS:
echo    • ✓ Enable SSH (use password authentication)
echo    • Username: pi
echo    • Password: (your choice - remember it!)
echo    • Configure WiFi: (optional - leave blank for hotspot mode)
echo    • Set locale settings: (your timezone)
echo.
echo 4. Click WRITE and wait for completion
echo 5. DO NOT EJECT YET - return here after flashing
echo.

echo Starting Raspberry Pi Imager...
start rpi-imager
echo.
echo [WAITING] Complete the SD card flashing, then press any key...
pause

echo.
echo [STEP 3] SD Card Post-Processing
echo.

set /p drive_letter="Enter your SD card drive letter (e.g., E, F, G): "

if not exist "%drive_letter%:\" (
    echo [ERROR] Drive %drive_letter%: not accessible!
    echo.
    echo Make sure:
    echo • SD card is still inserted
    echo • Drive letter is correct
    echo • Windows has finished mounting the drive
    echo.
    pause
    exit /b 1
)

echo.
echo [INFO] Preparing SD card at %drive_letter%:\ for auto-installation...

:: Create camera-bridge directory on SD card
echo [ACTION] Creating camera-bridge directory...
mkdir "%drive_letter%:\camera-bridge" 2>nul

:: Copy all project files to SD card
echo [ACTION] Copying Camera Bridge files (this may take a moment)...

xcopy "%PROJECT_ROOT%\*" "%drive_letter%:\camera-bridge\" /E /I /H /Y >nul
if %errorLevel% neq 0 (
    echo [ERROR] Failed to copy files to SD card!
    echo.
    echo Please manually copy the contents of:
    echo %PROJECT_ROOT%
    echo.
    echo To:
    echo %drive_letter%:\camera-bridge\
    echo.
    pause
    exit /b 1
)

echo [OK] Files copied successfully

:: Create auto-installation trigger
echo [ACTION] Creating auto-installation trigger...
echo Auto-install Camera Bridge > "%drive_letter%:\auto-install-camera-bridge.txt"

:: Create firstrun.sh for Raspberry Pi OS
echo [ACTION] Creating first-run script...
(
echo #!/bin/bash
echo # Camera Bridge Auto-Installation Trigger
echo if [ -f /boot/auto-install-camera-bridge.txt ]; then
echo     echo "Starting Camera Bridge auto-installation..." ^> /var/log/camera-bridge-setup.log
echo     chmod +x /boot/camera-bridge/raspberry-pi/pi-zero-2w/scripts/auto-install-first-boot.sh
echo     /boot/camera-bridge/raspberry-pi/pi-zero-2w/scripts/auto-install-first-boot.sh
echo fi
) > "%drive_letter%:\firstrun.sh"

:: Create userconf.txt for auto-user setup (if SSH configured)
echo [ACTION] Configuring automatic setup...

echo.
echo ┌─────────────────────────────────────────────────────────────┐
echo │                    SETUP COMPLETE!                         │
echo └─────────────────────────────────────────────────────────────┘
echo.
echo Your SD card is now ready for FULLY AUTOMATIC installation!
echo.
echo NEXT STEPS:
echo.
echo 1. Safely eject the SD card from Windows
echo 2. Insert SD card into Pi Zero 2W
echo 3. Connect power (USB-C cable)
echo 4. Wait 10-15 minutes for automatic installation
echo 5. Look for WiFi network: "CameraBridge-Setup"
echo 6. Connect with password: "setup123"
echo 7. Open browser: http://192.168.4.1
echo.
echo WHAT HAPPENS AUTOMATICALLY:
echo • Pi boots and runs auto-installation
echo • Camera Bridge software installs
echo • WiFi hotspot creates: CameraBridge-Setup
echo • Web interface becomes available
echo • System optimizes for USB gadget mode
echo.
echo TROUBLESHOOTING:
echo • Red LED solid = Pi booting normally
echo • Green LED flashing = SD card activity
echo • No hotspot after 15 min = Check power/SD card
echo.
echo STATUS MONITORING:
echo • Main interface: http://192.168.4.1
echo • Status page: http://192.168.4.1/status.php
echo.

echo [SUCCESS] SD card preparation complete!
echo.
echo Your Pi Zero 2W Camera Bridge will be ready in 10-15 minutes after power-on.
echo No display, keyboard, or technical knowledge required!
echo.

pause

echo.
echo [OPTIONAL] Additional Setup Tools
echo.
echo Would you like to:
echo.
echo 1. Open the Windows Setup Guide (detailed instructions)
echo 2. View troubleshooting information
echo 3. Exit
echo.

set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" (
    start notepad "%SCRIPT_DIR%WINDOWS-SETUP-GUIDE.md"
) else if "%choice%"=="2" (
    echo.
    echo TROUBLESHOOTING TIPS:
    echo.
    echo If the hotspot doesn't appear:
    echo • Wait longer (up to 20 minutes for first boot)
    echo • Check power cable (must support data)
    echo • Verify SD card integrity
    echo • Try different power adapter
    echo.
    echo If web interface doesn't load:
    echo • Ensure connected to CameraBridge-Setup WiFi
    echo • Try http://192.168.4.1 (not https)
    echo • Clear browser cache
    echo • Try different browser
    echo.
    echo For USB gadget mode:
    echo • Use USB-C data cable (not power-only)
    echo • Check camera USB storage compatibility
    echo • Try different USB port on camera
    echo.
    pause
)

echo.
echo Thank you for using Camera Bridge!
echo Visit: https://github.com/tomganleylee/Topcom for updates
echo.
pause