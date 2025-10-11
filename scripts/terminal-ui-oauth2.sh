#!/bin/bash

# Terminal UI with OAuth2 Support
# This wrapper adds OAuth2 functionality to the terminal UI

# Source the original terminal UI
source /opt/camera-bridge/scripts/terminal-ui.sh

# Source OAuth2 functions (overrides configure_dropbox)
source /opt/camera-bridge/scripts/terminal-ui-oauth2-functions.sh

# Run the main menu
main_menu
