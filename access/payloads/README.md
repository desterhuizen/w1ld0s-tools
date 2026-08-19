# payloads

Payload templates and the helpers that build them. Nothing here is published as a
command except `create_proxy.sh` and `generate_phase0.sh`; the rest are sources you
edit and stage.

| File | What it is |
| --- | --- |
| `shell_code_runner.ps1` | PowerShell shellcode runner, a direct port of the VBA version. See `shell_code_runner_readme.md` for the msfvenom line that feeds it. |
| `powershell_pure_memory.ps1` | Download-and-execute with nothing touching disk. |
| `proxy.ps1`, `create_proxy.sh` | Proxy-aware download stub and its generator. |
| `generate_phase0.sh` | Builds the first-stage dropper. |
| `office_payload_complete.doc` | See below. |

## office_payload_complete.doc

A Word document (Office 97-2003 / OLE compound file, ~170KB) carrying a working macro
dropper, kept as a reference for what a complete phishing artifact looks like — macro,
lure text and formatting together, rather than the macro alone.

It is deliberately **not executable**. `setup_links` publishes every executable file in
this repo as a command by basename, so a 0755 `.doc` became `office_payload_complete`
in `~/.local/bin` — a Word document on `$PATH`.

The macro fetches `stage0_final.ps1` from a hardcoded staging address, so it will not
work unmodified. Treat it as a template: open it, replace the address, re-save. It also
carries a filename check — the macro only runs when the document's own name matches an
encoded value baked into it. `check_macro.sh` (in `access/`) runs `olevba` over a doc
and tells you what that encoded name has to be for a given filename.

Live Office macro payloads trip antivirus and mail filters on sight. Do not commit new
ones; generate them per engagement.
