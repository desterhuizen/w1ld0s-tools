# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Scanning the target, and the /etc/hosts bookkeeping that goes with it.

# --- /etc/hosts ---

# Rewrite /etc/hosts through an awk program, keeping the previous contents in
# /etc/hosts.bak. Both helpers below go through this, so the temp file, the
# single sudo write and the backup live in one place. A program that changes
# nothing writes nothing, so an unset_host on an absent name stays a no-op.
_w1ld0s_hosts_edit() {
    local tmp rc
    tmp=$(mktemp) || return 1
    if ! awk "$@" /etc/hosts > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    rc=0
    if ! cmp -s "$tmp" /etc/hosts; then
        sudo cp /etc/hosts /etc/hosts.bak && sudo cp "$tmp" /etc/hosts
        rc=$?
    fi
    rm -f "$tmp"
    return $rc
}

# The hostname is compared against whole fields rather than being grepped for
# as a substring: `set_host corp.htb` used to match dc01.corp.htb too, and
# then rewrote whichever line grep happened to return. Only field 1 of a
# matching line is replaced, so the separator and any aliases survive.
function set_host() {
    if [ $# -ne 2 ]; then
        echo "set_host: usage: set_host <hostname> <address>" >&2
        return 1
    fi
    # shellcheck disable=SC2016  # $i and $0 belong to awk, not to the shell
    _w1ld0s_hosts_edit -v host="$1" -v addr="$2" '
        /^[ \t]*(#|$)/ { print; next }
        {
            for (i = 2; i <= NF; i++)
                if ($i == host) {
                    sub(/^[ \t]*[^ \t]+/, addr)
                    found = 1
                    break
                }
            print
        }
        END { if (!found) printf "%s  %s\n", addr, host }
    '
}

function unset_host() {
    if [ $# -ne 1 ]; then
        echo "unset_host: usage: unset_host <hostname>" >&2
        return 1
    fi
    # shellcheck disable=SC2016  # $i belongs to awk, not to the shell
    _w1ld0s_hosts_edit -v host="$1" '
        /^[ \t]*(#|$)/ { print; next }
        {
            for (i = 2; i <= NF; i++)
                if ($i == host) next
            print
        }
    '
}

function monitor_host() {
    while true; do
        clear
        date
        echo -e '\n ========================\n'
        ping "$1" -c 1 | grep -E '[01] packets|[01] received'
        echo -e '\n ========================'
        sleep 5
    done
}

# --- nmap ---

function my_scan() {
    if [ $# -ne 0 ] && [ -z "$IP" ]; then
        # Without this, every scan below ran nmap with an empty target
        # argument, which it reads as a host it cannot resolve.
        echo "my_scan: no target set -- run 'target <ip>' first" >&2
        return 1
    fi
    if [ $# -eq 0 ]; then
        echo "Scan 1:  sudo nmap -sS -Pn -oA top_ports \$IP"
        echo "Scan 2:  sudo nmap -sVC -n -O -Pn -oA top_ports_version -p <portlist> \$IP"
        echo "Scan 3:  sudo nmap -sS -Pn -oA all_ports -p- --max-rtt-timeout=100ms \$IP"
        echo "Scan 4:  sudo nmap -sVC -A -R -O -Pn -oA all_ports_version  -p <portlist> \$IP"
        echo "Scan 5:  sudo nmap --script vuln -p <portlist> -oA vuln_scan  \$IP"
        echo "Scan 6:  sudo nmap -sU -Pn -oA udp_ports \$IP"
    else
        # Anything after the scan number is passed straight to nmap. Held in an
        # array rather than "$2": a bare "$2" with nothing there handed nmap an
        # empty argument, which it reads as a target it cannot resolve.
        local extra=("${@:2}")
        if [[ "$1" == "1" ]]; then
            echo "sudo nmap -sS -Pn -oA top_ports $IP ${extra[*]}"
            sudo nmap -sS -Pn -oA top_ports "$IP" "${extra[@]}"
        elif [[ "$1" == "2" ]]; then
            echo "sudo nmap -sVC -n -O -Pn -oA top_ports_version -p $(portlist < top_ports.gnmap) $IP ${extra[*]}"
            sudo nmap -sVC -n -O -Pn -oA top_ports_version -p "$(portlist < top_ports.gnmap)" "$IP" "${extra[@]}"
        elif [[ "$1" == "3" ]]; then
            echo "sudo nmap -sS -Pn -oA all_ports -p- --max-rtt-timeout=100ms $IP ${extra[*]}"
            sudo nmap -sS -Pn -oA all_ports -p- --max-rtt-timeout=100ms "$IP" "${extra[@]}"
        elif [[ "$1" == "4" ]]; then
            echo "sudo nmap -sVC -A -R -O -Pn -oA all_ports_version -p $(portlist < all_ports.gnmap) $IP ${extra[*]}"
            sudo nmap -sVC -A -R -O -Pn -oA all_ports_version -p "$(portlist < all_ports.gnmap)" "$IP" "${extra[@]}"
        elif [[ "$1" == "5" ]]; then
            echo "sudo nmap --script vuln -p $(portlist < top_ports.gnmap) $IP -oA vuln_scan ${extra[*]}"
            sudo nmap --script vuln -p "$(portlist < top_ports.gnmap)" "$IP" -oA vuln_scan "${extra[@]}"
        elif [[ "$1" == "6" ]]; then
            echo "sudo nmap -sU -Pn -oA udp_ports $IP ${extra[*]}"
            sudo nmap -sU -Pn -oA udp_ports "$IP" "${extra[@]}"
        else
            echo "my_scan: no scan $1 -- run 'my_scan' for the list" >&2
            return 1
        fi
    fi
}
