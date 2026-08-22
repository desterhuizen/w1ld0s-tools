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

Cloning elsewhere is fine — `attack`, `common` and `scriptlist` resolve their own
location through the `~/.local/bin` symlink, so they need no configuration. Exporting
`W1LD0S_TOOLS_DIR` to point at the checkout is an optional override, which those three
and `aliases` all follow.

Upgrading from the flat layout: the per-engagement state is gitignored, so it stays
behind at the old paths. Move it once, then re-link:

```bash
cd "${W1LD0S_TOOLS_DIR:-$HOME/tools/repos/w1ld0s-tools}"
[ -d target/config ] && mv target/config engagement/target/config
[ -f attack/attacker ] && mv attack/attacker engagement/attack/attacker
./setup_links -d && ./setup_links
```

## What's here

Six directories, named for the phase of work they serve. Nesting is invisible to the
commands themselves — `setup_links` publishes by basename — so it exists purely to make
the repo findable.

|               |                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `engagement/` | Per-engagement state. `target 10.10.11.42` writes `engagement/target/config/*.sh`; `aliases` re-reads them each prompt, so `$IP`, `$URL`, `$TARGET_BASE`, `$TARGET_NAME`, `$TARGET_LAB`, `$TARGET_VPN` are live in every shell, including open ones. `attack` is the other half — your own address per interface. `setup_workspace` builds the tmux/i3 layout, with full pane logging. |
| `recon/`      | Enumeration and scanning: `port_scan.sh`, `pingsweep.sh`, `enumcert`, `portlist`, plus the `autorecon/` and `web_scan/` wrappers.                                                                                                                                                                                                                                                      |
| `access/`     | Getting a shell: `payloads/`, `footholder/`, `msf_scripts/`, `xfer_cmd/`, macro tooling.                                                                                                                                                                                                                                                                                               |
| `infra/`      | Attacker-side services you stand up: `webserver/`, `xss_server/`, `simple_wp_plugin/`, `rsh_server`, `setup_www_tools`.                                                                                                                                                                                                                                                                |
| `windows/`    | Windows and AD tooling: `powershell/`, `windows_domain/`, `users/`, `log_analysis/`. Cuts across the phases above, by design.                                                                                                                                                                                                                                                          |
| `docs/`       | `common` renders the offline cheatsheets under `docs/common/content/` (AD, web, bof, wifi, log evasion, …) through `glow`. `docs/checklists/` holds the longer-form ones.                                                                                                                                                                                                              |

Checklists exist in three forms on purpose, because they are used at different
moments: `docs/common/content/check_lists/*.json` are Taskwarrior imports for tracking
a live engagement (`common -t win_priv`), `docs/common/content/web_checklist.md` is the
long OWASP reference you read, and `docs/checklists/` holds the standalone HTML page
you tick through in a browser.

At the root: `aliases` — the shell surface, `$IP` and friends plus the functions that use
them (`my_scan`, `htricks`, `gtfo`, `serve`, …); source it, don't execute it. It is a
loader; the aliases themselves live in `aliases.d/`, one file per area, loaded in
numeric order because `00-state.sh` exports what the rest read:

```text
00-state    target/attack config, $IP, $A_IP, _my_ip
10-recon    my_scan, /etc/hosts helpers, monitor_host
20-access   listeners, PowerShell encoding, DotNetToJScript, ysoserial
30-infra    serve, httptools, smb/ftp/http control
40-tunnels  vpn, ligolo, reverse ssh
50-time     clock alignment for Kerberos skew
60-research htricks, gtfo, platt
90-shell    navigation, git, single-letter shortcuts
```

Adding a fragment means adding its name to the list in `aliases` — the loader does not
glob, so that a checkout with no `aliases.d/` still starts a shell cleanly.

`scriptlist` enumerates everything above with descriptions — start there. `setup_links`
publishes the executables.

Runtime state (`engagement/target/config/`, `engagement/attack/attacker`) is gitignored —
it is per-engagement and never belongs in the repo.

## Requirements

Bash 4+ (for `mapfile`), `glow` for `common`, and `i3`/`terminator`/`tmux` for
`setup_workspace`. `w1ld0s` installs all of them. Individual scripts pull in their own
tools — `scriptlist -d <name>` shows what each one needs.

## Contributing

Changes reach `main` through `staging` — `feature/xyz` → PR → `staging` → PR →
`main` — because `main` is what the installs above clone. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the branch rules, the merge policy, and how
to run the CI linters locally.

## License

AGPLv3 — see [LICENSE](LICENSE). Read [NOTICE](NOTICE) before use: this is an
offensive-security toolkit, and using it against systems you are not authorized to test
is a criminal offense in most jurisdictions.
