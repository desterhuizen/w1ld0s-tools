# w1ld0s-tools

Offensive-security scripts and the shell workflow that drives them — the toolkit half
of [w1ld0s](https://github.com/desterhuizen/w1ld0s).

`w1ld0s` provisions the workstation (apt packages, one pipx venv per Python CLI, Go
tools, wordlists, i3). This repo holds the operator-facing commands that live on top of
it: engagement state, enumeration wrappers, payload helpers, and offline cheatsheets.
The two are separate because the OS changes every two years and these scripts change
every week.

## Install

Under `w1ld0s`, nothing to do — `modules/90-tools.sh` clones this repo to
`~/tools/repos/w1ld0s-tools` and runs `setup_links`.

Standalone:

```bash
git clone https://github.com/desterhuizen/w1ld0s-tools.git ~/tools/repos/w1ld0s-tools
cd ~/tools/repos/w1ld0s-tools
./setup_links                                   # symlink executables into ~/.local/bin
echo 'source ~/tools/repos/w1ld0s-tools/aliases' >> ~/.zshrc
```

`setup_links` symlinks every executable file into `~/.local/bin`, stripping extensions
(`xfer_cmd/xfer_cmd.py` → `xfer_cmd`). `./setup_links -d` removes them. The executable
bit is load-bearing: a file is exported as a command **iff** it is executable, which is
why `aliases` is mode `0644`.

Cloning elsewhere is fine — export `W1LD0S_TOOLS_DIR` to point at the checkout and
`aliases`, `attack`, `common` and `scriptlist` all follow it.

## What's here

| | |
|---|---|
| `target/` | Per-engagement state. `target 10.10.11.42` writes `target/config/*.sh`; `aliases` sources them at shell startup so `$IP`, `$TARGET_BASE`, `$TARGET_NAME`, `$TARGET_LAB`, `$TARGET_VPN` are live in every shell. |
| `attack/` | The other half of that state — your own address per interface, for reverse shells and payload templates. |
| `aliases` | The shell surface: `$IP` and friends, plus the aliases and functions that use them (`my_scan`, `htricks`, `gtfo`, `getlinpeas`, …). Source it; don't execute it. |
| `common/` | `common` renders the offline cheatsheets under `common/content/` (AD, web, bof, wifi, log evasion, …) through `glow`. |
| `enum_scripts/`, `web_scan/`, `autorecon/` | Enumeration and scanning wrappers. |
| `payloads/`, `footholder/`, `msf_scripts/`, `xfer_cmd/`, `xss_server/`, `webserver/` | Foothold and delivery helpers. |
| `powershell/`, `windows_domain/`, `users/` | Windows and AD tooling. |
| `checklists/`, `log_analysis/`, `simple_sqlite_db/`, `simple_wp_plugin/` | Supporting odds and ends. |
| `scriptlist` | Enumerates everything above with descriptions. Start here. |
| `setup_workspace` | Builds the tmux/terminator/i3 layout for an engagement, with full pane logging. |

Runtime state (`target/config/`, `attack/attacker`) is gitignored — it is per-engagement
and never belongs in the repo.

## Requirements

Bash 4+ (for `mapfile`), `glow` for `common`, and `i3`/`terminator`/`tmux` for
`setup_workspace`. `w1ld0s` installs all of them. Individual scripts pull in their own
tools — `scriptlist -d <name>` shows what each one needs.

## License

AGPLv3 — see [LICENSE](LICENSE). Read [NOTICE](NOTICE) before use: this is an
offensive-security toolkit, and using it against systems you are not authorized to test
is a criminal offense in most jurisdictions.
