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
add_app_to_dock "/Applications/Microsoft Edge.app"
add_app_to_dock "/Applications/Microsoft Outlook.app"
add_app_to_dock "/Applications/Slack.app"
add_app_to_dock "/Applications/Microsoft Teams.app"
add_app_to_dock "/Applications/YouTube Music.app"
add_app_to_dock "/Applications/Visual Studio Code.app"
add_app_to_dock "/Applications/Joplin.app"
add_app_to_dock "/Applications/Miro.app"
add_app_to_dock "/Applications/Figma.app"
add_app_to_dock "/Applications/Cisco/Cisco Secure Client.app"

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

# Restart Dock to apply changes
echo ""
echo "Restarting Dock..."
killall Dock

echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""
echo "⚠️  The following settings cannot be automated and must be configured manually in System Settings > Desktop & Dock:"
echo ""
echo "### �️ Desktop & Stage Manager"
echo ""
echo "* Show Items: Uncheck 'On Desktop' and 'In Stage Manager'"
echo "* Click wallpaper to reveal desktop: Only in Stage Manager"
echo "* Stage Manager: OFF"
echo "* Show recent apps in Stage Manager: OFF"
echo "* Show windows from an application: All at Once"
echo ""
echo "### 🧩 Widgets"
echo ""
echo "* Show Widgets: Uncheck 'On Desktop' and 'In Stage Manager'"
echo "* Widget style: Automatic"
echo "* Use iPhone widgets: OFF"
echo ""
echo "### 🌐 Default web browser"
echo ""
echo "* Microsoft Edge.app"
echo ""
echo "### 🪟 Windows"
echo ""
echo "* Prefer tabs when opening documents: Always"
echo "* Ask to keep changes when closing documents: ON"
echo "* Close windows when quitting an application: ON"
echo "* Drag windows to screen edges to tile: Disabled (requires 'Displays have separate Spaces')"
echo "* Drag windows to menu bar to full screen: Disabled"
echo "* Hold ⌥ key while dragging windows to tile: Disabled"
echo "* Tiled windows have margins: Disabled"
echo ""
echo "### 🎛️ Mission Control"
echo ""
echo "* Automatically rearrange Spaces based on most recent use: OFF"
echo "* When switching to an application, switch to a Space with open windows for the application: ON"
echo "* Group windows by application: ON"
echo "* Displays have separate Spaces: ON"
echo "* Drag windows to top of screen to enter Mission Control: ON"
echo ""
echo "### ⌨️ Shortcuts"
echo ""
echo "* All shortcuts are not set"
echo ""
echo "### 🔥 Hot Corners"
echo ""
echo "* All corners are unset"
echo ""
echo " Note: Some WindowManager changes require logging out and back in to take effect."
echo ""
echo "🔗 To access: System Settings > Desktop & Dock"
echo ""
echo "📋 ============================================================================"


