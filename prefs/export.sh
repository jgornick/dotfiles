#!/bin/bash
# Exports and compares app preference snapshots in this directory.
#
# Naming domains is required on purpose. `defaults export` captures a whole
# domain, so it cannot tell settings you chose from whatever an app wrote on
# first launch. A blanket export run on a machine whose apps aren't configured
# yet overwrites good snapshots with fresh-install defaults, and the diff looks
# like an ordinary settings change. Exporting one domain at a time keeps the
# blast radius to the app you actually touched.
set -euo pipefail

cd "$(dirname "$0")"

usage() {
  cat <<'EOF'
Usage:
  ./export.sh <domain> [domain ...]   export only the named domains
  ./export.sh --all                   export every tracked domain
  ./export.sh --list                  list the domains this repo tracks
  ./export.sh --add <domain> [app]    track a new domain (app = process the
                                      import hook restarts, if any)
  ./export.sh --check [domain ...]    report drift between live and snapshot
  ./export.sh --drifted [domain ...]  print drifted domain names only
  ./export.sh --diff <domain>         show the normalized diff for one domain

Exit codes for --check / --drifted: 0 = in sync, 1 = something drifted.
A tracked domain with no snapshot yet is reported but does NOT count as drift.
EOF
}

# Tracked domains live in domains.conf (`domain|app-to-restart` per line),
# shared with the chezmoi import hook so the two lists cannot drift apart.
manifest_file="domains.conf"

tracked_domains=()
load_manifest() {
  [ -f "${manifest_file}" ] || { echo "${manifest_file} not found" >&2; exit 1; }
  local line
  while IFS= read -r line; do
    case "${line}" in '' | \#*) continue ;; esac
    tracked_domains+=("${line%%|*}")
  done <"${manifest_file}"
}
load_manifest

# Keys stripped from a snapshot after export, for two distinct reasons — the
# comment on each says which, so a security strip is never mistaken for tidying.
# Safe either way: `defaults import` merges rather than replaces, so the live
# domain on each machine keeps its own value.
#
# Entries are extended regexes matched against whole top-level key names. Use a
# pattern rather than a literal for anything secret: Paddle embeds a per-product
# id in its key (Paddle-Middle-573204-SD), and a literal that stops matching
# after a version bump would silently publish the licence instead of failing.
scrub_com_surteesstudios_Bartender=(
  'license6'                      # SECRET: licence key
  'license6HoldersName'           # PERSONAL: licence holder email
)
scrub_com_knollsoft_Hookshot=(
  'Paddle-.*'                     # SECRET: Paddle licence token
)
scrub_com_knollsoft_Middle=(
  'Paddle-.*'                     # SECRET: Paddle licence token
)
scrub_com_raycast_macos=(
  'raycastAI_openRouterModelsList' # CACHE: ~248KB model list, 98% of the snapshot
  'calculator_currenciesRefresh'   # CACHE: fetched FX rates
)

# Volatile keys ignored when comparing. These change on their own without you
# touching a setting, so counting them as drift would make --check cry wolf.
# Patterns are matched against whole top-level key names.
noise_key_patterns=(
  'NSWindow Frame .*'             # window geometry
  'NSStatusItem .*'               # menu bar item position
  'SU[A-Z].*'                     # Sparkle updater bookkeeping
  '.*[Cc]ache.*'                  # any self-refilling cache
  '.*[Hh]eartbeat.*'              # analytics pings
  '.*[Ll]ast[Pp]ing.*'
  '.*[Cc]heck.*[Dd]ate.*'         # "…lastAppUpdateCheckDate"
  '.*_ts'                         # unix-timestamp bookkeeping: updater_check_ts,
                                  # updater_install_ts — the _ts suffix is only
                                  # ever used for these, never for a setting
  '.*[Ll]astCheck.*'
  'firstLaunch.*'
  'install_date'
  'update_time'
  'lastVersion'
  'appAlreadyLaunched'
  'buildNumber'
)

# Per-domain additions, for churn too app-specific to generalise. Same
# name-mangling as the scrub arrays.
noise_com_raycast_macos=(
  'raycastAI_deviceInfo'          # per-machine hardware description
  'raycastAI_model.*'             # refetched model catalogues
  'raycastAI_remoteExtensions'
  'database_lastValidOSVersion'   # tracks the OS, not a setting
)
noise_eu_exelban_Stats=(
  'version'                       # app version, bumps on every update
)
noise_com_surteesstudios_Bartender=(
  # Both are per-machine by construction, so they can never converge across
  # Macs. Still exported (a fresh machine wants something there), just not
  # counted as drift.
  'ImageIndex'                    # hashes of the icons this Mac actually renders
  'MenuBarColoring-SpaceSettings' # keyed by Space UUIDs, which are per-machine
  'com\.bartender\.windowmap\.persistence'  # window ids -> uuids, per session
)

