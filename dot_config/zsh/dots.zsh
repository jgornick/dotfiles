# dotfiles + prefs sync helpers.
#
# Two tracks with deliberately different shapes:
#
#   dotfiles  bidirectional. chezmoi apply writes $HOME, chezmoi re-add
#             captures it back.
#   prefs     asymmetric. Import is automatic on apply; export is manual and
#             must name domains, because `defaults export` grabs a whole domain
#             and cannot tell a setting you chose from what an app wrote on
#             first launch.
#
# These helpers exist so the two tracks are visible in one place — mainly so a
# settings change can't be silently left out of a commit.

# prefs/ is chezmoiignored and never lands in $HOME, so reach it via the source
# directory rather than assuming a checkout path.
_dots_export_sh() {
  local src
  src="$(chezmoi source-path 2>/dev/null)" || return 1
  [ -n "${src}" ] && [ -x "${src}/prefs/export.sh" ] || return 1
  printf '%s\n' "${src}/prefs/export.sh"
}

dots-status() {
  echo "— dotfiles —"
  local out
  out="$(chezmoi status)"
  if [ -z "${out}" ]; then
    echo "  in sync"
  else
    printf '%s\n' "${out}"
    cat <<'EOF'

  col 1 = $HOME changed since chezmoi wrote it   col 2 = apply will change it
   _M  source is ahead        -> chezmoi apply
   MM  $HOME drifted          -> dots-merge, or apply/re-add to pick a side
   _R  script will run on next apply
EOF
  fi

  echo
  echo "— prefs —"
  local export_sh
  if ! export_sh="$(_dots_export_sh)"; then
    echo "  (prefs/export.sh not found via chezmoi source-path)"
    return 0
  fi
  "${export_sh}" --check
}

dots-pull() {
  local src branch
  src="$(chezmoi source-path 2>/dev/null)" || return 1
  branch="$(git -C "${src}" symbolic-ref --short HEAD 2>/dev/null)" || return 1

  # A branch can lose its upstream without losing its remote: `git filter-repo`
  # drops the remote outright, and re-adding it does not restore tracking.
  # `push.default = current` still pushes fine, so the gap only shows up here,
  # as git's unhelpful "no tracking information". Repair it instead.
  if ! git -C "${src}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    if git -C "${src}" rev-parse --verify -q "origin/${branch}" >/dev/null; then
      echo "No upstream for '${branch}' — setting it to origin/${branch}."
      git -C "${src}" branch --set-upstream-to="origin/${branch}" "${branch}" >/dev/null || return 1
    else
      echo "'${branch}' has no upstream and origin/${branch} doesn't exist." >&2
      echo "Add the remote first: git -C ${src} remote add origin <url>" >&2
      return 1
    fi
  fi

  # --autostash so an in-progress edit in the source dir doesn't block the pull.
  # This is what `chezmoi update` does internally.
  git -C "${src}" pull --autostash --rebase || return 1
  chezmoi diff
  echo
  echo "Review the diff above, then run: dots-apply"
}

# repo -> $HOME. Always shows the diff and asks first: applying overwrites live
# files and fires run_onchange scripts, and AGENTS.md forbids blind-applying.
# Takes optional targets, e.g. dots-apply ~/.zshrc
dots-apply() {
  local -a targets=("$@")

  local pending
  pending="$(chezmoi diff "${targets[@]}")"
  if [ -z "${pending}" ]; then
    echo "Nothing to apply — \$HOME already matches the source."
    return 0
  fi
  printf '%s\n' "${pending}"

  # Scripts are the surprising part of an apply: brew bundle can install
  # packages, and the prefs import restarts apps out from under you.
  local scripts
  scripts="$(chezmoi status "${targets[@]}" | grep -E '^.R ' | sed 's/^...//')" || true
  if [ -n "${scripts}" ]; then
    echo
    echo "⚠️  These scripts will run:"
    printf '%s\n' "${scripts}" | sed 's/^/     /'
    echo "     (brew bundle may install packages; the prefs import restarts apps)"
  fi

  echo
  # Unlike dots-push, refuse rather than proceed without a human: an
  # unattended apply overwriting live files is exactly the blind apply
  # that AGENTS.md rule 3 prohibits.
  if [ ! -t 0 ]; then
    echo "Not a terminal — refusing to apply unattended. Run 'chezmoi apply' directly if that's really what you want." >&2
    return 1
  fi

  local reply
  read -q "reply?Apply these changes? [y/N] " || true
  echo
  case "${reply}" in
    [Yy]) ;;
    *) echo "Aborted — nothing applied."; return 1 ;;
  esac

  chezmoi apply "${targets[@]}" || return 1
  echo "✓ applied"

  # apply imports pref snapshots, so the drift picture may have just changed.
  local export_sh
  if export_sh="$(_dots_export_sh)"; then
    echo
    echo "— prefs after apply —"
    "${export_sh}" --check || true
  fi
}

