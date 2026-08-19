# Target Script - User Guide

The `target` script is a comprehensive tool for managing penetration testing projects. This guide explains how to use its various features.

## Basic Usage

### Viewing Current Configuration

Running the script without any arguments shows your current configuration:

```bash
target
```

Output example:
```
Target Base    : /home/user/pentest-projects
Target Name    : client-x
Target IP      : 192.168.1.1
Target URL     : http://192.168.1.1
Target VPN     : /home/user/vpns/client-x

Use 'target -h' for help
```

### Setting Target IP

To set a target IP address (this also automatically sets the URL):

```bash
target 192.168.1.1
```

### Setting Target Name

To assign a name to your target (useful for organization):

```bash
target -n client-x
```
or
```bash
target --name client-x
```

### Setting Target URL

To set a custom URL for the target:

```bash
target -u http://example.com
```
or
```bash
target --url http://example.com
```

## Managing Project Directories

### Creating a Project Directory

To create a new project directory with the default structure:

```bash
target -m
```
or
```bash
target --make
```

This creates a project directory using either the target name or IP address.

### Changing to the Project Directory

To navigate to the project directory:

```bash
target -c
```
or
```bash
target --change
```

If the directory doesn't exist, you'll be prompted to create it.

### Changing to the Base Directory

To navigate to the base directory where all projects are stored:

```bash
target -cb
```
or
```bash
target --change-base
```

### Setting a Custom Base Directory

To change where your penetration testing projects are stored:

```bash
target -b /path/to/directory
```
or
```bash
target --base /path/to/directory
```

### Setting the VPN Directory

To store the path to the VPN config directory for the current engagement (e.g. where your `.ovpn` files live):

```bash
target -v /path/to/vpn
```
or
```bash
target --vpn /path/to/vpn
```

Running `target -v` with no argument prints the currently configured VPN directory. If the directory doesn't exist you'll be prompted to create it. The path is persisted to `engagement/target/config/vpn.sh` as `TARGET_VPN`.

### Changing to the VPN Directory

To navigate to the configured VPN directory:

```bash
target -cv
```
or
```bash
target --change-vpn
```

## Working with Labs / Networks

For multi-host environments (e.g. HTB Pro Labs like Dante, or any engagement with several boxes on one network) you can set an optional **lab / network** layer. Projects then nest under the lab, and the lab root holds resources shared across every host.

### Setting a Lab

```bash
target -L dante
```

`-L` (or `--lab`) accepts `-N` / `--network` as synonyms. Setting a lab persists `TARGET_LAB` to `engagement/target/config/lab.sh` and offers to scaffold the lab root. Running `target -L` with no argument prints the current lab.

With a lab set, project paths become nested:

```
${TARGET_BASE}/${LAB}/${HOST}      e.g. ~/pentest-projects/dante/host-01
```

With no lab set, paths stay flat (`${TARGET_BASE}/${HOST}`) exactly as before — the lab layer is fully optional and backward compatible.

### Lab Root Structure

Scaffolding a lab creates shared, cross-host resources at the lab root:

```
dante/
├── README.md           # Lab overview
├── network.md          # Host inventory / network map (fill in as you enumerate)
├── credentials/        # Credentials reusable across hosts
├── loot/               # Loot gathered across hosts
├── vpn -> <TARGET_VPN> # Symlink to the (global) VPN config dir
├── host-01/            # Per-host project (full structure, created with target -m)
└── host-02/
```

### Changing to the Lab Directory

```bash
target -cl
```

`-cl` (or `--change-lab`, `-cn`) launches a new shell in the lab root.

### Clearing a Lab

To return to the flat single-host layout:

```bash
target -L -
```

## Additional Features

### Listing All Projects

To see all projects in your base directory:

```bash
target -l
```
or
```bash
target --list
```

When a lab is set, `-l` lists the hosts inside that lab (the shared `credentials/`, `loot/` and `vpn` entries are hidden). With no lab set, it lists the projects in the base directory and marks which entries are labs.

### Viewing Detailed Configuration

To see detailed information about your current configuration:

```bash
target -i
```
or
```bash
target --info
```

### Getting Help

To display the help menu:

```bash
target -h
```
or
```bash
target --help
```

## Project Structure

When you create a new project with `target -m`, the following structure is created:

```
project_name/
├── README.md           # Project documentation (write-if-absent)
├── notes.md            # Structured enumeration notes (see below)
├── scans/              # For scan results
├── exploits/           # For exploit code
├── files/              # For project files
├── notes/              # Longer-form notes
│   └── pentest_enumeration_checklist.md   # Per-host tick-box checklist
├── evidence/           # For evidence collection
├── credentials/        # For storing discovered credentials
├── users               # List of usernames
├── passwords           # List of passwords
├── words               # Custom wordlists
├── www -> /var/www/html    # Symlink to web root
└── smb -> ~/smbshare       # Symlink to SMB share
```

**`target -m` is idempotent and cannot destroy a file.** Re-running it on an existing project only adds what is missing. `notes.md`, `README.md` and the checklist copy are all write-if-absent, and `target` tells you when it leaves one alone. The only way to replace notes is `target -m --force-notes`, which renames the old file to `notes.md.<timestamp>.bak` first — it never deletes.

The checklist is a **copy**, not a symlink, precisely so you can tick its boxes: the ticks belong to this host and ship with its evidence, and nothing you write can dirty the repo or leak into another host's copy.

## Structured Notes

