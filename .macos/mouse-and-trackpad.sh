#!/usr/bin/env bash

# Disable “natural” (Lion-style) scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

defaults write -globalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# Disable gesture to show Desktop (spread thumb and three fingers)
defaults write com.apple.dock showDesktopGestureEnabled -bool false

# Disable gesture to show Launchpad (pinch thumb and three fingers)
defaults write com.apple.dock showLaunchpadGestureEnabled -bool false

# Disable gesture to show Mission Control (swipe up with three or four fingers)
defaults write com.apple.dock showMissionControlGestureEnabled -bool false
