# Target Script - Installation Guide

The `target` script is a penetration testing project management tool that helps organize target information, project directories and per-host enumeration notes.

It is `engagement/target/target.py` (Python 3.11 or newer — it uses `tomllib` from the stdlib). No pip dependencies.

## Installation

Clone the repository and let `setup_links` do the work:

```bash
git clone https://github.com/desterhuizen/w1ld0s-tools.git
cd w1ld0s-tools
./setup_links
```

`setup_links` symlinks every executable in the repo into `~/.local/bin/`, stripping the file extension — so `engagement/target/target.py` becomes `~/.local/bin/target`. Run it once to initialise the configuration:

```bash
target
```

### Manual alternative

```bash
chmod +x engagement/target/target.py
ln -s "$PWD/engagement/target/target.py" ~/.local/bin/target
```

Prefer `setup_links`; the manual route skips the rest of the toolkit.

### Shell integration

`aliases` sources the state files at shell startup so `$IP`, `$TARGET_BASE`, `$TARGET_NAME`, `$TARGET_LAB` and `$TARGET_VPN` are available to other scripts (and to `setup_workspace`, which requires them). If you have not already:

```bash
echo 'source $HOME/tools/repos/w1ld0s-tools/aliases' >> ~/.zshrc
```

The sourcing is guarded, so missing or unreadable config files can never abort shell startup.

## Configuration

Configuration lives in `engagement/target/config/`, next to the script itself. Two kinds of file:

| File | Purpose |
|---|---|
| `targ.sh`, `base.sh`, `name.sh`, `lab.sh`, `vpn.sh` | Engagement **state**. Plain `export X="..."` so a shell can source them. |
| `config.toml` | Project **structure** — which directories, files, symlinks and checklists a project gets. |
| `config.legacy.sh` | Backup of a pre-port `config.sh`, written once during migration. |

### Where the config directory is resolved from

In order, first hit wins:

1. `$TARGET_CONFIG_DIR`, if set.
2. `engagement/target/config/` next to the real script (symlinks resolved).
3. Failing both, the pre-port location — see "Migration" below.

Setting `$TARGET_CONFIG_DIR` is the supported way to exercise `target` without touching live engagement state:

```bash
TARGET_CONFIG_DIR=/tmp/scratch/config target -i
```

Note that `target -b /tmp/...` alone is **not** enough for that — the state files are global and singular, so changing the base still overwrites your real `TARGET_BASE`, `TARGET_NAME` and `TARGET_LAB`.

### Customizing project structure

Edit `engagement/target/config/config.toml`:

```toml
version = 1

[project]
dirs  = ["scans", "exploits", "files", "notes", "evidence", "credentials"]
files = ["users", "passwords", "words"]

[project.symlinks]
"/var/www/html" = "www"
"~/smbshare"    = "smb"

[notes]
enabled  = true
filename = "notes.md"
template = "templates/host-notes.md"   # relative to the target/ directory

[checklists]
dest = "notes"
copy = ["../checklists/pentest_enumeration_checklist.md"]

[lab]
dirs = ["credentials", "loot"]
```

Notes:

- `[project.symlinks]` keys are paths and must be quoted. `~` is expanded when the symlink is created, so the file stays portable between machines.
- `[project.symlinks]` must come after all the bare `[project]` keys — that is a TOML rule, not a `target` one.
- Do **not** add `notes.md` to `[project].files`. It is generated from the template; listing it as a plain file is ignored with a warning.
- `[checklists].copy` paths are relative to the `target/` directory. Add more (e.g. `../common/content/web_checklist.md`) and each gets copied into every new host project. Set `copy = []` to disable.

To customize the notes themselves, edit `engagement/target/templates/host-notes.md`. Keep the `## N.` headings intact — the `-F`/`-A`/`-H`/`-X` append commands locate sections by those headings and will refuse to write if one is missing.

## Migration from the bash version

Nothing to do by hand: the first run of `target.py` migrates automatically and prints what it did.

**Config adoption.** The old bash implementation resolved its own directory with `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`, which does not follow symlinks. Invoked through `~/.local/bin/target`, it therefore stored everything in `~/.local/bin/config/` rather than `engagement/target/config/`. On first run, `target.py` finds that directory and **copies** (never moves) the files to the canonical location, then tells you the `rm -rf` command to clean up. Copying means a rollback still finds its config where it expects.

**Structure migration.** A legacy `config.sh` is evaluated with bash (`declare -p`) so that documented customization idioms like `PROJECT_DIRS+=( ... )` and `PROJECT_SYMLINKS["/path"]="dest"` survive. The result is written to `config.toml` and the original is renamed to `config.legacy.sh`. If the file cannot be evaluated, `target` writes defaults, leaves `config.sh` untouched, and warns loudly rather than guessing.

**Rollback** is documented in `engagement/target/legacy/README.md`. The state files keep their shell format specifically so the frozen bash remains a drop-in.

## Troubleshooting

* **Permission denied** — `chmod +x engagement/target/target.py`.
* **`target requires Python 3.11 or newer`** — `tomllib` is stdlib from 3.11. Check with `python3 --version`.
* **Configuration not found** — run `target` once to initialise it; `target -i` prints the resolved `Config Dir`.
* **Wrong config directory** — `target -i` shows which one is in use. Override with `$TARGET_CONFIG_DIR`.
* **`target` still runs the old bash version** — check `readlink -f ~/.local/bin/target`. Re-run `./setup_links` and answer `Y` when it offers to recreate the link.
* **Symlinks not created** — `target` skips a symlink whose destination already exists as a real file or directory, and prints which one. Remove it and re-run `target -m`.
* **`$IP` is empty in your shell** — open a new shell, or `source ~/.zshrc`. The variables are exported by `aliases` at startup, from `engagement/target/config/*.sh`.
