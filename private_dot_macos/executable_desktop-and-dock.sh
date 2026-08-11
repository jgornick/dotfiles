#!/usr/bin/env bash

# Dock Configuration
# Hide recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Set Dock icon size to 48 pixels
defaults write com.apple.dock tilesize -float 48.0

# Disable Dock magnification
defaults write com.apple.dock magnification -bool false

# Show full trash can icon when trash contains files
defaults write com.apple.dock trash-full -bool true


# Configure persistent apps in Dock
# Clear existing persistent apps
defaults write com.apple.dock persistent-apps -array

# Function to add an app to the Dock
add_app_to_dock() {
    local app_path="$1"

    if [ -e "$app_path" ]; then
        defaults write com.apple.dock persistent-apps -array-add "
            <dict>
                <key>tile-data</key>
                <dict>
                    <key>file-data</key>
                    <dict>
                        <key>_CFURLString</key>
                        <string>$app_path</string>
                        <key>_CFURLStringType</key>
                        <integer>0</integer>
                    </dict>
                </dict>
            </dict>
        "
        echo "✓ Added: $(basename "$app_path")"
    else
        echo "✗ Not found: $app_path"
    fi
}

# Add your desired applications here
# Customize this list with your preferred apps

add_app_to_dock "/Applications/Ghostty.app"
add_app_to_dock "/Applications/Google Chrome.app"
add_app_to_dock "/Applications/Microsoft Edge.app"
add_app_to_dock "/Applications/Microsoft Outlook.app"
add_app_to_dock "/System/Applications/Messages.app"
add_app_to_dock "/Applications/Slack.app"
add_app_to_dock "/Applications/Microsoft Teams.app"
add_app_to_dock "/Applications/YouTube Music.app"
add_app_to_dock "/Applications/Visual Studio Code.app"
add_app_to_dock "/Applications/Joplin.app"
add_app_to_dock "/Applications/Miro.app"
add_app_to_dock "/Applications/Figma.app"

# Configure persistent folders in Dock
# Clear existing persistent folders
defaults write com.apple.dock persistent-others -array

# Function to add a folder to the Dock
add_folder_to_dock() {
    local folder_path="$1"
    local folder_name="$2"
    local arrangement="$3"
    local showas="$4"

    if [ -d "$folder_path" ]; then
        defaults write com.apple.dock persistent-others -array-add "
            <dict>
                <key>tile-data</key>
                <dict>
                    <key>arrangement</key>
                    <integer>$arrangement</integer>
                    <key>displayas</key>
                    <integer>1</integer>
                    <key>file-data</key>
                    <dict>
                        <key>_CFURLString</key>
                        <string>$folder_path</string>
                        <key>_CFURLStringType</key>
                        <integer>0</integer>
                    </dict>
                    <key>file-label</key>
                    <string>$folder_name</string>
                    <key>preferreditemsize</key>
                    <integer>-1</integer>
                    <key>showas</key>
                    <integer>$showas</integer>
                </dict>
                <key>tile-type</key>
                <string>directory-tile</string>
            </dict>
        "
        echo "✓ Added folder: $folder_name"
    else
        echo "✗ Folder not found: $folder_path"
    fi
}

# Add Applications folder to Dock (sort by kind, grid view)
add_folder_to_dock "/Applications" "Applications" 1 2

# Add Downloads folder to Dock (sort by name, fan view)
add_folder_to_dock "$HOME/Downloads" "Downloads" 2 1

# ==============================================================================
# DESKTOP & STAGE MANAGER
# ==============================================================================
#
# The com.apple.WindowManager keys below were verified against this macOS build
# (26.6) by searching the dyld shared cache. The frameworks that read them are
# not readable with `strings` on disk, so key names cannot be confirmed the
# usual way — anything that could not be confirmed is left in the manual list
# at the end of this script rather than written on a guess.

# Show Items: uncheck "On Desktop"
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true

# Show Widgets: uncheck "On Desktop" and "In Stage Manager"
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true

