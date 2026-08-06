#!/usr/bin/env bash

# ==============================================================================
# GLOBAL SETTINGS
# ==============================================================================

# Show all file extensions
defaults write -globalDomain AppleShowAllExtensions -bool true

# Show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show the ~/Library folder
chflags nohidden ~/Library

# Show the /Volumes folder
sudo chflags nohidden /Volumes

# Set the home folder as the default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}"

# Open folders in new windows instead of tabs
defaults write com.apple.finder FinderSpawnTab -bool false

# Expand the following File Info panes:
# "General", "Open with", and "Sharing & Permissions"
defaults write com.apple.finder FXInfoPanesExpanded -dict \
	General -bool true \
	OpenWith -bool true \
	Privileges -bool true

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Set save/open dialogs to list view by default
defaults write NSGlobalDomain NSNavPanelFileListModeForOpenMode2 -int 2
defaults write NSGlobalDomain NSNavPanelFileListModeForSaveMode2 -int 2

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false


# ==============================================================================
# .DS_STORE FILES
# ==============================================================================

# Disable creation of .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Disable creation of .DS_Store files on USB drives
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ==============================================================================
# VIEW SETTINGS
# ==============================================================================

# Arrange grouped view by name
defaults write com.apple.finder FXArrangeGroupViewBy -string Name

# Set list view grouping preference by name
defaults write com.apple.finder FXPreferredGroupBy -string Name

# Use list view in all Finder windows by default
# Four-letter codes for the view modes: `icnv` (icon), `clmv` (column), `glyv` (gallery), `Nlsv` (list)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Set default view settings for specific locations
defaults write com.apple.finder FXDefaultSearchViewStyle -string "Nlsv"

# ==============================================================================
# DESKTOP ICONS
# ==============================================================================

# Hide external hard drives on desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false

# Hide internal hard drives on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# Hide mounted servers on desktop
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false

# Hide removable media (USB drives, SD cards) on desktop
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# ==============================================================================
# FINDER WINDOW ELEMENTS
# ==============================================================================

# Show path bar at bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true

# Show sidebar in Finder windows
defaults write com.apple.finder ShowSidebar -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# ==============================================================================
# TAGS
# ==============================================================================

# Remove all favorite tags (empty array = no tags)
defaults write com.apple.finder FavoriteTagNames -array

# ==============================================================================
# APPLY CHANGES
# ==============================================================================

# Restart Finder to apply changes
killall Finder