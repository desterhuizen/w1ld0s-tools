# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Scanning the target, and the /etc/hosts bookkeeping that goes with it.

# --- /etc/hosts ---

function set_host() {
    if grep -q "$1" /etc/hosts; then
        sudo sed -i "s/$(grep "$1" /etc/hosts | cut -d ' ' -f 1)/$2/g" /etc/hosts
    else
        echo "$2  $1" | sudo tee -a /etc/hosts
    fi
}

function unset_host() {
    if grep -q "$1" /etc/hosts; then
        sudo sed -i "/\s$1$/d" /etc/hosts
    fi
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
    # Re-read the target state so a `target <ip>` run in this shell is picked
    # up here. (This used to source "${SOURCE_DIR}/target", which is a
    # directory -- it always failed, and $IP was whatever the shell started
    # with.)
    _target_source "${SOURCE_DIR}/engagement/target/config/targ.sh"
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
            sudo nmap -sS -Pn -oA all_ports -p- "$IP" "${extra[@]}"
        elif [[ "$1" == "4" ]]; then
            echo "sudo nmap -sVC -A -R -O -Pn -oA all_ports_version -p $(portlist < all_ports.gnmap) $IP ${extra[*]}"
            sudo nmap -sVC -A -R -O -Pn -oA all_ports_version -p "$(portlist < all_ports.gnmap)" "$IP" "${extra[@]}"
        elif [[ "$1" == "5" ]]; then
            echo "sudo nmap --script vuln -p $(portlist < top_ports.gnmap) $IP -oA vuln_scan ${extra[*]}"
            sudo nmap --script vuln -p "$(portlist < top_ports.gnmap)" "$IP" -oA vuln_scan "${extra[@]}"
        elif [[ "$1" == "6" ]]; then
            echo "sudo nmap -sU -Pn -oA udp_port $IP ${extra[*]}"
            sudo nmap -sU -Pn -oA udp_port "$IP" "${extra[@]}"
        fi
    fi
}

function add_ports_to_readme() {
    echo -e "Ports\n" >> "$2"
    cat "$1" | grep -E '\/.*open ' | xargs -I {} echo -e '---\n{} \n\n' >> "$2"
}
