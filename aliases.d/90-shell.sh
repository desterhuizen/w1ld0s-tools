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
