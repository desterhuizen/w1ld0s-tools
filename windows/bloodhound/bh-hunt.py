#!/usr/bin/env python3
"""bh-hunt - run the BloodHound CE query pack against neo4j, flag the red flags.

BloodHound CE stores its graph in neo4j. This talks to neo4j's HTTP transaction
API directly (stdlib urllib, no driver, no cypher-shell, no venv), so it runs
from the pentest VM against a separate CE host without installing anything.

The queries live in bloodhound-ce-hunt.cypher next to this file. Each is a
labelled, optionally severity-tagged block; edit that file to change what runs.

Examples:
  bh-hunt --host 192.168.178.61                 # default CE creds, all queries
  bh-hunt -H bh.lab --owned 'SVC@DOM,BOB@DOM'   # mark owned first, then hunt
  bh-hunt -H bh.lab --only kerber               # queries whose label matches
  bh-hunt -H bh.lab --min-severity high         # skip info/medium
  bh-hunt -H bh.lab --json out.json             # machine-readable, no colour
  NEO4J_PASS=secret bh-hunt -H bh.lab           # creds via env

Connection defaults come from ~/.nxc/nxc.conf [BloodHound-CE] if present, then
env (NEO4J_HOST/PORT/USER/PASS), then CE's docker-compose defaults. Explicit
flags win over all of them.
"""
from __future__ import annotations

import argparse
import configparser
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

CYPHER_FILE = Path(__file__).resolve().parent / "bloodhound-ce-hunt.cypher"

SEVERITIES = ["critical", "high", "medium", "info"]  # descending
DEFAULTS = {"host": "localhost", "port": "7474", "user": "neo4j",
            "pass": "bloodhoundcommunityedition", "db": "neo4j"}


class C:
    """ANSI colours, blanked when output is not a tty or --no-color is set."""
    RED = GRN = YEL = CYN = DIM = BLD = RST = ""

    @classmethod
    def enable(cls) -> None:
        cls.RED, cls.GRN, cls.YEL = "\033[31m", "\033[32m", "\033[33m"
        cls.CYN, cls.DIM, cls.BLD, cls.RST = (
            "\033[36m", "\033[2m", "\033[1m", "\033[0m")


SEV_COLOUR = {"critical": lambda: C.RED, "high": lambda: C.YEL,
              "medium": lambda: C.CYN, "info": lambda: C.DIM}


def load_conf_defaults() -> dict[str, str]:
    """Read connection defaults from ~/.nxc/nxc.conf [BloodHound-CE] if present."""
    conf = Path.home() / ".nxc" / "nxc.conf"
    out: dict[str, str] = {}
    if not conf.is_file():
        return out
    parser = configparser.ConfigParser()
    try:
        parser.read(conf)
    except configparser.Error:
        return out
    for section in ("BloodHound-CE", "BloodHound"):
        if not parser.has_section(section):
            continue
        sec = parser[section]
        # nxc uses bh_uri/bh_user/bh_pass; be lenient about key names.
        for key, names in (("host", ("host", "bh_uri", "uri")),
                           ("port", ("port", "bh_port")),
                           ("user", ("user", "bh_user", "username")),
                           ("pass", ("pass", "bh_pass", "password"))):
            for name in names:
                if name in sec and sec[name].strip():
                    out[key] = sec[name].strip()
                    break
        break
    return out


def resolve_conn(args: argparse.Namespace) -> dict[str, str]:
    """Layer defaults: built-in < nxc.conf < env < explicit flags."""
    conn = dict(DEFAULTS)
    conn.update(load_conf_defaults())
    for key, env in (("host", "NEO4J_HOST"), ("port", "NEO4J_PORT"),
                     ("user", "NEO4J_USER"), ("pass", "NEO4J_PASS"),
                     ("db", "NEO4J_DB")):
        val = os.environ.get(env)
        if val:
            conn[key] = val
    for key in ("host", "port", "user", "db"):
        val = getattr(args, key, None)
        if val:
            conn[key] = str(val)
    if args.password:
        conn["pass"] = args.password
    # A bare host may arrive as bolt://h:7687 from nxc.conf; keep only the host.
    host = conn["host"]
    for prefix in ("bolt://", "neo4j://", "http://", "https://"):
        host = host.removeprefix(prefix)
    conn["host"] = host.split(":")[0].split("/")[0]
    return conn


