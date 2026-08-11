# dotfiles + prefs sync helpers.
#
# The workflow is a pipeline with one command per hop:
#
#   remote ──dots-fetch──> source ──dots-apply──> live
#   remote <──dots-push──  source <──dots-dump──  live
#
#   dots-status  where everything stands: remote ↔ source ↔ live, plus prefs
#   dots-merge   when both source and live changed, reconcile per file/domain
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
  echo "— source ↔ remote —"
  local dirty ahead behind
  dirty="$(chezmoi git -- status --porcelain 2>/dev/null)"
  ahead="$(chezmoi git -- rev-list --count '@{u}..HEAD' 2>/dev/null)" || ahead=""
  behind="$(chezmoi git -- rev-list --count 'HEAD..@{u}' 2>/dev/null)" || behind=""

  local synced=1
  if [ -n "${dirty}" ]; then
    echo "  uncommitted source changes           -> dots-dump"
    synced=0
  fi
  if [ "${ahead:-0}" -gt 0 ]; then
    echo "  ${ahead} commit(s) not on the remote        -> dots-push"
    synced=0
  fi
  if [ "${behind:-0}" -gt 0 ]; then
    echo "  ${behind} commit(s) behind the remote       -> dots-fetch, then dots-apply"
    synced=0
  fi
  if [ -z "${ahead}${behind}" ]; then
    echo "  (no upstream — remote comparison unavailable)"
  elif [ "${synced}" -eq 1 ]; then
    echo "  in sync (as of last fetch — dots-fetch to refresh)"
  fi

  echo
  echo "— source ↔ live —"
  local out
  out="$(chezmoi status)"
  if [ -z "${out}" ]; then
    echo "  in sync"
  else
    printf '%s\n' "${out}"
    cat <<'EOF'

  col 1 = $HOME changed since chezmoi wrote it   col 2 = apply will change it
   _M  source is ahead        -> dots-apply
   MM  $HOME drifted          -> dots-merge, or dots-apply/dots-dump to pick a side
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

# remote -> source. Pull only — nothing touches $HOME until dots-apply.
dots-fetch() {
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

  local before after
  before="$(git -C "${src}" rev-parse HEAD 2>/dev/null)"
  # --autostash so an in-progress edit in the source dir doesn't block the
  # pull. This is what `chezmoi update` does internally.
  if ! git -C "${src}" pull --autostash --rebase; then
    echo
    echo "Pull failed — likely rebase conflicts with local commits." >&2
    echo "Resolve in the source repo (chezmoi cd), then: git rebase --continue" >&2
    return 1
  fi
  after="$(git -C "${src}" rev-parse HEAD 2>/dev/null)"

  if [ "${before}" = "${after}" ]; then
    echo "Already up to date."
  else
    echo
    echo "New commits:"
    git -C "${src}" log --oneline "${before}..${after}" | sed 's/^/  /'
  fi

  echo
  local pending
  pending="$(chezmoi status)"
  if [ -z "${pending}" ]; then
    echo "Live already matches the source — nothing to apply."
  else
    echo "Apply would touch:"
    printf '%s\n' "${pending}" | sed 's/^/  /'
    echo
    echo "Review and apply with: dots-apply"
  fi
}

# source -> live. Always shows the diff and asks first: applying overwrites live
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

# live -> source. Captures both tracks, shows what changed, commits. Does NOT
# push — that's dots-push, so review and publish stay separate steps.
# Extra args go to git commit, e.g. dots-dump -m "msg"; with none it prompts.
dots-dump() {
  chezmoi re-add || return 1

  # Prefs are live state too, but capture stays opt-in per AGENTS.md: a
  # whole-domain export can't tell chosen settings from app-written defaults.
  local export_sh drifted
  if export_sh="$(_dots_export_sh)"; then
    drifted="$("${export_sh}" --drifted 2>/dev/null)" || true
    if [ -n "${drifted}" ]; then
      echo "Drifted pref domains:"
      printf '%s\n' "${drifted}" | sed 's/^/  /'
      if [ -t 0 ]; then
        local reply
        read -q "reply?Capture them into the source too? [y/N] " || true
        echo
        if [[ "${reply}" == [Yy] ]]; then
          local domain
          while IFS= read -r domain; do
            [ -n "${domain}" ] && "${export_sh}" "${domain}"
          done <<< "${drifted}"
        else
          echo "  left uncaptured — dots-prefs <domain> picks one, dots-merge compares"
        fi
      else
        echo "  (not a terminal — leaving prefs uncaptured)"
      fi
    fi
  fi

  chezmoi git -- add -A || return 1
  if [ -z "$(chezmoi git -- status --porcelain 2>/dev/null)" ]; then
    echo "Source already matches live — nothing to commit."
    return 0
  fi

  echo
  echo "— review: what will be committed —"
  chezmoi git -- diff --cached --stat
  echo
  chezmoi git -- diff --cached

  echo
  if [ $# -gt 0 ]; then
    chezmoi git -- commit "$@" || return 1
  else
    if [ ! -t 0 ]; then
      echo "Not a terminal and no commit message — changes are staged but not committed." >&2
      echo "Run: dots-dump -m \"message\"" >&2
      return 1
    fi
    local msg
    read -r "msg?Commit message (empty aborts): "
    if [ -z "${msg}" ]; then
      echo "Aborted — changes remain staged."
      return 1
    fi
    chezmoi git -- commit -m "${msg}" || return 1
  fi
  echo "✓ committed — publish with dots-push when ready"
}

# source -> remote. Transport only: no re-add, no commit — dots-dump does that.
dots-push() {
  local dirty
  dirty="$(chezmoi git -- status --porcelain 2>/dev/null)"
  if [ -n "${dirty}" ]; then
    echo "⚠️  Uncommitted source changes — these will NOT be pushed:"
    printf '%s\n' "${dirty}" | sed 's/^/     /'
    echo "   Capture and commit first with: dots-dump"
    # Never block when there's no one to answer (scripts, CI, hooks).
    if [ -t 0 ]; then
      local reply
      read -q "reply?Push only the committed work? [y/N] " || true
      echo
      case "${reply}" in
        [Yy]) ;;
        *) echo "Aborted — nothing pushed."; return 1 ;;
      esac
    else
      echo "   (not a terminal — pushing committed work only)"
    fi
  fi

  local outgoing
  outgoing="$(chezmoi git -- log --oneline '@{u}..HEAD' 2>/dev/null)" || true
  if [ -z "${outgoing}" ]; then
    echo "Nothing to push — remote already has every commit (as of last fetch)."
    return 0
  fi
  echo "Pushing:"
  printf '%s\n' "${outgoing}" | sed 's/^/  /'
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
