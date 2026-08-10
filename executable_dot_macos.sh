#!/usr/bin/env bash

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront. The settings scripts themselves
# run as the current user — `defaults write` is per-user, and running them as
# root would silently write to /var/root/Library/Preferences instead. Only the
# few commands that genuinely need root (e.g. `chflags` in finder.sh) call
# `sudo` inline; this pre-authorization just avoids a mid-run prompt.
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
            /usr/bin/env bash "$script"
        fi
    done
fi

# Several settings — notably scroll direction (com.apple.swipescrolldirection) —
# are read by WindowServer once at login and cached, so a plain `defaults write`
# appears to do nothing until the next logout. This forces a reload of the
# session's settings so the changes take effect immediately.
ACTIVATE_SETTINGS="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
if [ -x "${ACTIVATE_SETTINGS}" ]; then
    echo "→ Reloading session settings..."
    "${ACTIVATE_SETTINGS}" -u
fi

echo "✓ macOS settings applied successfully!"
echo "Note: A few changes (e.g. WindowManager) still require logging out for full effect."