class Neo4j:
    """Minimal neo4j HTTP transaction client over stdlib urllib."""

    def __init__(self, conn: dict[str, str], timeout: int) -> None:
        self.url = (f"http://{conn['host']}:{conn['port']}"
                    f"/db/{conn['db']}/tx/commit")
        self.timeout = timeout
        raw = f"{conn['user']}:{conn['pass']}".encode()
        import base64
        self.auth = "Basic " + base64.b64encode(raw).decode()

    def run(self, statement: str, params: dict | None = None) -> dict:
        """Return {'columns': [...], 'rows': [[...]], 'error': str|None}."""
        body = json.dumps({"statements": [
            {"statement": statement, "parameters": params or {}}]}).encode()
        req = urllib.request.Request(self.url, data=body, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", self.auth)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                payload = json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:200]
            return {"columns": [], "rows": [],
                    "error": f"HTTP {exc.code}: {detail}"}
        except (urllib.error.URLError, OSError) as exc:
            return {"columns": [], "rows": [], "error": f"connection: {exc}"}
        except json.JSONDecodeError:
            return {"columns": [], "rows": [], "error": "non-JSON response"}
        if payload.get("errors"):
            msg = "; ".join(e.get("message", str(e)) for e in payload["errors"])
            return {"columns": [], "rows": [], "error": msg}
        results = payload.get("results") or [{}]
        res = results[0]
        return {"columns": res.get("columns", []),
                "rows": [r.get("row", []) for r in res.get("data", [])],
                "error": None}


def parse_pack(path: Path) -> list[dict]:
    """Parse the .cypher pack into [{name, severity, query}, ...]."""
    if not path.is_file():
        sys.exit(f"[-] query file not found: {path}")
    queries: list[dict] = []
    name: str | None = None
    severity = "info"
    lines: list[str] = []

    def flush() -> None:
        nonlocal name, severity, lines
        if name and lines:
            queries.append({"name": name, "severity": severity,
                            "query": " ".join(lines).strip()})
        name, severity, lines = None, "info", []

    for raw in path.read_text().splitlines():
        line = raw.strip()
        if line.startswith("// name:"):
            flush()
            name = line.split(":", 1)[1].strip()
        elif line.startswith("// severity:"):
            severity = line.split(":", 1)[1].strip().lower()
        elif line.startswith("//") or not line:
            continue
        else:
            lines.append(line)
    flush()
    return queries


def cell(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return " -> ".join(cell(v) for v in value)
    return str(value)


def print_table(result: dict) -> None:
    cols, rows = result["columns"], result["rows"]
    table = [[cell(v) for v in row] for row in rows]
    widths = [len(c) for c in cols]
    for row in table:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(val))
    header = "  ".join(c.ljust(widths[i]) for i, c in enumerate(cols))
    print(f"  {C.BLD}{header}{C.RST}")
    for row in table:
        print("  " + "  ".join(val.ljust(widths[i])
                               for i, val in enumerate(row)))


def mark_owned(db: Neo4j, names: str) -> None:
    principals = [n.strip() for n in names.split(",") if n.strip()]
    if not principals:
        return
    res = db.run(
        "MATCH (n) WHERE n.name IN $names SET n.owned = true "
        "RETURN count(n) AS marked", {"names": principals})
    if res["error"]:
        print(f"{C.RED}[-] failed to mark owned: {res['error']}{C.RST}")
        return
    marked = res["rows"][0][0] if res["rows"] else 0
    unmatched = [p for p in principals if p]  # informational only
    print(f"{C.GRN}[+] marked owned: {marked}/{len(unmatched)} matched "
          f"({', '.join(principals)}){C.RST}")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Run the BloodHound CE query pack against neo4j.",
        formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    ap.add_argument("-H", "--host", help="neo4j host (default: nxc.conf/env/localhost)")
    ap.add_argument("-P", "--port", help="neo4j HTTP port (default 7474)")
    ap.add_argument("-u", "--user", help="neo4j user (default neo4j)")
    ap.add_argument("-p", "--password", help="neo4j password (or NEO4J_PASS)")
    ap.add_argument("--db", help="neo4j database (default neo4j)")
    ap.add_argument("-o", "--owned", help="comma-separated principals to mark owned first")
    ap.add_argument("--only", metavar="TERM",
                    help="run only queries whose label matches TERM (case-insensitive)")
    ap.add_argument("-s", "--min-severity", choices=SEVERITIES, default="info",
                    help="skip queries below this severity (default: info = all)")
    ap.add_argument("--empty", action="store_true",
                    help="also show queries that returned nothing")
    ap.add_argument("--json", metavar="FILE", nargs="?", const="-",
                    help="write results as JSON (FILE or - for stdout); implies --no-color")
    ap.add_argument("--no-color", action="store_true", help="disable ANSI colour")
    ap.add_argument("--timeout", type=int, default=60, help="per-query timeout seconds")
    ap.add_argument("--cypher-file", type=Path, default=CYPHER_FILE,
                    help="override the query pack path")
    args = ap.parse_args()

    json_to_stdout = args.json == "-"
    if not args.no_color and not json_to_stdout and sys.stdout.isatty():
        C.enable()

    conn = resolve_conn(args)
    db = Neo4j(conn, args.timeout)

    ping = db.run("RETURN 1")
    if ping["error"]:
        print(f"{C.RED}[-] cannot reach neo4j at {conn['host']}:{conn['port']} "
              f"as {conn['user']}: {ping['error']}{C.RST}", file=sys.stderr)
        print("    set --password / NEO4J_PASS "
              "(CE default: bloodhoundcommunityedition)", file=sys.stderr)
        return 1

    if args.owned:
        mark_owned(db, args.owned)

    queries = parse_pack(args.cypher_file)
    threshold = SEVERITIES.index(args.min_severity)
    collected: list[dict] = []
    counts = {s: 0 for s in SEVERITIES}

    for q in queries:
        sev = q["severity"] if q["severity"] in SEVERITIES else "info"
        if SEVERITIES.index(sev) > threshold:
            continue
        if args.only and args.only.lower() not in q["name"].lower():
            continue
        res = db.run(q["query"])
        record = {"name": q["name"], "severity": sev,
                  "error": res["error"], "columns": res["columns"],
                  "rows": res["rows"]}
        collected.append(record)
        if res["error"] is None and res["rows"]:
            counts[sev] += 1

        if args.json:
            continue

        hit = res["error"] is None and bool(res["rows"])
        if not hit and not res["error"] and not args.empty:
            continue
        tag = SEV_COLOUR.get(sev, lambda: "")()
        print()
        print(f"{C.CYN}=== {q['name']} {tag}[{sev}]{C.RST} ===")
        if res["error"]:
            print(f"  {C.RED}error: {res['error']}{C.RST}")
        elif not res["rows"]:
            print(f"  {C.DIM}(no results){C.RST}")
        else:
            print_table(res)

    if args.json:
        out = json.dumps({"connection": {"host": conn["host"], "port": conn["port"]},
                          "results": collected}, indent=2)
        if json_to_stdout:
            print(out)
        else:
            Path(args.json).write_text(out)
            print(f"{C.GRN}[+] wrote {len(collected)} results to {args.json}{C.RST}",
                  file=sys.stderr)
    else:
        summary = "  ".join(
            f"{SEV_COLOUR[s]()}{counts[s]} {s}{C.RST}"
            for s in SEVERITIES if counts[s])
        print()
        print(f"[*] done. flagged: {summary or '(nothing)'}")
        if not args.owned:
            print("    tip: --owned 'USER@DOM,...' then re-run — most attack "
                  "paths only appear once owned is set.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
