# dotfiles

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/), shared across
multiple Macs.

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
- **`.chezmoiignore`** — keeps repo-only files (`README.md`, `AGENTS.md`,
  `setup.sh`, `prefs/`) out of `$HOME`.
- **`lefthook.yml`** — betterleaks scans every commit for secrets (run
  `lefthook install` once after cloning).

## Machine-local files (never committed)

Secrets and per-machine overrides live outside chezmoi entirely:

| File | Purpose |
|------|---------|
| `~/.zshrc.local` | sourced at the end of `.zshrc`; machine-local env vars and secrets |
| `~/.ssh/config.local` | `Include`d from `~/.ssh/config`; private hosts |
| `~/.npmrc` | written by `npm login`; holds auth tokens |
| `~/.config/chezmoi/chezmoi.toml` | points chezmoi at this repo as its source |

If something secret or machine-specific needs a home, it goes in one of these
— never in a managed file.

## Daily sync

### The model

chezmoi has **three** states, which is why "changed in both places" feels
ambiguous until you see them named:

```
  source                target                 destination
  (this repo)  ──────>  (source + templates    ($HOME: the real files)
                         + config)
      ▲                                              │
      └────────────  add / re-add  ◄─────────────────┘
```

- **repo → home:** `chezmoi apply`
- **home → repo:** `chezmoi add` (new file), `chezmoi re-add` (already managed)
- **edit the repo directly:** `chezmoi edit`

App preferences do **not** work this way, and can't: they aren't files you edit
but a database `cfprefsd` owns and apps write to continuously. They get a
deliberately asymmetric pipeline instead — import automatic, export manual.

### Helpers

Defined in `dot_config/zsh/dots.zsh`, sourced from `.zshrc`:

```sh
dots-status   # am I in sync? — both dotfiles and prefs
dots-pull     # git pull + show diff — review, then run: chezmoi apply
dots-push     # re-add, warn on uncaptured pref drift, commit, push
dots-prefs    # bare: check for pref drift; with a domain: export it
dots-merge    # reconcile: dotfiles via 3-way merge, prefs by choosing a side
```

| Situation | Command |
|---|---|
| What differs? | `dots-status` |
| Get remote changes | `dots-pull` → review → `chezmoi apply` |
| Captured a live dotfile edit | `dots-push -m "msg"` |
| Edit via the repo instead | `chezmoi edit ~/.zshrc` → `chezmoi apply` |
| Changed an app's settings | `dots-prefs <domain>` → `dots-push -m "msg"` |
| **Both sides changed** | `dots-merge` → then `dots-push` |

### Reading `chezmoi status`

Two columns: the first is whether `$HOME` changed since chezmoi last wrote it,
the second is whether `chezmoi apply` will change it.

- `_M` — source is ahead; just `chezmoi apply`
- `MM` — `$HOME` drifted
- `_R` — a script will run on the next apply

`MM` does **not** distinguish "only `$HOME` changed" from "both changed" — a
drifted file differs from the target either way. Check `git log` if you need to
know, or just run `dots-merge`, which handles both cases correctly.

### App preferences

GUI app settings (Raycast, Rectangle Pro, Stats, Middle, Bartender, Monosnap,
macOS hotkeys) are **snapshots**, not live-tracked.

```sh
dots-prefs                              # which domains have drifted
dots-prefs com.knollsoft.Hookshot       # capture that one
./prefs/export.sh --diff <domain>       # see exactly what differs
```

`export.sh` requires you to name domains — it will not export everything
implicitly. `defaults export` captures a whole domain and cannot distinguish
settings you chose from what an app wrote on first launch, so a blanket export
on a machine whose apps aren't set up yet quietly replaces good snapshots with
fresh-install defaults. Naming domains keeps that blast radius to the one app
you touched. `--all` exists for a fully configured machine.

Drift checks ignore volatile keys (window geometry, menu-bar positions, update
timestamps, caches) so that `--check` reports real settings changes only — see
`noise_key_patterns` in `prefs/export.sh`.

On the receiving machine, the next `chezmoi apply` imports the snapshots and
restarts the affected apps. Import **merges** into the live domain rather than
replacing it, so per-machine values (licences, for one) survive.

Reconciling a pref conflict is **choosing a side with a readable diff**, not an
editable merge — there is no three-way merge to perform, since `defaults
import` already merges key-wise. `dots-merge` offers keep-live / take-repo /
skip per domain. Note "take repo" merges rather than replaces, so it will not
delete keys that exist only on this machine.

## Setting up a new machine

Every machine keeps the source checkout at `~/Projects/oss/dotfiles`, so clone
first and run `setup.sh` **from that clone** — do not pipe it from `curl`. The
script prompts for input (`npm login`, the Xcode license, "press Enter to
continue"), and piping it into `bash` hands those prompts the script's own text
instead of the keyboard. Running from the clone also makes it use the local
`private_dot_Brewfile` rather than downloading whatever is on `master`.

```sh
# 1. Command Line Tools, for git
xcode-select --install

# 2. Clone to the canonical location (HTTPS — the SSH key isn't restored yet)
git clone https://github.com/jgornick/dotfiles.git ~/Projects/oss/dotfiles

# 3. Point chezmoi at the clone (this file is machine-local and never managed)
mkdir -p ~/.config/chezmoi
printf 'sourceDir = "%s/Projects/oss/dotfiles"\n' "$HOME" > ~/.config/chezmoi/chezmoi.toml

# 4. Bootstrap tooling: Homebrew + Brewfile (includes chezmoi), Xcode,
#    proto runtimes, Android SDK, gh/npm auth. Interactive — expect Apple ID,
#    App Store, and gh prompts.
cd ~/Projects/oss/dotfiles && ./setup.sh

# 5. Apply dotfiles — ALWAYS review the diff first
chezmoi diff
chezmoi apply

# 6. Install the commit hooks in the clone
lefthook install
```

One follow-up the script doesn't cover:

- **Restore machine-local files by hand** — `~/.zshrc.local`, `~/.ssh/config.local`,
  and `~/.ssh/` keys. Once the GitHub key is back, switch the remote to SSH:
  `git remote set-url origin git@github.com:jgornick/dotfiles.git`.

## Rolling out to an existing machine

Machines with live configs have real drift — **never blind-apply**:

1. `brew install chezmoi`
2. If mackup is still present: `mackup uninstall` is no longer a subcommand in
   0.11+; check for symlinks first —
   `find ~ -maxdepth 3 -type l -lname '*dotfiles*'` — and resolve any, then
   `brew uninstall mackup`.
3. Clone to `~/Projects/oss/dotfiles` and point `~/.config/chezmoi/chezmoi.toml`
   at it (see above) — no `chezmoi init --apply`.
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
