#!/usr/bin/env bash
# bh-hunt.sh - run the BloodHound CE query pack via cypher-shell, labeled output.
#
# REFERENCE COPY. The maintained tool is ../bh-hunt.py, which speaks neo4j's
# HTTP API directly and needs no cypher-shell. This is kept 0644 (sourced/read,
# never published) as the pre-port implementation for anyone who has cypher-shell
# and wants a dependency-light runner. It reads the pack one directory up.
#
# BloodHound CE stores its graph in neo4j, so cypher-shell works against it.
# Defaults match the CE docker-compose (neo4j / bloodhoundcommunityedition on 7687).
#
# Usage:
#   bash bh-hunt.sh                                # run all queries
#   bash bh-hunt.sh -o 'SVC_LDAP@AUTHORITY.HTB'    # mark owned first (comma-separated)
#   bash bh-hunt.sh -f only:kerber                 # run only queries whose label matches
#   NEO4J_PASS=secret bash bh-hunt.sh              # override creds via env
#
# Env overrides: NEO4J_URI, NEO4J_USER, NEO4J_PASS, CYPHER_FILE
set -euo pipefail

URI="${NEO4J_URI:-bolt://localhost:7687}"
USER="${NEO4J_USER:-neo4j}"
PASS="${NEO4J_PASS:-bloodhoundcommunityedition}"
# The pack lives one level up (this reference copy sits in legacy/).
CYPHER_FILE="${CYPHER_FILE:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/bloodhound-ce-hunt.cypher}"
OWNED=""; FILTER=""

while getopts "o:f:h" opt; do
  case "$opt" in
    o) OWNED="$OPTARG" ;;
    f) FILTER="${OPTARG#only:}" ;;
    h) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "see -h"; exit 1 ;;
  esac
done

command -v cypher-shell >/dev/null || { echo "[-] cypher-shell not found (comes with neo4j)"; exit 1; }
[ -f "$CYPHER_FILE" ] || { echo "[-] query file not found: $CYPHER_FILE"; exit 1; }

run() { cypher-shell -a "$URI" -u "$USER" -p "$PASS" --format plain "$1" 2>&1; }

# connectivity check
if ! run "RETURN 1;" >/dev/null 2>&1; then
  echo "[-] cannot reach neo4j at $URI as $USER. Set NEO4J_PASS (CE default: bloodhoundcommunityedition)."
  exit 1
fi

# optional: mark owned from the command line (overrides/augments the file's list)
if [ -n "$OWNED" ]; then
  # Quote each comma-separated name on its own line, then join with commas.
  # Splitting on newlines (not word-splitting $OWNED) keeps names with spaces
  # -- "CERT PUBLISHERS@DOM" -- intact.
  list=$(echo "$OWNED" | tr ',' '\n' | sed "s/^ *//; s/ *$//; /^$/d; s/.*/'&'/" | paste -sd, -)
  echo "[*] marking owned: $OWNED"
  run "MATCH (n) WHERE n.name IN [$list] SET n.owned=true RETURN count(n) AS marked;"
fi

RED=$'\e[31m'; GRN=$'\e[32m'; CYN=$'\e[36m'; DIM=$'\e[2m'; RST=$'\e[0m'

# parse the .cypher file into label<TAB>query records (join multi-line queries with spaces)
awk '
  /^\/\/[ ]*name:/ { if (q!="") print label "\t" q; label=substr($0, index($0,":")+1); sub(/^[ ]+/,"",label); sub(/[ ]+$/,"",label); q=""; next }
  /^\/\// { next }
  /^[ ]*$/ { next }
  { line=$0; sub(/^[ ]+/,"",line); sub(/[ ]+$/,"",line); q=(q=="" ? line : q " " line) }
  END { if (q!="") print label "\t" q }
' "$CYPHER_FILE" | while IFS=$'\t' read -r label query; do
  [ -n "$FILTER" ] && ! echo "$label" | grep -qi "$FILTER" && continue
  echo
  echo "${CYN}=== ${label} ===${RST}"
  # || true: set -e would otherwise abort the whole run on the first query that
  # errors (e.g. an unbounded shortestPath that times out), taking the rest down.
  out=$(run "$query") || true
  # first line is the column header; if nothing but header, say empty
  rows=$(echo "$out" | sed '1d' | grep -cve '^[[:space:]]*$' || true)
  # Match neo4j error codes only. A bare 'error'/'invalid' also matches result
  # rows -- a description field or an account named svc_error -- and paints them red.
  if echo "$out" | grep -qE 'Neo\.(ClientError|DatabaseError|TransientError)'; then
    echo "${RED}${out}${RST}"
  elif [ "$rows" -eq 0 ]; then
    echo "${DIM}(no results)${RST}"
  else
    echo "${GRN}${out}${RST}"
  fi
done

echo
echo "[*] done. Tip: mark owned then re-run — most paths only appear once owned is set."
