# dotfiles

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/), shared across
multiple machines (work, personal M2, personal M4).

## Layout

This repo is a **chezmoi source directory**: files use chezmoi naming
(`dot_zshrc` → `~/.zshrc`, `private_dot_ssh/private_config` → `~/.ssh/config`).

| Path | Purpose |
|------|---------|
| `dot_*`, `private_*` | chezmoi-managed dotfiles (deployed into `$HOME`) |
| `.chezmoiscripts/` | `run_onchange_` hooks: `brew bundle` when the Brewfile changes, prefs import when snapshots change |
| `prefs/` | App preference snapshots (`defaults export`) + `export.sh` — repo-only, applied via the run_onchange hook |
| `dot_config/joplin-desktop/modify_settings.json` | Merges synced Joplin settings onto the live file, preserving the machine-local `api.token` and `sync.*` keys |
| `setup.sh` | New-machine bootstrap: Homebrew, Brewfile, Xcode, proto runtimes, Android SDK, auth |
| `PACKAGES.md` | Package audit / cross-reference |

## Machine-local files (never committed)

Secrets and per-machine overrides live outside chezmoi's management:

- `~/.zshrc.local` — sourced at the end of `.zshrc` (e.g. `SECRET_ENV`)
- `~/.ssh/config.local` — included from `~/.ssh/config` (private hosts, colima)
- `~/.npmrc` — written by `npm login`, intentionally unmanaged

## Daily sync

Aliases defined in `.zshrc`:

- `dots-status` — show drift between live files and the source
- `dots-pull` — pull from origin, then show the diff; review, then `chezmoi apply`
- `dots-push` — `chezmoi re-add` live changes, commit, and push

App preference changes (Raycast, Rectangle Pro, Stats, Ice, Middle,
Monosnap, macOS hotkeys) are **not** picked up automatically — run
`prefs/export.sh` to refresh the snapshots, then commit.

## New machine

```sh
# 1. Bootstrap tooling (installs Homebrew, Brewfile incl. chezmoi, runtimes)
curl -fsSL https://raw.githubusercontent.com/jgornick/dotfiles/master/setup.sh | bash

# 2. Initialize dotfiles — review before applying (never blind-apply onto
#    a machine with existing config)
chezmoi init git@github.com:jgornick/dotfiles.git
chezmoi diff
chezmoi apply
```

By default the source checkout lives at `~/.local/share/chezmoi`. To keep it
at `~/Projects/oss/dotfiles` instead, set `~/.config/chezmoi/chezmoi.toml`:

```toml
sourceDir = "/Users/joe/Projects/oss/dotfiles"
```

and clone the repo there before running `chezmoi` commands.
