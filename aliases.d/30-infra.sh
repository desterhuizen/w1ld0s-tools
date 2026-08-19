# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Attacker-side services: what you stand up for the target to reach.

# SMB utilities
alias smbserver="impacket-smbserver -smb2support"
alias smbup="sudo systemctl start smbd nmbd"
alias smbdown="sudo systemctl stop smbd nmbd"

# FTP utilities
alias ftp_up="sudo systemctl start pure-ftpd"
alias ftp_down="sudo systemctl stop pure-ftpd"

# Web server control
alias httpup="sudo systemctl start apache2"
alias httpdown="sudo systemctl stop apache2"
alias httplog="tail -f /var/log/apache2/access.log"

# --- Fetching tools ---

# Tool downloads
alias getlinpeas="wget https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh"
alias getwinpeas="wget https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe"

# --- Serving files to the target ---

function httptools() {
    local dev="${1:-${A_DEV:-tun0}}" self_ip
    self_ip=$(_my_ip "$dev")
    find /var/www/html/tools -maxdepth 1 -mindepth 1 -printf '%f\n' | sort |
        awk -v ip="$self_ip" '{print "http://" ip "/tools/" $0}' | grep -Ev '[\./]$'
}

# The peas directory update_peas writes to. Kept in one place: aliases and
# update_peas disagreeing about it is how `serve peas` came to list an empty
# directory.
export PEAS_DIR="${HOME}/tools/binaries/peas"

function serve() {
    # `local` is load-bearing: without it the assignment below overwrites the
    # exported target $IP for the rest of the shell.
    local port=80 dev="${A_DEV:-tun0}" self_ip

    if [[ -n "$2" ]]; then
        dev="$2"
    fi

    self_ip=$(_my_ip "$dev")

    if [[ $# -ge 1 ]]; then
        if [[ "$1" == "peas" ]]; then
            find "$PEAS_DIR" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort |
                while read -r peas_file; do echo "http://$self_ip/$peas_file"; done
            python3 -m http.server "$port" --directory "$PEAS_DIR"
            return
        fi
        port="$1"
    fi

    python3 -m http.server "$port"
}
