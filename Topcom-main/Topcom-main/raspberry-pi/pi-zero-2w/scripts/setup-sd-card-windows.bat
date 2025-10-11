@echo off
echo ============================================
echo Camera Bridge Pi Zero 2W - SD Card Setup
echo ============================================
echo.
echo This script will help you prepare an SD card for
echo fully automatic Camera Bridge installation.
echo.
echo REQUIREMENTS:
echo - Raspberry Pi Imager installed
echo - SD card (16GB+ recommended)
echo - Internet connection
echo.
echo PROCESS:
echo 1. Flash Raspberry Pi OS Lite to SD card
echo 2. Enable SSH and auto-installation
echo 3. Copy Camera Bridge files
echo.

pause

echo.
echo ============================================
echo STEP 1: Flash Raspberry Pi OS Lite
echo ============================================
echo.
echo 1. Open Raspberry Pi Imager
echo 2. Choose OS: "Raspberry Pi OS Lite (64-bit)"
echo 3. Choose Storage: Your SD card
echo 4. Click the GEAR icon for advanced options:
echo    - Enable SSH (use password authentication)
echo    - Set username: pi
echo    - Set password: (your choice)
echo    - Configure WiFi (optional - will use hotspot if not set)
echo 5. Click WRITE to flash the SD card
echo.
echo Press any key when flashing is complete...
pause

echo.
echo ============================================
echo STEP 2: Preparing Auto-Installation
echo ============================================
echo.

set /p drive_letter="Enter the SD card drive letter (e.g., E): "

if not exist "%drive_letter%:\" (
    echo Error: Drive %drive_letter%: not found!
    pause
    exit /b 1
)

echo.
echo Copying Camera Bridge files to SD card...

:: Create directory for Camera Bridge files
mkdir "%drive_letter%:\camera-bridge" 2>nul

:: Copy the installation files
echo Downloading latest Camera Bridge files...
echo.
echo NOTE: You need to manually download the Camera Bridge files from:
echo https://github.com/tomganleylee/Topcom/archive/refs/heads/main.zip
echo.
echo Extract the ZIP file and copy the contents to:
echo %drive_letter%:\camera-bridge\
echo.
echo The folder structure should look like:
echo %drive_letter%:\camera-bridge\scripts\
echo %drive_letter%:\camera-bridge\raspberry-pi\
echo %drive_letter%:\camera-bridge\web\
echo etc...
echo.

pause

:: Create auto-installation script
echo Creating auto-installation script...

echo #!/bin/bash > "%drive_letter%:\install-camera-bridge.sh"
echo # Camera Bridge Auto-Installation Script >> "%drive_letter%:\install-camera-bridge.sh"
echo echo "Starting Camera Bridge auto-installation..." >> "%drive_letter%:\install-camera-bridge.sh"
echo cd /boot/camera-bridge >> "%drive_letter%:\install-camera-bridge.sh"
echo sudo ./raspberry-pi/pi-zero-2w/scripts/install-pi-zero-2w.sh >> "%drive_letter%:\install-camera-bridge.sh"
echo sudo touch /opt/camera-bridge-auto-installed >> "%drive_letter%:\install-camera-bridge.sh"
echo echo "Camera Bridge installation complete! Rebooting..." >> "%drive_letter%:\install-camera-bridge.sh"
echo sudo reboot >> "%drive_letter%:\install-camera-bridge.sh"

:: Create auto-run service
echo Creating auto-run configuration...

echo #!/bin/bash > "%drive_letter%:\setup-auto-install.sh"
echo # Run this script on first boot to set up auto-installation >> "%drive_letter%:\setup-auto-install.sh"
echo if [ ! -f /opt/camera-bridge-auto-installed ]; then >> "%drive_letter%:\setup-auto-install.sh"
echo   echo "Running Camera Bridge auto-installation..." >> "%drive_letter%:\setup-auto-install.sh"
echo   /boot/install-camera-bridge.sh ^>^> /var/log/camera-bridge-install.log 2^>^&1 >> "%drive_letter%:\setup-auto-install.sh"
echo fi >> "%drive_letter%:\setup-auto-install.sh"

:: Add to rc.local for auto-execution
echo # Camera Bridge Auto-Installation >> "%drive_letter%:\rc.local.addition"
echo /boot/setup-auto-install.sh ^& >> "%drive_letter%:\rc.local.addition"

echo.
echo ============================================
echo STEP 3: Final SD Card Configuration
echo ============================================
echo.
echo The SD card is almost ready!
echo.
echo MANUAL STEPS NEEDED:
echo.
echo 1. Copy Camera Bridge files (if not done already):
echo    - Download: https://github.com/tomganleylee/Topcom/archive/refs/heads/main.zip
echo    - Extract to: %drive_letter%:\camera-bridge\
echo.
echo 2. Safely eject the SD card from Windows
echo.
echo 3. Insert SD card into Pi Zero 2W
echo.
echo 4. Connect Pi Zero 2W to power (USB-C)
echo.
echo 5. Wait 5-10 minutes for installation
echo.
echo 6. Look for WiFi network: "CameraBridge-Setup"
echo    Password: setup123
echo.
echo 7. Connect to WiFi and go to: http://192.168.4.1
echo.
echo ============================================
echo Setup Complete!
echo ============================================
echo.
echo Your Pi Zero 2W will automatically:
echo - Install Camera Bridge software
echo - Create a setup WiFi hotspot
echo - Provide a web interface for configuration
echo.
echo No display or keyboard needed!
echo.

pause