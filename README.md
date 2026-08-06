# dotfiles

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/), shared across
three near-identical machines: **work**, **personal M2**, and **personal M4**.

## How this repo works

This repo is a **chezmoi source directory**: files use chezmoi naming and are
deployed into `$HOME` by `chezmoi apply`.

| Source | Deploys to |
|--------|------------|
| `private_dot_zshrc` | `~/.zshrc` (mode 600) |
| `private_dot_Brewfile` | `~/.Brewfile` |
| `dot_ssh/private_config` | `~/.ssh/config` |
| `private_Library/...Code/User/settings.json` | `~/Library/Application Support/Code/User/settings.json` |

Prefixes: `dot_` → leading dot, `private_` → mode 600/700, `executable_` →
mode 755, `modify_` → script that transforms the existing file, `.tmpl` →
template rendered before use.

Special pieces:

- **`.chezmoiscripts/run_onchange_darwin-brew-bundle.sh.tmpl`** — runs
  `brew bundle` automatically on `chezmoi apply` whenever the Brewfile changed
  (the embedded hash tracks it).
- **`.chezmoiscripts/run_onchange_darwin-import-prefs.sh.tmpl`** — re-imports
  app preference snapshots and restarts the affected apps whenever a snapshot
  in `prefs/` changed.
- **`dot_config/joplin-desktop/modify_private_settings.json`** — merges synced
  Joplin settings onto the live file while preserving the machine-local
  `api.token` and `sync.*` keys, so they never enter this (public) repo.
- **`.chezmoiignore`** — keeps repo-only files (`README.md`, `PACKAGES.md`,
  `setup.sh`, `prefs/`) out of `$HOME`.
- **`.pre-commit-config.yaml`** — gitleaks scans every commit for secrets.

## Machine-local files (never committed)

Secrets and per-machine overrides live outside chezmoi entirely:

| File | Purpose |
|------|---------|
| `~/.zshrc.local` | sourced at the end of `.zshrc` (e.g. `SECRET_ENV`) |
| `~/.ssh/config.local` | `Include`d from `~/.ssh/config` (home-lab hosts, colima) |
| `~/.npmrc` | written by `npm login`; holds auth tokens |
| `~/.config/chezmoi/chezmoi.toml` | points chezmoi at this repo as its source |

If something secret or machine-specific needs a home, it goes in one of these
— never in a managed file.

## Daily sync

Aliases/functions defined in `.zshrc`:

```sh
dots-status   # what differs between live files and the source
dots-pull     # git pull + show diff — review, then run: chezmoi apply
dots-push     # chezmoi re-add live changes, commit, push
```

Editing flow, either direction works:

- Edit the live file (e.g. `~/.zshrc`), then `dots-push` to capture + commit.
- Or `chezmoi edit ~/.zshrc`, then `chezmoi apply` to update the live file.

### App preferences

GUI app settings (Raycast, Rectangle Pro, Stats, Ice, Middle, Monosnap, macOS
hotkeys) are **snapshots**, not live-tracked. After changing settings you want
to sync:

```sh
./prefs/export.sh    # refresh snapshots from this machine
git add prefs && git commit
```

On the receiving machine, the next `chezmoi apply` imports them and restarts
the affected apps.

## Setting up a new machine

```sh
# 1. Bootstrap tooling: Homebrew + Brewfile (includes chezmoi), Xcode,
#    proto runtimes, Android SDK, gh/npm auth
curl -fsSL https://raw.githubusercontent.com/jgornick/dotfiles/master/setup.sh | bash

# 2. Initialize dotfiles — ALWAYS review the diff before applying on a
#    machine that already has config
chezmoi init git@github.com:jgornick/dotfiles.git
chezmoi diff
chezmoi apply
```

By default the source checkout lands in `~/.local/share/chezmoi`. To keep it
at `~/Projects/oss/dotfiles` instead (as on the M2), clone the repo there and
set `~/.config/chezmoi/chezmoi.toml`:

```toml
sourceDir = "/Users/joe/Projects/oss/dotfiles"
```

## Rolling out to an existing machine (M4 / work)

These machines have live configs with real drift — **never blind-apply**:

1. `brew install chezmoi`
2. If mackup is still present: `mackup uninstall` is no longer a subcommand in
   0.11+; check for symlinks first —
   `find ~ -maxdepth 3 -type l -lname '*dotfiles*'` — and resolve any, then
   `brew uninstall mackup`.
3. `chezmoi init git@github.com:jgornick/dotfiles.git` (no `--apply`)
4. `chezmoi diff` — review every hunk. For live-side changes worth keeping,
   `chezmoi re-add <file>` and commit; move any machine secrets into
   `~/.zshrc.local` / `~/.ssh/config.local` first.
5. `chezmoi apply`
6. Expect first-apply effects: `brew bundle` runs (may need
   `brew trust <tap>` for third-party taps), prefs import restarts those apps.

## Troubleshooting

- `chezmoi doctor` — sanity-check the setup.
- `brew trust xcodesorg/made` — newer Homebrew refuses untrusted third-party
  taps; trust any tap the Brewfile uses on first bundle.
- VS Code ≥ 1.131 bundles Copilot Chat; `vscode "github.copilot*"` entries
  can't be installed via brew and are intentionally absent from the Brewfile.
- A `run_onchange` script re-fires only when its embedded hash changes; to
  force one, `chezmoi state delete-bucket --bucket=entryState` (nuclear) or
  edit the tracked file.