dots-push() {
  chezmoi re-add || return 1

  local export_sh drifted
  if export_sh="$(_dots_export_sh)"; then
    drifted="$("${export_sh}" --drifted 2>/dev/null)" || true
    if [ -n "${drifted}" ]; then
      echo "⚠️  These pref domains have drifted from their snapshots:"
      printf '%s\n' "${drifted}" | sed 's/^/     /'
      echo
      echo "   Capture with:  dots-prefs <domain>"
      echo "   Inspect with:  dots-merge"
      echo
      # Never block when there's no one to answer (scripts, CI, hooks).
      if [ -t 0 ]; then
        local reply
        read -q "reply?Continue without capturing them? [y/N] " || true
        echo
        case "${reply}" in
          [Yy]) ;;
          *) echo "Aborted — nothing committed."; return 1 ;;
        esac
      else
        echo "   (not a terminal — continuing without prompting)"
      fi
    fi
  fi

  chezmoi git -- add -A || return 1
  chezmoi git -- commit "$@" || return 1
  chezmoi git -- push
}

dots-prefs() {
  local export_sh
  export_sh="$(_dots_export_sh)" || {
    echo "prefs/export.sh not found via chezmoi source-path" >&2
    return 1
  }
  if [ $# -eq 0 ]; then
    "${export_sh}" --check
  else
    "${export_sh}" "$@"
  fi
}

# Reconcile either track. Dotfiles get a real three-way merge; prefs get a
# readable diff and a choice of side, because there is no three-way merge to
# perform — `defaults import` already merges key-wise, so the only outcomes are
# keep live, take repo, or leave it.
dots-merge() {
  if [ $# -gt 0 ]; then
    chezmoi merge "$@"
    return $?
  fi

  echo "— dotfiles —"
  chezmoi merge-all

  echo
  echo "— prefs —"
  local export_sh drifted
  export_sh="$(_dots_export_sh)" || return 0
  drifted="$("${export_sh}" --drifted 2>/dev/null)" || true
  if [ -z "${drifted}" ]; then
    echo "  nothing to reconcile"
    return 0
  fi

  local domain choice src
  src="$(chezmoi source-path)"
  while IFS= read -r domain; do
    [ -n "${domain}" ] || continue
    echo
    "${export_sh}" --diff "${domain}"
    echo
    echo "  ${domain}"
    echo "    [l] keep live  — export.sh ${domain}, overwriting the snapshot"
    echo "    [r] take repo  — defaults import, merged into the live domain"
    echo "    [s] skip"
    read -q "choice?  choice [l/r/s] " || true
    echo
    case "${choice}" in
      [Ll]) "${export_sh}" "${domain}" ;;
      [Rr])
        if [ "${domain}" = "monosnap" ]; then
          cp "${src}/prefs/monosnap-settings.json" \
            "${HOME}/Library/Containers/com.monosnap.monosnap/Data/Library/Monosnap/settings.json" \
            && echo "  imported monosnap settings"
        else
          defaults import "${domain}" "${src}/prefs/${domain}.plist" \
            && echo "  imported ${domain} (merged — live-only keys are kept)"
        fi
        ;;
      *) echo "  skipped ${domain}" ;;
    esac
  done <<< "${drifted}"
}
