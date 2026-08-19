# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Getting onto the network and staying there: VPN, ligolo, reverse ssh.

# --- VPN ---
alias vpn='sudo openvpn ${HOME}/vpn/*.ovpn'

# Ligolo tunneling
alias ligolo-up='sudo ip tuntap add user $(whoami) mode tun ligolo; sudo ip link set ligolo up'
alias ligolo-down="sudo ip link set ligolo down"

function ligolo-start() {
    echo "agent at /usr/bin/ligolo-agent"
    addr="0.0.0.0:54"
    if [ $# -ne 0 ]; then
        addr="$1"
    fi
    sudo ligolo-proxy -selfcert -laddr "$addr"
}

function ligolo-route() {
    sudo ip route add "$1" dev ligolo
}

# --- Reverse SSH ---

function rscp() {
    local ip
    ip=$(_my_ip)
    scp -J "$ip" "$@"
}

function rssh() {
    local port=443 ip
    if [ $# -ne 0 ]; then
        port="$1"
    fi
    ip=$(_my_ip)
    ssh "$ip" -p "$port"
}

function rsh_links() {
    port=443
    if [ $# -eq 2 ]; then
        port="$2"
    fi
    ssh "$1" -p "$port" "link -r *"
    ssh "$1" -p "$port" "link --goos windows --goarch amd64 --name shell.exe"
    ssh "$1" -p "$port" "link --goos linux --goarch amd64 --name shell"
    ssh "$1" -p "$port" "link -l"
}
