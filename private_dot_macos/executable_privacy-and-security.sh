#!/usr/bin/env bash

# Privacy & Security has nothing scripted yet. This file exists so the pane's
# manual list lives next to the other panes, with the reason each item is
# manual — the same rule as everywhere else in ~/.macos: nothing is written
# on a guess.

echo ""
echo "📋 ============================================================================"
echo "📋 MANUAL STEPS REQUIRED 📋"
echo "📋 ============================================================================"
echo ""
echo "Configure in System Settings > Privacy & Security:"
echo ""
echo "### 🔌 Security"
echo ""
echo "* Allow accessories to connect: Always allow"
echo "    Genuinely cannot be scripted on macOS 26. The value is Transport"
echo "    Restricted Mode, owned by the AppleCredentialManager kext and persisted"
echo "    in the Secure Enclave (ACMTRMSaveState). Toggling it writes no plist,"
echo "    nvram, sysctl, or ioreg value, so there is no defaults domain to set."
echo "    The settings pane writes it via ACMTRMConfigProxy_PolicyMode_Set under"
echo "    the private entitlement"
echo "    com.apple.private.applecredentialmanager.devicerestrictedmode.allow,"
echo "    which a third-party binary can't hold with SIP on — so it can't be"
echo "    read back for verification either."
echo ""
echo "    The only forcing path is an MDM Restrictions payload with"
echo "    allowUSBRestrictedMode=false (device channel, macOS 13+). These Macs"
echo "    aren't enrolled, and the profiles CLI can no longer install a"
echo "    .mobileconfig, so a profile would still need a click in System"
echo "    Settings and would grey the control out as managed — no gain."
echo ""
echo "📋 ============================================================================"
