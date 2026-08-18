#!/usr/bin/env python3
"""target - a penetration testing project management tool.

Manages per-engagement state (IP, name, URL, lab, VPN) and scaffolds the
project tree for each host, including a structured notes.md.

Python port of the original bash implementation, kept for rollback at
target/legacy/target.bash. The five state files keep their shell-sourceable
`export X="..."` format so both implementations remain hot-swappable and so
aliases can source them at shell startup.
"""
# CLAUDE.md prefers a standalone executable over a package, so this is one
# file by design.
# pylint: disable=too-many-lines,consider-using-f-string

import datetime
import ipaddress
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

if sys.version_info < (3, 11):
    sys.stderr.write(
        "target requires Python 3.11 or newer (tomllib). Found %s.\n"
        % sys.version.split()[0]
    )
    raise SystemExit(1)

# Must follow the version guard above, or a 3.10 box gets an ImportError
# traceback instead of the message.
import tomllib  # noqa: E402  # pylint: disable=wrong-import-position

# --------------------------------------------------------------------------
# Messaging (same ANSI codes as the bash implementation)
# --------------------------------------------------------------------------

STATE_FILES = ("targ", "base", "name", "vpn", "lab")

NOTES_SECTIONS = {
    1: "Facts",
    2: "Anomalies",
    3: "Hypotheses",
    4: "Tried / failed",
}


def error_exit(msg, code=1):
    """Print an error and terminate, matching the bash error_exit()."""
    sys.stderr.write("\033[1;31mERROR:\033[0m %s\n" % msg)
    raise SystemExit(code)


def success(msg):
    print("\033[1;32mSUCCESS:\033[0m %s" % msg)


def info(msg):
    print("\033[1;34mINFO:\033[0m %s" % msg)


def warn(msg):
    sys.stderr.write("\033[1;33mWARNING:\033[0m %s\n" % msg)


def confirm(question, default=False):
    """Ask a y/n question. Non-interactive callers get `default` silently."""
    if not sys.stdin.isatty():
        return default
    try:
        answer = input("%s " % question)
    except (EOFError, KeyboardInterrupt):
        print()
        return default
    return answer.strip().lower().startswith("y")


# --------------------------------------------------------------------------
# Shell + TOML serialisation
# --------------------------------------------------------------------------

def sh_quote(value):
    """Quote a value for `export X="..."` in a sourced shell file."""
    out = str(value or "")
    for char in ("\\", '"', "$", "`"):
        out = out.replace(char, "\\" + char)
    return '"%s"' % out


def toml_str(value):
    out = str(value).replace("\\", "\\\\").replace('"', '\\"')
    out = out.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return '"%s"' % out


_BARE_KEY_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def toml_key(key):
    """Bare key where TOML allows it, quoted otherwise.

    Symlink sources are paths, so `/var/www/html` must be quoted or the
    resulting file will not parse.
    """
    key = str(key)
    return key if _BARE_KEY_RE.match(key) else toml_str(key)


def toml_dump(data):
    """Minimal TOML emitter: scalars, string lists and string->string tables.

    There is no TOML writer in the stdlib and CLAUDE.md forbids pip
    dependencies, so this covers exactly the shapes config.toml needs.
    Sub-tables are emitted after their parent's bare keys, as TOML requires.
    """
    lines = []

    def emit_pair(key, value):
        name = toml_key(key)
        if isinstance(value, bool):
            lines.append("%s = %s" % (name, "true" if value else "false"))
        elif isinstance(value, int):
            lines.append("%s = %d" % (name, value))
        elif isinstance(value, (list, tuple)):
            body = ", ".join(toml_str(item) for item in value)
            lines.append("%s = [%s]" % (name, body))
        else:
            lines.append("%s = %s" % (name, toml_str(value)))

    def emit_table(name, table):
        if name:
            lines.append("")
            lines.append("[%s]" % name)
        for key, value in table.items():
            if not isinstance(value, dict):
                emit_pair(key, value)
        for key, value in table.items():
            if isinstance(value, dict):
                child = toml_key(key)
                emit_table("%s.%s" % (name, child) if name else child, value)

    emit_table("", data)
    return "\n".join(lines).lstrip("\n") + "\n"


def atomic_write(path, data, mode=None):
    """Write via a same-directory temp file + rename, so readers never see
    a truncated file if we crash or the disk fills mid-write."""
    tmp = path.with_name(path.name + ".target-tmp")
    tmp.write_text(data, encoding="utf-8")
    if mode is not None:
        os.chmod(tmp, mode)
    elif path.exists():
        shutil.copymode(path, tmp)
    os.replace(tmp, path)


# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------