tmpdir=""
# `[ -z ... ] ||` rather than `[ -n ... ] &&`: this runs as the EXIT trap, and
# under `set -e` a trap whose last command fails overrides the script's exit
# status — `--list` was exiting 1 whenever no tmpdir had been made.
cleanup() { [ -z "${tmpdir}" ] || rm -rf "${tmpdir}"; }
trap cleanup EXIT
ensure_tmp() { [ -n "${tmpdir}" ] || tmpdir="$(mktemp -d)"; }

drift_count=0
porcelain=0

is_tracked() {
  local candidate="$1" known
  for known in "${tracked_domains[@]}"; do
    [ "${known}" = "${candidate}" ] && return 0
  done
  return 1
}

require_tracked() {
  local domain
  for domain in "$@"; do
    if ! is_tracked "${domain}"; then
      echo "Unknown domain: ${domain}" >&2
      echo "Run './export.sh --list' to see tracked domains, or './export.sh --add ${domain}' to start tracking it." >&2
      exit 1
    fi
  done
}

# Look up an array named after a domain (dots/dashes -> underscores) and echo
# its items.
domain_array() {
  local prefix="$1" domain="$2"
  local ref="${prefix}_${domain//[.-]/_}[@]"
  local item
  for item in ${!ref+"${!ref}"}; do
    printf '%s\n' "${item}"
  done
}

# List the top-level key names in a plist, one per line.
top_level_keys() {
  plutil -p "$1" 2>/dev/null | sed -nE 's/^  "([^"]+)" =>.*/\1/p'
}

# Print one top-level entry from a normalized dump, including any nested block
# it owns. Matched with index() rather than a regex so keys containing regex
# metacharacters (com.bartender.windowmap.persistence) behave.
extract_block() {
  awk -v key="$2" '
    BEGIN { want = "  \"" key "\" =>" }
    !inblk && index($0, want) == 1 {
      print
      if ($0 ~ /[{(]$/) inblk = 1
      next
    }
    inblk {
      print
      if ($0 ~ /^  [})]/) inblk = 0
    }
  ' "$1"
}

# Names of top-level keys whose values differ between two normalized dumps.
# Comparing per key rather than diffing raw lines is what lets a change buried
# inside a nested dict still be reported as "ProfileSettings" instead of the
# useless "something on line 24".
changed_top_level_keys() {
  local a="$1" b="$2" key
  { sed -nE 's/^  "([^"]+)" =>.*/\1/p' "${a}"
    sed -nE 's/^  "([^"]+)" =>.*/\1/p' "${b}"; } | sort -u | while IFS= read -r key; do
    [ -n "${key}" ] || continue
    cmp -s <(extract_block "${a}" "${key}") <(extract_block "${b}" "${key}") \
      || printf '%s\n' "${key}"
  done
}

# Remove every top-level key matching this domain's scrub patterns. Echoes the
# names removed so callers can report them. Patterns are expanded against the
# file's actual keys, so a product-id change can't cause a silent miss.
strip_scrub() {
  local domain="$1" file="$2" pattern key
  while IFS= read -r pattern; do
    [ -n "${pattern}" ] || continue
    while IFS= read -r key; do
      [ -n "${key}" ] || continue
      if plutil -remove "${key}" "${file}" >/dev/null 2>&1; then
        printf '%s\n' "${key}"
      fi
    done < <(top_level_keys "${file}" | grep -xE "${pattern}" || true)
  done < <(domain_array scrub "${domain}")
}

noise_regex_for() {
  local domain="$1" joined="" pattern
  for pattern in "${noise_key_patterns[@]}"; do
    joined="${joined:+${joined}|}${pattern}"
  done
  while IFS= read -r pattern; do
    [ -n "${pattern}" ] || continue
    joined="${joined:+${joined}|}${pattern}"
  done <<EOF
$(domain_array noise "${domain}")
EOF
  printf '^  "(%s)" =>' "${joined}"
}

