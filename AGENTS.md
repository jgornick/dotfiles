# AGENTS.md — working on this repo as an agent

Context and rules for AI agents (Claude Code, etc.) operating in this
repository. Read README.md first for the human-facing overview.

## What this repo is

A **chezmoi source directory** for macOS dotfiles shared across multiple
Macs. The repo is **public**. Files here are *rendered/deployed* into `$HOME`
by chezmoi — editing a file in this repo does **not** change the live machine
until `chezmoi apply` runs, and live edits don't reach the repo until
`chezmoi re-add`.

## Hard rules

1. **Never `git push` unless the repo owner explicitly asks in the current
   conversation.** Local commits are fine.
2. **Never let secrets or personal details into the repo.** It's public.
   Machine-local files that must stay unmanaged: `~/.zshrc.local`,
   `~/.ssh/config.local`, `~/.npmrc`, and Joplin's `api.token`/`sync.*` keys
   (preserved by the modify_ script — never add them to its managed overlay).
   This covers more than credentials: private hostnames, internal IPs,
   employer usernames or IDs, and machine inventories don't belong here
   either. Run `betterleaks dir .` when in doubt; lefthook runs betterleaks on
   every commit regardless. Note that app-pref snapshots in `prefs/` can
   carry personal data from the *apps* (e.g. folder-permission paths) —
   inspect them after re-exporting.
3. **Never blind-apply onto a machine.** Live `$HOME` files drift from the
   repo (each machine has real local state). Always `chezmoi diff` and
   reconcile per file before `chezmoi apply`. The same applies in reverse:
   before `chezmoi re-add`, check the live file doesn't contain secrets.
4. **Don't chmod-normalize casually.** `private_`/`executable_` prefixes in
   source names encode target permissions; `~/Library` must stay 700
   (`private_Library`), `~/.ssh/*` must stay 600.

## How to make changes

- **Change a managed dotfile:** edit the source file here (e.g.
  `private_dot_zshrc`), then `chezmoi diff` → `chezmoi apply`. Or edit the
  live file and `chezmoi re-add <target>`.
- **Add a new file to management:** `chezmoi add <live-path>` (source name is
  derived automatically). Check the resulting prefix matches intended perms.
- **Change packages:** edit `private_dot_Brewfile`, then `chezmoi apply` —
  the `run_onchange` hook runs `brew bundle` because the file's hash (embedded
  in the script template) changed.
- **Change synced app prefs:** don't edit `prefs/*.plist` by hand; change the
  setting in the app, run `prefs/export.sh <domain>` for the domain you
  changed, commit. Never run `--all` on a machine whose apps aren't fully
  configured — whole-domain export can't tell your settings from fresh-install
  defaults and will overwrite good snapshots with a diff that looks routine.
  On apply, the import hook restarts the affected apps (Raycast, Rectangle Pro,
  Stats, Middle, Bartender, Monosnap) — mildly disruptive, expected.
- **Check pref drift:** `prefs/export.sh --check` compares live domains against
  snapshots; `--drifted` prints just the names (machine-readable); `--diff
  <domain>` shows what actually changed. Comparison normalises via `plutil -p`
  — `plutil -convert json` is NOT usable, it fails on the `<date>` and `<data>`
  values most of these snapshots contain.
- **Secrets and churn in prefs:** `prefs/` is committed to a public repo. Add
  keys to a `scrub_<domain_with_underscores>` array in `prefs/export.sh` to
  strip them after export; entries are **extended regexes** matched against
  whole key names. Use a pattern, not a literal, for anything secret — Paddle
  embeds a per-product id in its key (`Paddle-Middle-573204-SD`), and a literal
  that stops matching after a version bump would silently publish the licence.
  Safe because `defaults import` merges, so each machine keeps its own value.
  Volatile-but-harmless keys go in `noise_key_patterns` (global) or
  `noise_<domain>` (per-domain) instead — those are ignored when comparing but
  still exported.
- **Sync helpers:** `dot_config/zsh/dots.zsh` defines `dots-status` /
  `dots-pull` / `dots-push` / `dots-prefs` / `dots-merge`. They locate the repo
  via `chezmoi source-path` because `prefs/` is chezmoiignored and never lands
  in `$HOME`. `dots-push` prompts before committing when a domain has drifted,
  and skips the prompt when stdin isn't a TTY so scripts can't hang.
- **Repo-only files** (docs, scripts not deployed to `$HOME`): add them to
  `.chezmoiignore` or they will be deployed as `~/...` targets.

## Verification checklist

After any change:

```sh
chezmoi doctor        # config sanity (dirty-worktree warnings are normal)
chezmoi diff          # empty means source == live
chezmoi apply         # then run it AGAIN — second run must output nothing
```

For template changes (`.tmpl`), `chezmoi execute-template < file.tmpl` renders
without applying. For a fresh-machine simulation:
`chezmoi apply --destination <scratch-dir> --exclude scripts`.

## Gotchas learned the hard way

- `~/.config/chezmoi/chezmoi.toml`: `sourceDir` is a **top-level** key; inside
  a `[general]` section it's silently ignored and chezmoi uses
  `~/.local/share/chezmoi`.
- `chezmoi add` of a path whose parent dir already exists bare in the source
  tree reuses that bare name — it created a non-`private_` `Library/` once,
  which would have chmod'd `~/Library` 700 → 755 on apply.
- The Joplin `modify_` script must output `jq --tab` (Joplin's own format) or
  every Joplin write causes formatting churn; its `private_` filename prefix
  is what keeps the target at mode 600.
- Homebrew now requires `brew trust <tap>` for third-party taps
  (`xcodesorg/made`); an untrusted tap fails the whole bundle hook and aborts
  `chezmoi apply` mid-run.
- VS Code ≥ 1.131 has Copilot Chat built in; `vscode "github.copilot*"`
  Brewfile entries fail permanently — they were removed deliberately.
- mackup 0.11+ removed the `uninstall` subcommand; this repo no longer uses
  mackup at all.
- `setup.sh` fetches the Brewfile from raw GitHub at
  `master/private_dot_Brewfile` — if the source layout moves, update that
  path and the local fallback in `setup.sh`.