# Use iPhone widgets: OFF. The key name is confirmed in this build's shared
# cache; the domain is chronod (the widget daemon), evidenced by its
# hasMigratedRemoteWidgetsEnabledState marker. Picked up at next login.
defaults write com.apple.chronod remoteWidgetsEnabled -bool false

# Click wallpaper to reveal desktop: Only in Stage Manager
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# Stage Manager: OFF
defaults write com.apple.WindowManager GloballyEnabled -bool false

# ==============================================================================
# WINDOWS
# ==============================================================================

# Prefer tabs when opening documents: Always
defaults write NSGlobalDomain AppleWindowTabbingMode -string always

# Ask to keep changes when closing documents: ON
defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true

# Close windows when quitting an application: ON
# (the key is the inverse — "keeps windows" off means windows close on quit)
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false

# Drag windows to screen edges to tile: disabled
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false

# Drag windows to the menu bar to fill the screen: disabled
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false

# Hold ⌥ while dragging windows to tile: disabled
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false

# Tiled windows have margins: disabled
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# ==============================================================================
# MISSION CONTROL
# ==============================================================================

# When switching to an application, switch to a Space with open windows: ON
defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool true

# Group windows by application: ON
defaults write com.apple.dock expose-group-apps -bool true

# Displays have separate Spaces: ON (the key is the inverse)
defaults write com.apple.spaces spans-displays -bool false

# ==============================================================================
# HOT CORNERS
# ==============================================================================

# All four corners unset. 1 would be "disabled" in the UI sense; 0 is no action
# at all, which is what an unset corner actually stores.
for corner in tl tr bl br; do
	defaults write com.apple.dock "wvous-${corner}-corner" -int 0
	defaults write com.apple.dock "wvous-${corner}-modifier" -int 0
done

# ==============================================================================
# APPLY CHANGES
# ==============================================================================

echo ""
echo "Restarting Dock and WindowManager..."
killall Dock 2>/dev/null || true
# WindowManager reads its domain at launch; without this the Stage Manager and
# tiling changes wait until the next login.
killall WindowManager 2>/dev/null || true

echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""
echo "Everything else in Desktop & Dock is scripted above. These are what's left,"
echo "each for a specific reason:"
echo ""
echo "### 🖥️ Desktop & Stage Manager"
echo ""
echo "These three only matter if Stage Manager is ever turned ON (it is scripted"
echo "OFF above), so they can wait until then:"
echo ""
echo "* Show Items: uncheck 'In Stage Manager'"
echo "    No verifiable key — the Stage Manager counterpart to"
echo "    StandardHideDesktopIcons could not be confirmed in this build."
echo "* Show recent apps in Stage Manager: OFF"
echo "* Show windows from an application: All at Once"
echo "    Key exists (AppWindowGroupingBehavior) but its enum values could not"
echo "    be confirmed, and guessing would silently pick the wrong mode."
echo ""
echo "### 🧩 Widgets"
echo ""
echo "* Widget style: Automatic — no key found; this is the macOS default, so"
echo "  a fresh machine is already correct."
echo ""
echo "### 🌐 Default web browser"
echo ""
echo "* Microsoft Edge.app — macOS requires a click-through confirmation;"
echo "  no command-line path sets this reliably."
echo ""
echo "### 🎛️ Mission Control"
echo ""
echo "* Automatically rearrange Spaces based on most recent use: OFF"
echo "    The old 'mru-spaces' key no longer exists anywhere in the Dock binary"
echo "    on macOS 26, and no replacement was found."
echo "* Drag windows to top of screen to enter Mission Control: ON"
echo "    No key found in this build; ON is the macOS default, so a fresh"
echo "    machine is already correct."
echo ""
echo " Note: WindowManager and Dock are restarted above, so those changes apply"
echo " immediately. Spaces changes still need a log out and back in."
echo ""
echo "🔗 To access: System Settings > Desktop & Dock"
echo ""
echo "📋 ============================================================================"
