#!/usr/bin/env bash

# Disable Resume system-wide
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Add specified apps to launch at login
# Usage: Edit the APPS array below to include the full app names (as shown in Finder)
APPS=("Ghostty" "Ice" "Middle" "Monosnap" "Raycast" "Rectangle Pro" "Stats")

for APP in "${APPS[@]}"; do
	# Add app to login items using osascript
	osascript -e "tell application \"System Events\" to make login item at end with properties {name: \"$APP\", path: \"/Applications/$APP.app\", hidden:false}"
	# Comment: This will add $APP to login items if not already present
done

