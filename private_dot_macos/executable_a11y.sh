#!/usr/bin/env bash

# Accessibility > Zoom
#
# com.apple.universalaccess is TCC-protected: `defaults write` fails with
# "Could not write domain com.apple.universalaccess; exiting" for ANY key —
# verified with a throwaway probe key, so it isn't about these keys specifically.
# Granting the terminal Full Disk Access (System Settings > Privacy & Security >
# Full Disk Access) lifts the restriction and makes this script work.
#
# The key names themselves are correct for this build (26.6), confirmed by
# searching the dyld shared cache. So the writes are attempted, and the script
# reports what is left to do by hand if the domain is locked.

zoom_settings_applied=1

zoom_write() {
	if ! defaults write com.apple.universalaccess "$@" 2>/dev/null; then
		zoom_settings_applied=0
	fi
}

# Use keyboard shortcuts to zoom: OFF
zoom_write closeViewHotkeysEnabled -bool false

# Use trackpad gesture to zoom: OFF
zoom_write closeViewTrackpadGestureZoomEnabled -bool false

# Use scroll gesture with modifier keys to zoom: ON
zoom_write closeViewScrollWheelToggle -bool true

# Modifier key for the scroll gesture: Control.
# The value is an NSEvent modifier mask — control is 1 << 18.
zoom_write closeViewScrollWheelModifiersInt -int 262144

# Zoom style: Full Screen (1 would be picture-in-picture)
zoom_write closeViewZoomMode -int 0

echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""

if [ "${zoom_settings_applied}" -eq 1 ]; then
	echo "✓ All zoom settings were written — nothing manual left in this pane."
else
	echo "⚠️  com.apple.universalaccess is locked (TCC): the zoom settings could not"
	echo "   be written. Either grant this terminal Full Disk Access and re-run,"
	echo "   or set them in System Settings > Accessibility > Zoom:"
	echo ""
	echo "* Use keyboard shortcuts to zoom: OFF"
	echo "* Use trackpad gesture to zoom: OFF"
	echo "* Use scroll gesture with modifier keys to zoom: ON"
	echo "* Modifier key for scroll gesture: Control"
	echo "* Zoom style: Full Screen"
fi

echo ""
echo " Note: zoom settings are read at login; log out and back in if the"
echo " scroll-to-zoom gesture doesn't respond immediately."
echo ""
echo "📋 ============================================================================"
