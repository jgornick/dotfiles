#!/usr/bin/env bash

# Disable Resume system-wide
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Add specified apps to launch at login
# Usage: Edit the APPS array below to include the full app names (as shown in Finder)
APPS=(
	"Bartender 6"
	"BetterDisplay"
	"Claude Usage"
	"Ghostty"
	"Middle"
	"Monosnap"
	"Raycast"
	"Rectangle Pro"
	"Stats"
)

for APP in "${APPS[@]}"; do
	APP_PATH="/Applications/${APP}.app"

	if [ ! -d "${APP_PATH}" ]; then
		echo "✗ Not installed, skipping: ${APP}"
		continue
	fi

	# System Events happily creates duplicate entries, so only add what's missing.
	if [ "$(osascript -e "tell application \"System Events\" to exists login item \"${APP}\"" 2>/dev/null)" = "true" ]; then
		echo "• Already a login item: ${APP}"
		continue
	fi

	osascript -e "tell application \"System Events\" to make login item at end with properties {name: \"${APP}\", path: \"${APP_PATH}\", hidden:false}" >/dev/null
	echo "✓ Added login item: ${APP}"
done

