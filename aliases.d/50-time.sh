# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Clock alignment with the target. Kerberos refuses tickets outside a five
# minute skew, so this is often the difference between a working AD attack
# and an unexplained failure.

# Sync local system clock to a target's HTTP Date header.
# Usage: httpdate <ip-or-host> [port]
# Example: httpdate 10.10.11.42
#          httpdate target.htb 8080
httpdate() {
    if [ -z "$1" ]; then
        echo "Usage: httpdate <ip-or-host> [port]" >&2
        echo "  Syncs local clock to the target's HTTP Date header." >&2
        return 1
    fi

    local target="$1"
    local port="${2:-80}"
    local url="http://${target}:${port}"

    local http_date
    http_date=$(curl -sI --max-time 5 "$url" | grep -i '^Date:' | sed 's/^[Dd]ate:[[:space:]]*//' | tr -d '\r\n')

    if [ -z "$http_date" ]; then
        echo "httpdate: no Date header from $url" >&2
        return 1
    fi

    echo "Target date: [$http_date]"
    echo "Local before: $(date)"

    if sudo date -s "$http_date"; then
        echo "Local after:  $(date)"
    else
        echo "httpdate: failed to set date" >&2
        return 1
    fi
}

# Sync local system clock to a target's NTP server.
# Usage: ntpdate-target <ip-or-host>
# Example: ntpdate-target 10.10.11.42
#          ntpdate-target dc01.logging.htb
ntpdate-target() {
    if [ -z "$1" ]; then
        echo "Usage: ntpdate-target <ip-or-host>" >&2
        echo "  Syncs local clock to the target's NTP server (UDP/123)." >&2
        return 1
    fi

    local target="$1"

    # Pick whichever NTP client is installed
    local ntp_cmd=""
    if command -v ntpdate >/dev/null 2>&1; then
        ntp_cmd="ntpdate"
    elif command -v sntp >/dev/null 2>&1; then
        ntp_cmd="sntp"
    elif command -v chronyd >/dev/null 2>&1; then
        ntp_cmd="chronyd"
    else
        echo "ntpdate-target: no NTP client found. Install one:" >&2
        echo "  sudo apt install ntpdate     # classic" >&2
        echo "  sudo apt install sntp        # lightweight" >&2
        echo "  sudo apt install chrony      # modern" >&2
        return 1
    fi

    echo "Local before: $(date)"

    # Stop systemd-timesyncd if running, so it doesn't fight us
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        echo "Disabling systemd-timesyncd temporarily..."
        sudo timedatectl set-ntp false
    fi

    case "$ntp_cmd" in
        ntpdate)
            sudo ntpdate -u "$target" || {
                echo "ntpdate-target: ntpdate failed against $target" >&2
                return 1
            }
            ;;
        sntp)
            sudo sntp -sS "$target" || {
                echo "ntpdate-target: sntp failed against $target" >&2
                return 1
            }
            ;;
        chronyd)
            sudo chronyd -q "server $target iburst" || {
                echo "ntpdate-target: chronyd failed against $target" >&2
                return 1
            }
            ;;
    esac

    echo "Local after:  $(date)"
}

# Reads system_time from SMB via nmap's smb-os-discovery script.
  # Useful when NTP / HTTP are blocked but SMB to the DC is reachable —
  # the Kerberos clock-skew workaround.
  dc-time-target() {
    local dc="$1" set_clock=0
    [[ -z "$dc" ]] && { echo "usage: dc-time-target <dc> [--set]" >&2; return 2; }
    shift
    while (( $# )); do
      case "$1" in
        --set) set_clock=1 ;;
        -h|--help)
          echo "usage: dc-time-target <dc> [--set]" >&2
          return 0 ;;
        *) echo "dc-time-target: unknown arg: $1" >&2; return 2 ;;
      esac
      shift
    done

    local ts
    ts=$(nmap -sT -p 445 --script smb-os-discovery "$dc" 2>/dev/null \
         | grep -oP 'System time:\s*\K\S+' | head -1)
    if [[ -z "$ts" ]]; then
      echo "dc-time-target: no system time leaked from $dc — is SMB reachable?" >&2
      return 1
    fi

    echo "$ts"
    (( set_clock )) && sudo date -s "$ts" >&2
  }

    # LDAP rootDSE returns currentTime as generalized time (YYYYMMDDHHMMSS.0Z),
  # always UTC. We convert to ISO before printing / `date -s`.
  dc-time-target-ldap() {
    local dc="$1" set_clock=0 user="" pass=""
    [[ -z "$dc" ]] && { echo "usage: dc-time-target-ldap <dc> [--set] [-u USER -p PASS]" >&2; return 2; }
    shift
    while (( $# )); do
      case "$1" in
        --set)    set_clock=1 ;;
        -u|--user) user="$2"; shift ;;
        -p|--pass) pass="$2"; shift ;;
        -h|--help)
          echo "usage: dc-time-target-ldap <dc> [--set] [-u USER -p PASS]" >&2
          echo "       anonymous query first; -u/-p when rootDSE is locked down" >&2
          return 0 ;;
        *) echo "dc-time-target-ldap: unknown arg: $1" >&2; return 2 ;;
      esac
      shift
    done

    # Build ldapsearch args: anonymous (-x) by default; auth bind when -u/-p passed.
    local -a ldargs=(-LLL -H "ldap://$dc" -s base -b "" currentTime)
    if [[ -n "$user" ]]; then
      ldargs=(-D "$user" -w "$pass" "${ldargs[@]}")
    else
      ldargs=(-x "${ldargs[@]}")
    fi

    local raw
    raw=$(ldapsearch "${ldargs[@]}" 2>/dev/null | awk '/^currentTime:/ {print $2}')
    if [[ -z "$raw" ]]; then
      echo "dc-time-target-ldap: no currentTime — anonymous rootDSE blocked? Try -u/-p." >&2
      return 1
    fi

    # YYYYMMDDHHMMSS.0Z → ISO 8601
    local iso
    iso=$(printf '%s\n' "$raw" | sed -E 's/^(....)(..)(..)(..)(..)(..).*/\1-\2-\3T\4:\5:\6Z/')
    echo "$iso"
    (( set_clock )) && sudo date -u -s "$iso" >&2
  }