DEFAULT_CONFIG = {
    "version": 1,
    "project": {
        "dirs": ["scans", "exploits", "files", "notes", "evidence",
                 "credentials"],
        "files": ["users", "passwords", "words"],
        "symlinks": {"/var/www/html": "www", "~/smbshare": "smb"},
    },
    "notes": {
        "enabled": True,
        "filename": "notes.md",
        "template": "templates/host-notes.md",
    },
    "checklists": {
        "dest": "notes",
        "copy": ["../checklists/pentest_enumeration_checklist.md"],
    },
    "lab": {"dirs": ["credentials", "loot"]},
}

_DECLARE_SCRIPT = """
source "$1" >/dev/null 2>&1 || exit 3
declare -p PROJECT_DIRS PROJECT_FILES PROJECT_SYMLINKS 2>/dev/null
"""

_DECL_RE = re.compile(r"^declare\s+-\S+\s+(?P<name>\w+)=\((?P<body>.*)\)$",
                      re.S)


def read_legacy_config(path):
    """Read bash arrays out of a legacy config.sh, or None if we cannot.

    Evaluated with bash rather than regexed: install.md documented
    `PROJECT_DIRS+=(...)` and `PROJECT_SYMLINKS["/p"]="d"` as the
    customization idiom, and neither survives a naive regex. This is not a
    new trust boundary -- the bash implementation sourced this same file on
    every single invocation.
    """
    if not shutil.which("bash"):
        return None
    try:
        proc = subprocess.run(
            ["bash", "-c", _DECLARE_SCRIPT, "target-migrate", str(path)],
            capture_output=True, text=True, timeout=10, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        return None

    out = {}
    chunks = re.findall(r"^declare .*?(?=^declare |\Z)", proc.stdout,
                        re.M | re.S)
    for chunk in chunks:
        match = _DECL_RE.match(chunk.strip())
        if not match:
            continue
        items = []
        try:
            tokens = shlex.split(match.group("body"))
        except ValueError:
            continue
        for token in tokens:
            if token.startswith("["):
                key, sep, val = token[1:].partition("]=")
                if sep:
                    items.append((key, val))
                    continue
            items.append((None, token))
        out[match.group("name")] = items
    return out or None


def invocation_dir():
    """Reproduce how the bash version resolved its own directory.

    `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd` does not follow symlinks, so
    invoking ~/.local/bin/target put the config in ~/.local/bin/config. We
    need that path to find and adopt existing state.
    """
    invoked = sys.argv[0]
    if os.sep in invoked:
        return Path(invoked).parent
    found = shutil.which(invoked)
    return Path(found).parent if found else None


class Config:
    """Engagement state plus project-structure settings."""

    def __init__(self, config_dir):
        self.dir = Path(config_dir)
        self.script_dir = Path(__file__).resolve().parent
        self.ip = ""
        self.url = ""
        self.base = str(Path.home() / "pentest-projects")
        self.name = ""
        self.vpn = ""
        self.lab = ""
        self.settings = {}

    # -- resolution ------------------------------------------------------

    @staticmethod
    def resolve_dir():
        """Pick the config directory, adopting pre-port state if needed."""
        override = os.environ.get("TARGET_CONFIG_DIR")
        if override:
            path = Path(override).expanduser()
            path.mkdir(parents=True, exist_ok=True)
            return path

        # .resolve() is the fix for the original bug: the canonical config
        # belongs next to the real script, not next to the PATH symlink.
        canonical = Path(__file__).resolve().parent / "config"
        if canonical.is_dir() and any(canonical.iterdir()):
            return canonical

        candidates = []
        invoked = invocation_dir()
        if invoked is not None:
            candidates.append(invoked / "config")
        candidates.append(Path.home() / ".local" / "bin" / "config")

        for legacy in candidates:
            try:
                if legacy.resolve() == canonical.resolve():
                    continue
            except OSError:
                continue
            if not legacy.is_dir():
                continue
            found = [f for f in legacy.iterdir() if f.is_file()]
            if not found:
                continue
            canonical.mkdir(parents=True, exist_ok=True)
            for src in found:
                dst = canonical / src.name
                if dst.exists():
                    continue
                shutil.copy2(src, dst)
                os.chmod(dst, 0o600)
            info("adopted existing config from %s" % legacy)
            info("      (the bash version resolved its own path through the "
                 "~/.local/bin symlink;")
            info("       the canonical location is now %s)" % canonical)
            info("originals left in place -- delete them once you are happy:")
            info("      rm -rf %s" % legacy)
            return canonical

        canonical.mkdir(parents=True, exist_ok=True)
        return canonical

    # -- state files -----------------------------------------------------

    def _read_exports(self, filename):
        """Parse `export KEY="value"` lines out of a state file."""
        path = self.dir / filename
        values = {}
        if not path.is_file():
            return values
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            warn("cannot read %s: %s" % (path, exc))
            return values
        for line in text.splitlines():
            line = line.strip()
            if not line.startswith("export "):
                continue
            key, _, raw = line[len("export "):].partition("=")
            key = key.strip()
            if not key:
                continue
            try:
                parts = shlex.split(raw, posix=True)
            except ValueError:
                parts = [raw.strip().strip('"').strip("'")]
            values[key] = parts[0] if parts else ""
        return values

    def _write_export(self, filename, pairs):
        body = "".join("export %s=%s\n" % (k, sh_quote(v)) for k, v in pairs)
        atomic_write(self.dir / filename, body, mode=0o600)

    @classmethod
    def load(cls):
        cfg = cls(cls.resolve_dir())
        cfg.migrate()

        targ = cfg._read_exports("targ.sh")
        cfg.ip = targ.get("IP", "")
        cfg.url = targ.get("URL", "")
        cfg.base = cfg._read_exports("base.sh").get("TARGET_BASE", "") \
            or str(Path.home() / "pentest-projects")
        cfg.name = cfg._read_exports("name.sh").get("TARGET_NAME", "")
        cfg.vpn = cfg._read_exports("vpn.sh").get("TARGET_VPN", "")
        cfg.lab = cfg._read_exports("lab.sh").get("TARGET_LAB", "")

        # Ensure every state file exists so aliases always has
        # something readable to source.
        for stem in STATE_FILES:
            if not (cfg.dir / ("%s.sh" % stem)).is_file():
                cfg.save(stem)
        return cfg

    def save(self, which):
        if which == "targ":
            self._write_export("targ.sh", [("IP", self.ip), ("URL", self.url)])
        elif which == "base":
            self._write_export("base.sh", [("TARGET_BASE", self.base)])
        elif which == "name":
            self._write_export("name.sh", [("TARGET_NAME", self.name)])
        elif which == "vpn":
            self._write_export("vpn.sh", [("TARGET_VPN", self.vpn)])
        elif which == "lab":
            self._write_export("lab.sh", [("TARGET_LAB", self.lab)])

    # -- structure config ------------------------------------------------

    def migrate(self):
        """Create config.toml, converting a legacy config.sh if present."""
        toml_path = self.dir / "config.toml"
        legacy = self.dir / "config.sh"

        if toml_path.is_file():
            self.settings = self._load_toml(toml_path)
            return

        data = {k: (dict(v) if isinstance(v, dict) else v)
                for k, v in DEFAULT_CONFIG.items()}
        data["project"] = {k: (dict(v) if isinstance(v, dict) else list(v))
                           for k, v in DEFAULT_CONFIG["project"].items()}

        if legacy.is_file():
            parsed = read_legacy_config(legacy)
            if parsed is None:
                warn("could not evaluate %s -- writing default settings "
                     "instead." % legacy)
                warn("Your customization was NOT migrated and %s was left "
                     "untouched." % legacy.name)
                warn("Hand-port it into %s: PROJECT_DIRS -> [project].dirs, "
                     "PROJECT_FILES -> [project].files," % toml_path)
                warn("PROJECT_SYMLINKS -> [project.symlinks].")
            else:
                dirs = [v for _, v in parsed.get("PROJECT_DIRS", [])]
                files = [v for _, v in parsed.get("PROJECT_FILES", [])]
                links = {k: v for k, v in parsed.get("PROJECT_SYMLINKS", [])
                         if k is not None}
                if dirs:
                    data["project"]["dirs"] = dirs
                if files:
                    data["project"]["files"] = files
                if links:
                    data["project"]["symlinks"] = links

                notes_name = data["notes"]["filename"]
                if notes_name in data["project"]["files"]:
                    data["project"]["files"] = [
                        f for f in data["project"]["files"] if f != notes_name
                    ]
                    info("%s removed from [project].files -- it is now "
                         "generated from %s"
                         % (notes_name, data["notes"]["template"]))

                backup = self.dir / "config.legacy.sh"
                try:
                    # Keep the .sh suffix: .gitignore matches
                    # target/config/*.sh, and a .bak name would show up
                    # untracked in git status.
                    os.replace(legacy, backup)
                    os.chmod(backup, 0o600)
                    info("legacy config backed up to %s" % backup)
                except OSError as exc:
                    warn("could not back up %s: %s" % (legacy, exc))

        atomic_write(toml_path, toml_dump(data), mode=0o600)
        self.settings = data

    def _load_toml(self, path):
        try:
            with open(path, "rb") as handle:
                data = tomllib.load(handle)
        except (OSError, tomllib.TOMLDecodeError) as exc:
            warn("cannot read %s (%s) -- using defaults." % (path, exc))
            return dict(DEFAULT_CONFIG)

        merged = {}
        for key, default in DEFAULT_CONFIG.items():
            value = data.get(key, default)
            if isinstance(default, dict) and isinstance(value, dict):
                merged[key] = {**default, **value}
            else:
                merged[key] = value

        # Defensive: notes.md must never also be in [project].files, or the
        # plain-file loop races the notes generator.
        notes_name = merged["notes"]["filename"]
        files = merged["project"].get("files", [])
        if notes_name in files:
            merged["project"]["files"] = [f for f in files if f != notes_name]
            warn("%s is listed in [project].files; ignoring it (it is "
                 "generated from the notes template)." % notes_name)
        return merged

    # -- derived paths ---------------------------------------------------

    def host_path(self, host=None):
        host = host or self.name or self.ip
        if self.lab:
            return Path(self.base) / self.lab / host
        return Path(self.base) / host

    def lab_path(self):
        return Path(self.base) / self.lab


def validate_ip(text):
    """True for a dotted-quad IPv4 address.

    Stricter than the old bash regex: ipaddress rejects leading zeros, so
    `010.1.1.1` (which bash accepted and which some tools read as octal) is
    now an error. That is deliberate.
    """
    try:
        ipaddress.IPv4Address(text)
    except ValueError:
        return False
    return True


# --------------------------------------------------------------------------
# Notes
# --------------------------------------------------------------------------

_PLACEHOLDER = re.compile(r"\{\{([A-Z0-9_]+)\}\}")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
HEADING_RE = re.compile(r"^##\s")        # '###' does not match: subheadings
BULLET_RE = re.compile(r"^[-*+]\s+")     # stay inside their parent section


class NotesError(Exception):
    """Operator-facing notes failure; the message is printed verbatim."""


def render_template(text, values):
    """Substitute {{TOKEN}}. Unknown tokens are left verbatim, never raised.

    Deliberately not string.Template: the template is full of intentional
    shell `$` (`nmap -p- $IP`, `${TARGET_BASE}`) that safe_substitute would
    rewrite. Only a literal {{UPPER_NAME}} is touched here.
    """
    return _PLACEHOLDER.sub(
        lambda m: str(values.get(m.group(1), m.group(0))), text
    )


def _section_re(number):
    # matches "## 1. Facts" and "## 01 Facts", but not "## 10. ..."
    return re.compile(r"^##\s+0*%d(?![0-9])" % number)


def append_to_section(path, number, title, text, now=None):
    """Insert a timestamped entry at the END of section `number` of `path`."""
    text = text.strip()
    if not text:
        raise NotesError("Refusing to append an empty note.")

    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise NotesError(
            "No notes file at %s\n"
            "Run 'target -m' to scaffold the host project and its notes.md "
            "first." % path
        ) from None
    except OSError as exc:
        raise NotesError("Cannot read %s: %s" % (path, exc)) from None

    lines = raw.split("\n")
    if raw.endswith("\n"):
        lines.pop()                       # drop the artefact of the final \n

    heading_re = _section_re(number)
    start = end = None
    in_fence = False
    for index, line in enumerate(lines):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:                      # the GATE banner is fenced
            continue
        if start is None:
            if heading_re.match(line):
                start = index
        elif HEADING_RE.match(line):
            end = index
            break

    if start is None:
        raise NotesError(
            "Section '## %d. %s' not found in %s\n"
            "The heading was renamed or deleted. Restore it (see "
            "target/templates/host-notes.md) or move notes.md aside and "
            "re-run 'target -m'." % (number, title, path)
        )
    if end is None:
        end = len(lines)                  # section runs to EOF

    insert = end
    while insert > start + 1 and not lines[insert - 1].strip():
        insert -= 1

    stamp = (now or datetime.datetime.now()).strftime("%Y-%m-%d %H:%M")
    body = text.split("\n")
    # Absorb one leading markdown bullet so "- foo" doesn't render as
    # "- <ts> - foo". BULLET_RE requires whitespace after the marker, so
    # "--script vuln" and "-p- was slow" are left alone.
    body[0] = BULLET_RE.sub("", body[0], count=1)
    entry = ["- `%s` %s" % (stamp, body[0].rstrip())]
    entry += ["  " + extra.rstrip() for extra in body[1:]]

    # Separate the entry list from whatever precedes it. Continuing an
    # existing list needs no blank line; starting one after the section's
    # heading or its blockquote preamble does.
    if insert == start + 1:               # section body was empty
        entry.insert(0, "")
    else:
        previous = lines[insert - 1]
        if not (BULLET_RE.match(previous) or previous.startswith((" ", "\t"))):
            entry.insert(0, "")
    lines[insert:insert] = entry
    after = insert + len(entry)
    if after < len(lines) and lines[after].strip():
        lines.insert(after, "")           # one blank before the next heading

    atomic_write(path, "\n".join(lines) + "\n")
    return "\n".join(e for e in entry if e)


def write_host_notes(cfg, project_path, force=False):
    """Scaffold notes.md from the template. Never overwrites silently."""
    notes_cfg = cfg.settings.get("notes", DEFAULT_CONFIG["notes"])
    if not notes_cfg.get("enabled", True):
        return

    dest = project_path / notes_cfg.get("filename", "notes.md")
    if dest.exists():
        if not force:
            info("%s exists -- left untouched" % dest.name)
            return
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = dest.with_name("%s.%s.bak" % (dest.name, stamp))
        os.replace(dest, backup)
        info("existing notes backed up to %s" % backup.name)

    template = cfg.script_dir / notes_cfg.get(
        "template", "templates/host-notes.md")
    try:
        body = template.read_text(encoding="utf-8")
    except OSError as exc:
        warn("cannot read notes template %s: %s" % (template, exc))
        return

    values = {
        "HOST": project_path.name,
        "IP": cfg.ip or "not set",
        "URL": cfg.url or "not set",
        "LAB": cfg.lab or "none",
        "VPN": cfg.vpn or "not set",
        "DATE": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
    }
    atomic_write(dest, render_template(body, values), mode=0o600)
    success("notes scaffolded at %s" % dest)


def copy_checklists(cfg, project_path):
    """Copy tick-box checklists into the host tree (per-host mutable state)."""
    settings = cfg.settings.get("checklists", DEFAULT_CONFIG["checklists"])
    sources = settings.get("copy", [])
    if not sources:
        return
    dest_dir = project_path / settings.get("dest", "notes")
    dest_dir.mkdir(parents=True, exist_ok=True)
    for rel in sources:
        src = (cfg.script_dir / rel).resolve()
        if not src.is_file():
            warn("checklist not found, skipped: %s" % src)
            continue
        dest = dest_dir / src.name
        if dest.exists():
            info("%s exists -- left untouched" % dest.name)
            continue
        shutil.copy2(src, dest)
        info("checklist copied to %s" % dest)


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

def spawn_shell(path, title=""):
    """cd into `path` and replace this process with an interactive shell."""
    info("Changing to: %s" % path)
    try:
        os.chdir(path)
    except OSError as exc:
        error_exit("Failed to change directory to %s: %s" % (path, exc))
    if title:
        os.environ["TITLE"] = title
    shell = os.environ.get("SHELL") or "/bin/sh"
    try:
        os.execvp(shell, [shell])         # never returns
    except OSError as exc:
        error_exit("Failed to start shell %s: %s" % (shell, exc))


def create_lab(cfg):
    """Scaffold the shared lab root. Idempotent; never clobbers."""
    if not cfg.lab:
        return
    lab_path = cfg.lab_path()
    created = not lab_path.is_dir()

    for name in cfg.settings.get("lab", DEFAULT_CONFIG["lab"])["dirs"]:
        try:
            (lab_path / name).mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            error_exit("Failed to create lab %s directory: %s" % (name, exc))

    if cfg.vpn:
        link_path(Path(cfg.vpn), lab_path / "vpn")

    network = lab_path / "network.md"
    if not network.exists():
        network.write_text(
            "# Network Map: %s\n\n"
            "- Created: %s\n"
            "- VPN: %s\n\n"
            "## Hosts\n\n"
            "| Host | IP | Role | Creds | Notes |\n"
            "|------|----|------|-------|-------|\n"
            "|      |    |      |       |       |\n\n"
            "## Pivots / Routes\n\n-\n"
            % (cfg.lab, datetime.datetime.now().strftime("%c"),
               cfg.vpn or "Not set"),
            encoding="utf-8",
        )

    readme = lab_path / "README.md"
    if not readme.exists():
        readme.write_text(
            "# Lab / Network: %s\n\n"
            "- Created: %s\n"
            "- VPN: %s\n\n"
            "Shared, cross-host resources for this lab live here:\n\n"
            "- `credentials/` - creds reusable across hosts\n"
            "- `loot/` - loot gathered across hosts\n"
            "- `network.md` - host inventory / network map\n"
            "- `vpn` - symlink to the lab VPN config dir\n\n"
            "Each host is its own subdirectory (`target -m`).\n"
            % (cfg.lab, datetime.datetime.now().strftime("%c"),
               cfg.vpn or "Not set"),
            encoding="utf-8",
        )

    if created:
        success("Lab created at: %s" % lab_path)


def link_path(source, dest):
    """Create dest -> source, without the `ln -sf` directory trap.

    `ln -sf /var/www/html proj/www` where proj/www is an existing directory
    silently creates proj/www/html instead of replacing the link.
    """
    if not source.exists():
        info("Symlink source does not exist, skipped: %s" % source)
        return
    if dest.is_symlink():
        try:
            if os.readlink(dest) == str(source):
                return
            dest.unlink()
        except OSError as exc:
            info("Failed to replace symlink %s: %s" % (dest, exc))
            return
    elif dest.exists():
        info("%s exists and is not a symlink -- skipped" % dest)
        return
    try:
        os.symlink(source, dest)
    except OSError as exc:
        info("Failed to create symlink to %s: %s" % (source, exc))


def create_project(cfg, host, force_notes=False):
    create_lab(cfg)
    project_path = cfg.host_path(host)

    if project_path.is_dir():
        # The old prompt said "overwrite" but answering y deleted nothing --
        # it re-ran mkdir/touch/ln. Say what actually happens.
        info("Project directory already exists at: %s" % project_path)
        if not confirm("Re-run scaffolding into it? (y/n):", default=True):
            info("Project creation canceled.")
            return

    try:
        project_path.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        error_exit("Failed to create project directory: %s" % exc)

    project = cfg.settings.get("project", DEFAULT_CONFIG["project"])
    for name in project.get("dirs", []):
        try:
            (project_path / name).mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            error_exit("Failed to create %s directory: %s" % (name, exc))

    for source, dest in project.get("symlinks", {}).items():
        link_path(Path(os.path.expanduser(source)), project_path / dest)

    for name in project.get("files", []):
        try:
            (project_path / name).touch()   # does not truncate
        except OSError as exc:
            info("Failed to create %s: %s" % (name, exc))

    readme = project_path / "README.md"
    if readme.exists():
        # Was rewritten unconditionally before, destroying anything the
        # operator added under its own "## Notes" heading.
        info("README.md exists -- left untouched (delete it and re-run -m "
             "to regenerate)")
    else:
        readme.write_text(
            "# Penetration Testing Project: %s\n\n"
            "## Project Information\n"
            "- Lab / Network: %s\n"
            "- Target Name: %s\n"
            "- Target IP: %s\n"
            "- Target URL: %s\n"
            "- Created: %s\n\n"
            "## Directory Structure\n"
            "%s\n\n"
            "## Notes\n"
            "Enumeration notes live in `notes.md` (four sections, gated).\n"
            % (host, cfg.lab or "none", cfg.name, cfg.ip, cfg.url,
               datetime.datetime.now().strftime("%c"),
               "\n".join("- %s/" % d for d in project.get("dirs", []))),
            encoding="utf-8",
        )

    write_host_notes(cfg, project_path, force=force_notes)
    copy_checklists(cfg, project_path)
    success("Project created successfully at: %s" % project_path)


def cmd_status(cfg, _rest=None):
    print("Target Base\t: %s" % (cfg.base or "Not set"))
    print("Target Lab\t: %s" % (cfg.lab or "Not set"))
    print("Target Name\t: %s" % (cfg.name or "Not set"))
    print("Target IP\t: %s" % (cfg.ip or "Not set"))
    print("Target URL\t: %s" % (cfg.url or "Not set"))
    print("Target VPN\t: %s" % (cfg.vpn or "Not set"))
    print("\nUse 'target -h' for help")


def cmd_info(cfg, _rest):
    print("Target Configuration:")
    print("--------------------")
    print("Base Directory: %s" % cfg.base)
    print("Target Lab:     %s" % (cfg.lab or "Not set"))
    print("Target Name:    %s" % (cfg.name or "Not set"))
    print("Target IP:      %s" % (cfg.ip or "Not set"))
    print("Target URL:     %s" % (cfg.url or "Not set"))
    print("VPN Directory:  %s" % (cfg.vpn or "Not set"))
    print("Config Dir:     %s" % cfg.dir)
    print("Project Path:   %s" % cfg.host_path())


def cmd_change(cfg, _rest):
    host = cfg.name or cfg.ip
    if not host:
        error_exit("No target name or IP set. Use 'target IP' or "
                   "'target -n NAME' first.")
    project_path = cfg.host_path(host)
    if not project_path.is_dir():
        info("Project directory does not exist: %s" % project_path)
        if not confirm("Would you like to create it now? (y/n):"):
            return 0
        create_project(cfg, host)
    spawn_shell(project_path, title=host)   # execs; does not return
    return 0


def cmd_change_base(cfg, _rest):
    spawn_shell(Path(cfg.base), title=cfg.name or cfg.ip)


def cmd_change_vpn(cfg, _rest):
    if not cfg.vpn:
        error_exit("No VPN directory set. Use 'target -v /path/to/vpn' first.")
    if not Path(cfg.vpn).is_dir():
        error_exit("VPN directory does not exist: %s" % cfg.vpn)
    spawn_shell(Path(cfg.vpn), title=cfg.name or cfg.ip)


def cmd_change_lab(cfg, _rest):
    if not cfg.lab:
        error_exit("No lab set. Use 'target -L NAME' first.")
    lab_path = cfg.lab_path()
    if not lab_path.is_dir():
        info("Lab directory does not exist: %s" % lab_path)
        if not confirm("Would you like to create it now? (y/n):"):
            return 0
        create_lab(cfg)
    spawn_shell(lab_path, title=cfg.lab)    # execs; does not return
    return 0


def cmd_make(cfg, rest):
    force = "--force-notes" in rest
    host = cfg.name or cfg.ip
    if not host:
        error_exit("No target name or IP set. Use 'target IP' or "
                   "'target -n NAME' first.")
    create_project(cfg, host, force_notes=force)
    return 0


def cmd_base(cfg, rest):
    if not rest:
        info("Current base directory: %s" % cfg.base)
        info("To change base directory, use: target -b /path/to/directory")
        return 0
    new_base = Path(os.path.expanduser(rest[0]))
    if not new_base.is_dir():
        if not confirm("Directory does not exist. Create it? (y/n):"):
            error_exit("Base directory change canceled.")
        try:
            new_base.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            error_exit("Failed to create directory: %s" % exc)
    cfg.base = str(new_base)
    cfg.save("base")
    success("Base directory set to: %s" % cfg.base)
    return 0


def cmd_vpn(cfg, rest):
    if not rest:
        info("Current VPN directory: %s" % (cfg.vpn or "Not set"))
        info("To change VPN directory, use: target -v /path/to/directory")
        return 0
    new_vpn = Path(os.path.expanduser(rest[0]))
    if not new_vpn.is_dir():
        if not confirm("Directory does not exist. Create it? (y/n):"):
            error_exit("VPN directory change canceled.")
        try:
            new_vpn.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            error_exit("Failed to create directory: %s" % exc)
    cfg.vpn = str(new_vpn)
    cfg.save("vpn")
    success("VPN directory set to: %s" % cfg.vpn)
    return 0


def cmd_lab(cfg, rest):
    if not rest:
        info("Current lab/network: %s" % (cfg.lab or "Not set"))
        info("To set a lab, use: target -L NAME   (use '-' to clear)")
        return 0
    value = rest[0]
    if value in ("-", "none"):
        cfg.lab = ""
        cfg.save("lab")
        success("Lab cleared. Projects will use flat layout: ${BASE}/${HOST}")
        return 0
    cfg.lab = value
    cfg.save("lab")
    success("Lab/network set to: %s" % cfg.lab)
    if not cfg.lab_path().is_dir():
        if confirm("Lab directory does not exist. Create it now? (y/n):"):
            create_lab(cfg)
    return 0


def cmd_name(cfg, rest):
    if not rest:
        error_exit("No name provided. Usage: target -n NAME")
    cfg.name = rest[0]
    cfg.save("name")
    success("Target name set to: %s" % cfg.name)
    return 0


def cmd_url(cfg, rest):
    if not rest:
        error_exit("No URL provided. Usage: target -u URL")
    cfg.url = rest[0]
    cfg.save("targ")
    success("Target URL set to: %s" % cfg.url)
    return 0


def cmd_set_ip(cfg, value):
    if not validate_ip(value):
        error_exit("Invalid IP address: %s" % value)
    cfg.ip = value
    cfg.url = "http://%s" % value
    cfg.save("targ")
    success("Target IP set to: %s" % cfg.ip)
    success("Target URL set to: %s" % cfg.url)
    return 0


def cmd_list(cfg, _rest):
    if cfg.lab:
        lab_path = cfg.lab_path()
        if not lab_path.is_dir():
            error_exit("Lab directory does not exist: %s" % lab_path)
        print("Hosts in lab '%s' (%s):" % (cfg.lab, lab_path))
        shared = set(cfg.settings.get("lab", DEFAULT_CONFIG["lab"])["dirs"])
        shared.add("vpn")
        for entry in sorted(lab_path.iterdir()):
            if entry.is_dir() and entry.name not in shared:
                print("  - %s" % entry.name)
        return 0

    base = Path(cfg.base)
    if not base.is_dir():
        error_exit("Base directory does not exist: %s" % base)
    print("Projects in %s:" % base)
    for entry in sorted(base.iterdir()):
        if not entry.is_dir():
            continue
        if (entry / "network.md").is_file():
            print("  - %s/  (lab)" % entry.name)
        else:
            print("  - %s" % entry.name)
    return 0


def cmd_note(cfg, rest, number):
    title = NOTES_SECTIONS[number]
    if not rest:
        error_exit("No text provided. Usage: target %s \"<text>\""
                   % {1: "-F", 2: "-A", 3: "-H", 4: "-X"}[number])
    host = cfg.name or cfg.ip
    if not host:
        error_exit("No target name or IP set. Use 'target IP' or "
                   "'target -n NAME' first.")
    notes_cfg = cfg.settings.get("notes", DEFAULT_CONFIG["notes"])
    path = cfg.host_path(host) / notes_cfg.get("filename", "notes.md")
    try:
        entry = append_to_section(path, number, title, " ".join(rest))
    except NotesError as exc:
        error_exit(str(exc))
    success("%s <- %s" % (title, entry))
    return 0


USAGE = """Usage: target [IP_ADDRESS] [OPTION] [VALUE]

DESCRIPTION:
    Manage penetration testing project directories, target information and
    per-host enumeration notes.

OPTIONS:
    -c, --change       Change to target project directory
    -cb, --change-base Change to base directory
    -cv, --change-vpn  Change to VPN directory
    -cl, --change-lab  Change to lab/network directory (-cn alias)
    -m, --make         Create a new project directory structure
                       (--force-notes backs up and regenerates notes.md)
    -b, --base PATH    Set base directory to PATH
    -v, --vpn PATH     Set VPN directory to PATH
    -L, --lab NAME     Set lab/network to NAME (-N/--network alias; '-' clears)
    -n, --name NAME    Set target name to NAME
    -u, --url URL      Set target URL to URL
    -i, --info         Display current target information
    -l, --list         List all projects (or hosts, inside a lab)
    -h, --help         Display this help message

NOTES:
    Each host project gets a notes.md with four sections. Do not exploit
    until section 2 (Anomalies) is populated.

    -F, --fact TEXT       Append to 1. Facts (verbatim observations)
    -A, --anomaly TEXT    Append to 2. Anomalies (deviations from default)
    -H, --hypothesis TEXT Append to 3. Hypotheses (anomaly -> attack path)
    -X, --tried TEXT      Append to 4. Tried / failed (with the reason)

    Entries are timestamped and inserted at the end of their section.
    Text is taken verbatim, so leading dashes are safe:
        target -X "--script vuln returned nothing"

LAB / NETWORK LAYER:
    When a lab is set, projects nest under it:
        ${BASE}/${LAB}/${HOST}   e.g. ~/pentest-projects/dante/host-01
    The lab root holds shared credentials/, loot/, network.md and a vpn
    symlink. With no lab set, behaviour is the flat ${BASE}/${HOST}.

EXAMPLES:
    target 192.168.1.1          Set target IP to 192.168.1.1
    target -n client-x          Set target name to client-x
    target -L dante             Set lab/network to dante (scaffolds it)
    target -m                   Create project directory
    target -c                   Change to project directory
    target -F "22/tcp OpenSSH 8.9p1 Ubuntu"
    target -A "nginx default page but /backup/ is listable"
    target -L -                 Clear lab (back to flat mode)"""


def cmd_help(_cfg, _rest):
    print(USAGE)
    return 0


# --------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------

_ALIASES = {
    "change": ("-c", "--change"),
    "change_base": ("-cb", "--change-base"),
    "change_vpn": ("-cv", "--change-vpn"),
    "change_lab": ("-cl", "-cn", "--change-lab", "--change-network"),
    "make": ("-m", "--make"),
    "base": ("-b", "--base"),
    "vpn": ("-v", "--vpn"),
    "lab": ("-L", "-N", "--lab", "--network"),
    "name": ("-n", "--name"),
    "url": ("-u", "--url"),
    "info": ("-i", "--info"),
    "list": ("-l", "--list"),
    "help": ("-h", "--help"),
    "note_fact": ("-F", "--fact"),
    "note_anomaly": ("-A", "--anomaly"),
    "note_hypothesis": ("-H", "--hypothesis"),
    "note_tried": ("-X", "--tried"),
}

FLAGS = {token: command
         for command, tokens in _ALIASES.items()
         for token in tokens}

HANDLERS = {
    "change": cmd_change,
    "change_base": cmd_change_base,
    "change_vpn": cmd_change_vpn,
    "change_lab": cmd_change_lab,
    "make": cmd_make,
    "base": cmd_base,
    "vpn": cmd_vpn,
    "lab": cmd_lab,
    "name": cmd_name,
    "url": cmd_url,
    "info": cmd_info,
    "list": cmd_list,
    "help": cmd_help,
    "note_fact": lambda c, r: cmd_note(c, r, 1),
    "note_anomaly": lambda c, r: cmd_note(c, r, 2),
    "note_hypothesis": lambda c, r: cmd_note(c, r, 3),
    "note_tried": lambda c, r: cmd_note(c, r, 4),
}


def main(argv):
    cfg = Config.load()
    if not argv:
        return cmd_status(cfg) or 0

    head, rest = argv[0], argv[1:]
    command = FLAGS.get(head)
    if command is not None:
        return HANDLERS[command](cfg, rest) or 0
    if head.startswith("-"):
        # Parity with the bash `${1:0:1} == "-"` check, including a bare "-".
        error_exit("Invalid option: %s. Use 'target -h' for help." % head)
    return cmd_set_ip(cfg, head)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
