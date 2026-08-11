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

# Keyboard shortcuts are NOT configured here.
#
# The whole com.apple.symbolichotkeys domain is a tracked snapshot in prefs/,
# imported by the run_onchange hook on every `chezmoi apply`. That snapshot
# already disables 81 of 87 shortcuts, including the Mission Control ones this
# script used to ask you to uncheck by hand (32 = Mission Control,
# 33 = Application windows, 36 = Show Desktop).
#
# To change a shortcut: change it in System Settings, then
#   prefs/export.sh com.apple.symbolichotkeys
