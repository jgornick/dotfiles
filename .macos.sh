#!/usr/bin/env bash

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MACOS_DIR="${SCRIPT_DIR}/.macos"

# Source all settings files in the .macos directory
echo "Applying macOS settings..."

# Run all .sh files in the .macos directory
if [ -d "${MACOS_DIR}" ]; then
    for script in "${MACOS_DIR}"/*.sh; do
        if [ -f "$script" ]; then
            echo "→ Running $(basename "$script")..."
            sudo /usr/bin/env bash "$script"
        fi
    done
fi

echo "✓ macOS settings applied successfully!"
echo "Note: Some changes may require logging out or restarting for full effect."