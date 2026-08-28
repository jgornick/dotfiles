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

# ==============================================================================
# CONTROL CENTER MODULE VISIBILITY
# ==============================================================================
#
# Contrary to the widely repeated claim, these ARE scriptable on macOS 26 — one
# integer key per module, in the ByHost (-currentHost) com.apple.controlcenter
# domain. Verified on 26.6 by round-tripping Sound and Battery: write the key,
# killall ControlCenter, and the status item is torn down or rebuilt to match.
# ControlCenter does not overwrite the external write on relaunch.
#
# The opaque ControlCenterDisplayableChronoControlsProviderConfiguration blob is
# a red herring — it holds the custom Control Center *controls* you can add
# (Dark Mode, Capture Screen, ...), not the built-in modules' visibility.
#
# Values (macOS 26): 8 = Don't Show in Menu Bar, 16 = Always Show in Menu Bar.
# Note 16, not the 18 that older write-ups list — 18 is a pre-26 value.
#
# Only modules that differ from the macOS default are written. A module with no
# key is at its default, and a fresh machine lands there on its own; to capture
# a new one, set it in System Settings and read the key back out of
# `defaults -currentHost read com.apple.controlcenter`.
defaults -currentHost write com.apple.controlcenter Sound -int 16
defaults -currentHost write com.apple.controlcenter Battery -int 8
defaults -currentHost write com.apple.controlcenter Display -int 8
defaults -currentHost write com.apple.controlcenter FocusModes -int 8
defaults -currentHost write com.apple.controlcenter NowPlaying -int 8
defaults -currentHost write com.apple.controlcenter Spotlight -int 8
defaults -currentHost write com.apple.controlcenter Timer -int 8

# ==============================================================================
# APPLY CHANGES
# ==============================================================================

# ControlCenter reads both the clock domain and the module keys above only at
# launch; without the restart the changes appear on next login instead of now.
killall ControlCenter 2>/dev/null || true

echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""
echo "Menu bar visibility for Sound, Battery, Display, Focus, Now Playing,"
echo "Spotlight and Timer is scripted above — nothing to do for those."
echo ""
echo "Still manual, because these have no key in com.apple.controlcenter on this"
echo "machine (they sit at the macOS default). Confirm them in System Settings >"
echo "Control Center, and if one needs changing, set it there and read the new"
echo "key out of \`defaults -currentHost read com.apple.controlcenter\` so it can"
echo "be added to the scripted block:"
echo ""
echo "### ⚙️ Control Center Modules"
echo ""
echo "* Wi-Fi: Show in Menu Bar"
echo "* Bluetooth: Show in Menu Bar"
echo "* AirDrop: Don't Show in Menu Bar"
echo "* Stage Manager: Don't Show in Menu Bar"
echo "* Screen Mirroring: Show When Active"
echo ""
echo "### 🔧 Other Modules"
echo ""
echo "* Accessibility Shortcuts"
echo "  * Show in Menu Bar: OFF"
echo "  * Show in Control Center: OFF"
echo ""
echo "* Battery — menu bar visibility scripted above; these are separate"
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

