#!/usr/bin/env bash

# Menu bar clock: analog face.
# Choosing analog is the whole setting — macOS greys out the digital-only
# options (seconds, AM/PM, day of week, date) once IsAnalog is set, so the
# leftover ShowAMPM/ShowDayOfWeek/ShowDate keys are simply ignored. They are
# left in place deliberately so switching back to digital restores them.
defaults write com.apple.menuextra.clock IsAnalog -bool true

# Recent documents, applications, and servers: 10.
# NSRecentDocumentsLimit is confirmed in this build's shared cache (with its
# setRecentDocumentsLimit setter); apps read it at launch.
defaults write NSGlobalDomain NSRecentDocumentsLimit -int 10

# Automatically hide and show the menu bar: In Full Screen Only.
# Two keys, both verified against this build: _HIHideMenuBar false means "don't
# always hide", AppleMenuBarVisibleInFullscreen false means "do hide in full
# screen". Together they are the "In Full Screen Only" option.
defaults write NSGlobalDomain _HIHideMenuBar -bool false
defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool false

# The menu bar clock is drawn by ControlCenter, which reads this domain only at
# launch; without the restart the change appears on next login instead of now.
killall ControlCenter 2>/dev/null || true

echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""
echo "Control Center module visibility genuinely cannot be scripted on macOS 26."
echo "It is no longer stored as one key per module: com.apple.controlcenter now"
echo "keeps it in ControlCenterDisplayableChronoControlsProviderConfiguration, a"
echo "single opaque binary blob. Writing the old per-module integer keys does"
echo "nothing. Configure these in System Settings > Control Center:"
echo ""
echo "### ⚙️ Control Center Modules"
echo ""
echo "* Wi-Fi: Show in Menu Bar"
echo "* Bluetooth: Show in Menu Bar"
echo "* AirDrop: Don't Show in Menu Bar"
echo "* Focus: Show When Active"
echo "* Stage Manager: Don't Show in Menu Bar"
echo "* Screen Mirroring: Show When Active"
echo "* Display: Don't Show in Menu Bar"
echo "* Sound: Always Show in Menu Bar"
echo "* Now Playing: Don't Show in Menu Bar"
echo ""
echo "### 🔧 Other Modules"
echo ""
echo "* Accessibility Shortcuts"
echo "  * Show in Menu Bar: OFF"
echo "  * Show in Control Center: OFF"
echo ""
echo "* Battery"
echo "  * Show in Menu Bar: OFF"
echo "  * Show in Control Center: OFF"
echo "  * Show Percentage: OFF"
echo "  * Show Energy Mode: When Active"
echo ""
echo "* Music Recognition"
echo "  * Show in Menu Bar: OFF"
echo "  * Show in Control Center: OFF"
echo ""
echo "* Hearing"
echo "  * Show in Menu Bar: OFF"
echo "  * Show in Control Center: OFF"
echo ""
echo "* Fast User Switching"
echo "  * Show in Menu Bar: Don't Show"
echo "  * Show in Control Center: OFF"
echo ""
echo "* Keyboard Brightness"
echo "  * Show in Menu Bar: OFF"
echo "  * Show in Control Center: OFF"
echo ""
echo "### 📊 Menu Bar Only"
echo ""
echo "* Clock: analog — scripted above, nothing to do"
echo "* Spotlight: Don't Show in Menu Bar"
echo "* Siri: Don't Show in Menu Bar"
echo "* Time Machine: Don't Show in Menu Bar"
echo "* Weather: Don't Show in Menu Bar"
echo ""
echo "🔗 To access: System Settings > Control Center"
echo ""
echo "📋 ============================================================================"

