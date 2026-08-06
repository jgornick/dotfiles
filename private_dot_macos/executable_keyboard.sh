#!/usr/bin/env bash

# Set initial key repeat delay (lower = faster)
# Default is 15, lower values make key repeat start faster
defaults write -globalDomain InitialKeyRepeat -float 15.0

# Set key repeat rate (lower = faster)
# Default is 2, lower values make keys repeat faster
defaults write -globalDomain KeyRepeat -float 2.0

# Enable function keys as standard function keys (F1, F2, etc.)
# When true: Press F1-F12 for standard function keys, Fn+F1-F12 for special features (brightness, volume, etc.)
# When false: Press F1-F12 for special features, Fn+F1-F12 for standard function keys
defaults write -globalDomain com.apple.keyboard.fnState -bool true

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Disable automatic capitalization as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# # Complete Keyboard Shortcuts Override
# # This configuration explicitly sets ALL keyboard shortcuts to their current state
# # This ensures complete control over keyboard shortcuts - no defaults will be used

# # Find all available keyboard shortcut keys and disable them
# keys=$(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null | grep -o '^[[:space:]]*[0-9]\+ =' | sed 's/ =//' | tr -d ' ' | sort -u)

# for key in $keys; do
#     # Set value to empty dict
#     /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:$key:value {}" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value dict" ~/Library/Preferences/com.apple.symbolichotkeys.plist
#     # Set enabled to 0
#     /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:$key:enabled 0" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:enabled integer 0" ~/Library/Preferences/com.apple.symbolichotkeys.plist
# done


echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""
echo "⚠️  The following settings cannot be automated and must be configured manually:"
echo ""
echo "⌨️  Keyboard Shortcuts - Mission Control & Function Keys:"
echo "      - Open System Settings > Keyboard > Keyboard Shortcuts > Mission Control"
echo "      - Uncheck all Mission Control shortcuts, specifically:"
echo "        • Mission Control (typically F3 or Ctrl+↑)"
echo "        • Application windows (typically F4)"
echo "        • Show Desktop (typically F11)"
echo ""
echo "      Note: When 'Use F1, F2, etc. keys as standard function keys' is enabled,"
echo "      you must disable these in System Settings as they are hardware-level"
echo "      shortcuts that bypass the symbolic hotkeys system."
echo ""
echo "🔗 To access: System Settings > Keyboard > Keyboard Shortcuts > Mission Control"
echo ""
echo "📋 ============================================================================"
