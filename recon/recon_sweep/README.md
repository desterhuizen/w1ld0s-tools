# recon_sweep

An external reconnaissance sweep over a domain: subdomain enumeration, live-host
checks, screenshots, technology fingerprinting, historical URLs, subdomain-takeover
checks, port and vulnerability scans, and directory brute forcing. Results land in a
timestamped directory named for the domain.

```bash
recon_sweep example.com
```

Published as `recon_sweep`, not `autorecon` — the original filename shadowed the
unrelated `autorecon` tool if that was also on `$PATH`.

## What it needs

This repo installs nothing; `w1ld0s` provisions the workstation. Check what is
present before a run:

```bash
command -v assetfinder amass httprobe gowitness whatweb waybackurls subjack nmap nuclei ffuf
```

Two data files the script also expects, both provisioned outside this repo:

- `/usr/share/subjack/fingerprints.json` — subdomain-takeover signatures.
- `/usr/share/wordlists/dirb/common.txt` — the directory brute-force list.

If either is missing the corresponding stage produces nothing useful. Everything else
degrades per-tool rather than aborting the sweep.
