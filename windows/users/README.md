# users

Adding an account you control, on either platform, plus one credential-attack helper.

| File                        | What it is                                                                                                                        |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `add_rroot.sh`              | Adds a UID 0 account on Linux. Published as the `add_rroot` command.                                                              |
| `create_user.bat`           | `net user` / `net localgroup administrators` one-liner for Windows.                                                               |
| `createUserWin.cpp`         | The same two `net` calls wrapped in a C program, for when you can drop and run a binary but not a batch file. Compile with mingw. |
| `ntlm_passwordspray.tar.gz` | See below.                                                                                                                        |

There used to be a `createUserLin.cpp` alongside `createUserWin.cpp`. It was
byte-identical to it — the same Windows `net user` calls — so it never built anything
usable on Linux. `add_rroot.sh` is the Linux path.

## ntlm_passwordspray.tar.gz

A gzipped tarball holding a single file, `ntlm_passwordspray.py` (~2.5KB): sprays a
password list against an NTLM-authenticating HTTP endpoint. Kept archived because it is
meant to be copied to a target or a jump host as one file, not run from here.

```bash
tar xzf ntlm_passwordspray.tar.gz
python3 ntlm_passwordspray.py -u usernames.txt -f <domain> -p <password> -a <url>
```

The same invocation appears in the AD cheatsheet — `common ad`.
