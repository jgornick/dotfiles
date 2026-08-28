#!/usr/bin/env bash

# Set mouse tracking speed ("Tracking speed" slider in Settings > Mouse).
# The slider's ten ticks are 0.0, 0.125, 0.5, 0.6875, 0.875, 1.0, 1.5, 2.0,
# 2.5, 3.0 — 1.0 is the sixth tick. Off-tick values work too; the slider then
# renders at the nearest tick. A bare `defaults write` does not take effect
# until next login; running this via ~/.macos.sh is what picks it up sooner,
# since that ends with `activateSettings -u`.
defaults write NSGlobalDomain com.apple.mouse.scaling -float 1.0

# Disable “natural” (Lion-style) scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

defaults write -globalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# Disable gesture to show Desktop (spread thumb and three fingers)
defaults write com.apple.dock showDesktopGestureEnabled -bool false

# Disable gesture to show Launchpad (pinch thumb and three fingers)
defaults write com.apple.dock showLaunchpadGestureEnabled -bool false

# Disable gesture to show Mission Control (swipe up with three or four fingers)
defaults write com.apple.dock showMissionControlGestureEnabled -bool false
