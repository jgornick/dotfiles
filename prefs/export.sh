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
  ./export.sh --check [domain ...]    report drift between live and snapshot
  ./export.sh --drifted [domain ...]  print drifted domain names only
  ./export.sh --diff <domain>         show the normalized diff for one domain

Exit codes for --check / --drifted: 0 = in sync, 1 = something drifted.
A tracked domain with no snapshot yet is reported but does NOT count as drift.
EOF
}

# "monosnap" is a pseudo-domain: Monosnap stores JSON in its container rather
# than using the defaults system.
tracked_domains=(
  com.apple.symbolichotkeys
  com.knollsoft.Hookshot
  com.knollsoft.Middle
  com.raycast.macos
  com.surteesstudios.Bartender
  eu.exelban.Stats
  monosnap
)

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
  '.*[Cc]heck_?ts'                # "updater_check_ts"
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

tmpdir=""
cleanup() { [ -n "${tmpdir}" ] && rm -rf "${tmpdir}"; }
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
      echo "Run './export.sh --list' to see tracked domains, or add it to tracked_domains." >&2
      exit 1
    fi
  done
}

# Look up an array named after a domain (dots -> underscores) and echo its items.
domain_array() {
  local prefix="$1" domain="$2"
  local ref="${prefix}_${domain//./_}[@]"
  local item
  for item in ${!ref+"${!ref}"}; do
    printf '%s\n' "${item}"
  done
}

# List the top-level key names in a plist, one per line.
top_level_keys() {
  plutil -p "$1" 2>/dev/null | sed -nE 's/^  "([^"]+)" =>.*/\1/p'
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
  plutil -p "${file}" 2>/dev/null | grep -vE "${regex}" || true
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

  # `diff` exits 1 when files differ, which `pipefail` would turn into an abort.
  local keys count
  keys="$( { diff "${tmpdir}/repo/${domain}" "${tmpdir}/live/${domain}" || true; } \
    | sed -nE 's/^[<>]   "([^"]+)" =>.*/\1/p' | sort -u)"
  count="$(printf '%s' "${keys}" | grep -c . || true)"
  if [ "${count}" -gt 0 ]; then
    report "drifted" "${domain}" "(${count} keys differ)"
    printf '%s\n' "${keys}" | sed 's/^/                 /'
  else
    report "drifted" "${domain}" "(nested changes)"
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