The point of `notes.md` is discipline, not storage. Boxes are rarely missed for lack of tools; they are missed for skipping enumeration and jumping to an exploit. So the file is built around one rule, printed in a banner at the top:

> **Do not exploit until section 2 (Anomalies) is populated.**

You have not earned an exploit until you can name one thing on the box that is *not* how it ships by default. An empty section 2 means enumeration is unfinished — it does not mean the box is hard.

Nothing in the script enforces this. It is a written artifact, and the enforcement is yours.

### The sections

| Section               | Holds                                                                              | Discipline                                                                           |
| --------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **0. Rules**          | Tick-box enumeration rules                                                         | Tick these before writing anything in section 3                                      |
| **1. Facts**          | Ports, versions, hostnames, usernames, emails, paths, tech stack, odd HTTP headers | Verbatim only. What the box literally told you. No interpretation                    |
| **2. Anomalies**      | Deviations from a default install                                                  | A stock nginx page is not an anomaly. A stock nginx page serving `/backup/` is       |
| **3. Hypotheses**     | anomaly → candidate attack path → what would prove or kill it                      | Nothing here that is not traceable to a line in section 2                            |
| **4. Tried / failed** | What you tried and **why** it failed                                               | "Didn't work" is not a reason. The reason is what stops you repeating it at hour six |

Section 0 carries the rules that catch the usual misses — full `-p-` before any `-sCV`, every hostname into `/etc/hosts` and then vhost-fuzzed, page source and every JS file read by hand before any directory brute force, and a fresh enumeration pass after **every** credential found.

### Appending from the shell

Four flags append a timestamped entry to the end of the matching section:

```bash
target -F "80/tcp nginx 1.18.0 (Ubuntu)"          # 1. Facts
target -A "nginx default page but /backup/ is listable"   # 2. Anomalies
target -H "guess /backup/ contents -> creds"      # 3. Hypotheses
target -X "--script vuln returned nothing"        # 4. Tried / failed
```

Long forms are `--fact`, `--anomaly`, `--hypothesis`, `--tried`.

Details worth knowing:

- The entry lands at the **end of its section**, not the end of the file, so the sections stay ordered as you work.
- Text is taken verbatim and never re-parsed, so **leading dashes are safe** — `target -X "--script vuln ..."` and `target -X "-p- was slow"` both work.
- Quoting is optional for simple text: `target -F 22/tcp OpenSSH 8.9p1` works.
- One leading markdown bullet is absorbed, so `target -F "- 445/tcp Samba"` doesn't render as a double bullet.
- Multi-line text is kept as a single list item with indented continuation lines.
- The flags resolve the host through the same path logic as `-c` and `-m`, so they respect the lab layer automatically.

If `notes.md` is missing, or you have renamed one of the `## N.` headings, `target` refuses and tells you which — it never appends blindly to the end of the file. Writes are atomic, so an interrupted append can never leave a truncated `notes.md`.

### Customizing the template

The template is `engagement/target/templates/host-notes.md`. Edit it freely — the placeholders `{{HOST}}`, `{{IP}}`, `{{URL}}`, `{{LAB}}`, `{{VPN}}` and `{{DATE}}` are substituted at creation. Anything else, including shell `$` and `${...}`, is left alone.

Keep the `## N.` headings intact, or the append commands cannot find their sections.

## Environment variables in your shell

`aliases` sources the state files at shell startup, which exports:

```
$IP  $URL  $TARGET_BASE  $TARGET_NAME  $TARGET_LAB  $TARGET_VPN
```

Other scripts rely on these — `setup_workspace` requires `TARGET_BASE` and `TARGET_NAME`, and the `my_scan` helpers use `$IP`.

These are read **at shell startup**, so after changing the target with `target <IP>`, an already-open shell keeps the old value until you re-source or open a new one. `target -c` starts a fresh shell, so it always sees current values.

## Workflow Examples

### Complete Workflow Example

```bash
# Set the target IP
target 192.168.1.1

# Set a friendly name
target -n client-x

# Create the project structure
target -m

# Change to the project directory
target -c

# Now you're in the project directory ready to work
```

### Working with Multiple Targets

```bash
# Set first target
target 192.168.1.1
target -n client-1
target -m

# Set second target
target 192.168.1.2
target -n client-2
target -m

# List all projects
target -l

# Switch to first target
target -n client-1
target -c
```

### Working with a Lab / Network (multiple hosts)

```bash
# Create the lab once (scaffolds shared dirs + network map)
target -L dante

# First host under the lab
target 10.10.110.10
target -n host-01
target -m

# Second host under the same lab
target 10.10.110.11
target -n host-02
target -m

# List the hosts in the lab
target -l

# Jump to the lab root (shared creds / loot / network.md)
target -cl

# Jump to a specific host
target -n host-01
target -c

# Done with the lab — back to flat single-host mode
target -L -
```

## Tips and Tricks

1. **Custom Project Structure**: Edit `engagement/target/config/config.toml` to customize the default project structure — see `setup.md` for the schema. (This used to be a bash `config.sh`; it is migrated automatically on first run.)

2. **Shell Integration**: The `-c`, `-cb`, `-cv` and `-cl` options launch a new shell in the target directory. When you exit this shell, you'll return to your previous location.

3. **Multiple Projects**: You can easily switch between projects by changing the target name or IP before using the `-c` option.

4. **URL Customization**: While the URL is set automatically based on the IP, you can customize it with the `-u` option.

5. **Path Expansion**: When setting a base directory with `-b` or a VPN directory with `-v`, you can use `~` to reference your home directory.
