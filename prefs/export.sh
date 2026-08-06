#!/bin/bash
# Exports current app preferences into snapshot files in this directory.
# Run this after changing app settings you want synced, then commit.
set -euo pipefail

cd "$(dirname "$0")"

domains=(
  com.apple.symbolichotkeys
  com.jordanbaird.Ice
  com.knollsoft.Hookshot
  com.knollsoft.Middle
  com.knollsoft.Rectangle
  com.raycast.macos
  eu.exelban.Stats
)

for domain in "${domains[@]}"; do
  if defaults export "${domain}" "${domain}.plist" 2>/dev/null; then
    echo "exported ${domain}"
  else
    echo "skipped ${domain} (domain not found)"
  fi
done

# Monosnap stores settings as JSON in its container, not via defaults
monosnap_settings="${HOME}/Library/Containers/com.monosnap.monosnap/Data/Library/Monosnap/settings.json"
if [ -f "${monosnap_settings}" ]; then
  cp "${monosnap_settings}" monosnap-settings.json
  echo "exported Monosnap settings"
fi
