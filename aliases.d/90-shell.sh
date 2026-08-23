# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Plain shell comfort, plus the single-letter shortcuts. Loaded last so the
# functions they point at already exist.

# Navigation shortcuts
alias tools_b='cd ${HOME}/tools/binaries'
alias tools_r='cd ${HOME}/tools/repos'
alias mkip='mkdir ${IP}; cd ${IP}'

# File viewing/editing
alias vi="nvim"
alias ccat="batcat --color always"
alias pbcopy="xclip -selection clipboard"
alias hosts="cat /etc/hosts"
alias showserve='tree --noreport -a --prune -i -L 3 -f -I "__python__" -I "*.csv" -I "*.txt" -I "*.spec" -I "*__init__*" -I "*.dmp" -I "*.so" -I "*.c" -I "*.h" -I "__pycache__" -I "*.cs" -I "*.png" -I "*.go" -I "*.md" -I "*.git*" | batcat -f -l sh --theme gruvbox-dark'

# --- Network interfaces ---

# Ubuntu ships iproute2, not net-tools or wireless-tools, so the names worth
# keeping are the ones already in muscle memory. Bare `ifconfig` gives the
# one-line-per-interface summary -- which interface, up or down, what address
# -- and `-a` the full blocks; an interface name narrows either. Both names
# shadow the real binaries if those packages ever get installed, so call
# /sbin/ifconfig by path on the rare occasion the genuine article is wanted.
function ifconfig() {
    if [ "$1" = "-a" ]; then
        shift
        ip -c addr show "$@"
    else
        ip -c -br addr show "$@"
    fi
}

# `iw dev` lists the wireless interfaces; association detail for one of them is
# `iw dev <interface> link`.
alias iwconfig="iw dev"

# Password utilities
alias password_generate="tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo"

# Command shortcuts
alias t="target"
alias s="my_scan"
alias a="attack"
alias c="common"

# --- git ---

alias gs="git status"
alias ga="git add ."
alias gp="git push"
alias gc="git commit"