# plutil -p is key-sorted and renders every plist type. `plutil -convert json`
# is not usable here: it fails on the <date> and <data> values that four of
# these five snapshots contain.
#
# Caveat: plutil -p abbreviates <data> to its length plus first/last bytes, so a
# content change at identical length inside a blob is invisible. After the
# Raycast scrub above, the only data value left is Stats' Clock_list (220B).
normalize() {
  local file="$1" regex="$2"
  # Drop noise keys including any nested block they own. A plain line filter
  # would strip `"key" => {` but leave its children behind, which is how
  # com.bartender.windowmap.persistence (a per-session window-id map) kept
  # showing up as drift.
  plutil -p "${file}" 2>/dev/null | awk -v re="${regex}" '
    skip {
      if ($0 ~ /^  [})]/) skip = 0    # closing line at top-level indent
      next
    }
    $0 ~ re {
      if ($0 ~ /[{(]$/) skip = 1      # entry opens a nested block
      next
    }
    { print }
  ' || true
}

# Writes the normalized live/repo text pair into $tmpdir. Returns:
#   0 both written  1 domain absent here  2 no snapshot committed yet
prepare_pair() {
  local domain="$1"
  ensure_tmp
  mkdir -p "${tmpdir}/live" "${tmpdir}/repo"

  local live_plist="${tmpdir}/live-${domain}.plist"
  local repo_plist="${tmpdir}/repo-${domain}.plist"

  defaults export "${domain}" "${live_plist}" 2>/dev/null || return 1
  [ -f "${domain}.plist" ] || return 2
  cp "${domain}.plist" "${repo_plist}"

  strip_scrub "${domain}" "${live_plist}" >/dev/null
  strip_scrub "${domain}" "${repo_plist}" >/dev/null

  local regex
  regex="$(noise_regex_for "${domain}")"
  normalize "${live_plist}" "${regex}" >"${tmpdir}/live/${domain}"
  normalize "${repo_plist}" "${regex}" >"${tmpdir}/repo/${domain}"
  return 0
}

report() {
  local state="$1" domain="$2" detail="${3:-}"
  [ "${porcelain}" -eq 1 ] && return 0
  printf '  %-12s %s%s\n' "${state}" "${domain}" "${detail:+  ${detail}}"
}

check_monosnap() {
  local live="${HOME}/Library/Containers/com.monosnap.monosnap/Data/Library/Monosnap/settings.json"
  if [ ! -f "${live}" ]; then
    report "absent" "monosnap" "(not present on this machine)"
    return 0
  fi
  if [ ! -f "monosnap-settings.json" ]; then
    report "no snapshot" "monosnap" "(never exported)"
    return 0
  fi
  if diff -q <(jq -S . "${live}") <(jq -S . monosnap-settings.json) >/dev/null 2>&1; then
    report "in sync" "monosnap"
  else
    drift_count=$((drift_count + 1))
    [ "${porcelain}" -eq 1 ] && echo "monosnap" || report "drifted" "monosnap"
  fi
  return 0
}

check_domain() {
  local domain="$1"

  if [ "${domain}" = "monosnap" ]; then
    check_monosnap
    return 0
  fi

  local status=0
  prepare_pair "${domain}" || status=$?
  case "${status}" in
    1) report "absent" "${domain}" "(not present on this machine)"; return 0 ;;
    2) report "no snapshot" "${domain}" "(never exported)"; return 0 ;;
  esac

  if cmp -s "${tmpdir}/live/${domain}" "${tmpdir}/repo/${domain}"; then
    report "in sync" "${domain}"
    return 0
  fi

  drift_count=$((drift_count + 1))
  if [ "${porcelain}" -eq 1 ]; then
    echo "${domain}"
    return 0
  fi

  local keys count
  keys="$(changed_top_level_keys "${tmpdir}/repo/${domain}" "${tmpdir}/live/${domain}")"
  count="$(printf '%s' "${keys}" | grep -c . || true)"
  if [ "${count}" -gt 0 ]; then
    report "drifted" "${domain}" "(${count} keys differ)"
    printf '%s\n' "${keys}" | sed 's/^/                 /'
  else
    report "drifted" "${domain}" "(differences outside any top-level key)"
  fi
  return 0
}

diff_domain() {
  local domain="$1"

  if [ "${domain}" = "monosnap" ]; then
    local live="${HOME}/Library/Containers/com.monosnap.monosnap/Data/Library/Monosnap/settings.json"
    ensure_tmp
    mkdir -p "${tmpdir}/live" "${tmpdir}/repo"
    jq -S . "${live}" >"${tmpdir}/live/monosnap" 2>/dev/null || true
    jq -S . monosnap-settings.json >"${tmpdir}/repo/monosnap" 2>/dev/null || true
  else
    local status=0
    prepare_pair "${domain}" || status=$?
    case "${status}" in
      1) echo "${domain} is not present on this machine." >&2; return 1 ;;
      2) echo "${domain} has no snapshot committed yet." >&2; return 1 ;;
    esac
  fi

  # Run from $tmpdir so the diff header reads repo/<domain> vs live/<domain>
  # instead of two absolute temp paths.
  ( cd "${tmpdir}" && git diff --no-index --color=auto -- \
      "repo/${domain}" "live/${domain}" ) || true
}

export_monosnap() {
  local settings="${HOME}/Library/Containers/com.monosnap.monosnap/Data/Library/Monosnap/settings.json"
  if [ -f "${settings}" ]; then
    cp "${settings}" monosnap-settings.json
    echo "exported monosnap"
  else
    echo "skipped monosnap (settings.json not found)"
  fi
}

export_domain() {
  local domain="$1"

  if [ "${domain}" = "monosnap" ]; then
    export_monosnap
    return
  fi

  if ! defaults export "${domain}" "${domain}.plist" 2>/dev/null; then
    echo "skipped ${domain} (domain not found)"
    return
  fi
  echo "exported ${domain}"

  local key
  while IFS= read -r key; do
    [ -n "${key}" ] || continue
    echo "  scrubbed ${key}"
  done < <(strip_scrub "${domain}" "${domain}.plist")
}

# Registers a domain in domains.conf. Deliberately does NOT export it: the gap
# between --add and the first export is where you review the keys printed below
# and write scrub_/noise_ entries — everything in prefs/ lands in a public repo.
add_domain() {
  local domain="$1" app="${2:-}"

  if is_tracked "${domain}"; then
    echo "${domain} is already tracked." >&2
    exit 1
  fi

  # `defaults export` succeeds for nonexistent domains (it writes an empty
  # plist), so probe with `defaults read`, which actually fails.
  if ! defaults read "${domain}" >/dev/null 2>&1; then
    echo "No live defaults domain '${domain}' on this machine." >&2
    echo "Find an app's domain with: mdls -name kMDItemCFBundleIdentifier -raw '/Applications/<App>.app'" >&2
    exit 1
  fi
  ensure_tmp
  local live="${tmpdir}/add-${domain}.plist"
  defaults export "${domain}" "${live}"

  printf '%s|%s\n' "${domain}" "${app}" >>"${manifest_file}"
  echo "Tracking ${domain}${app:+ (import restarts ${app})} — added to ${manifest_file}."
  echo

  # Blobs get flagged because plutil renders them opaquely: a "settings" blob
  # can embed live credentials (Claude Usage's profiles_v3 carried OAuth
  # tokens), and nothing downstream would notice.
  echo "Its top-level keys — review them, prefs/ is committed to a PUBLIC repo:"
  local key value flag
  while IFS=$'\t' read -r key value; do
    flag=""
    case "${value}" in
      '{length = '*) flag="⚠️  opaque data blob — decode it before trusting it" ;;
    esac
    if printf '%s\n' "${key}" | grep -qiE 'licen[cs]e|token|secret|passw|credential|account|email|paddle'; then
      flag="⚠️  name suggests a secret"
    fi
    printf '  %-44s%s\n' "${key}" "${flag}"
  done < <(plutil -p "${live}" | sed -nE 's/^  "([^"]+)" => (.*)$/\1\t\2/p')

  cat <<EOF

Before the first export:
  1. secret keys      -> scrub_${domain//[.-]/_}=( ... ) in export.sh
  2. volatile keys    -> noise_${domain//[.-]/_}=( ... ) in export.sh
  3. then snapshot it -> ./export.sh ${domain}
EOF
}

run_checks() {
  local domains=("$@")
  [ ${#domains[@]} -gt 0 ] || domains=("${tracked_domains[@]}")
  require_tracked "${domains[@]}"

  local domain
  for domain in "${domains[@]}"; do
    check_domain "${domain}"
  done

  [ "${drift_count}" -eq 0 ] || return 1
  return 0
}

if [ $# -eq 0 ]; then
  usage
  echo
  echo "Refusing to export every domain implicitly — name the ones you changed." >&2
  exit 1
fi

case "$1" in
  --list)
    printf '%s\n' "${tracked_domains[@]}"
    exit 0
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  --add)
    shift
    [ $# -ge 1 ] && [ $# -le 2 ] || { echo "Usage: ./export.sh --add <domain> [app-to-restart]" >&2; exit 1; }
    add_domain "$@"
    exit 0
    ;;
  --check)
    shift
    run_checks "$@"
    exit $?
    ;;
  --drifted)
    shift
    porcelain=1
    run_checks "$@"
    exit $?
    ;;
  --diff)
    shift
    [ $# -eq 1 ] || { echo "--diff takes exactly one domain" >&2; exit 1; }
    require_tracked "$1"
    diff_domain "$1"
    exit 0
    ;;
  --all)
    echo "Exporting all tracked domains — only correct on a fully configured machine."
    for domain in "${tracked_domains[@]}"; do
      export_domain "${domain}"
    done
    exit 0
    ;;
esac

require_tracked "$@"
for domain in "$@"; do
  export_domain "${domain}"
done
