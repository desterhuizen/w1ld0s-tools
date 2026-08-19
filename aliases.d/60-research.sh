# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Searching the offline reference clones under ~/tools/repos.

function htricks() {
    grep -R "^#.*$1.*Pentesting" "${HOME}/tools/repos/hacktricks/network-services-pentesting" |
    cut -d":" -f 1 | rev | cut -d "/" -f1 | rev | cut -d "." -f 1 |
    xargs -I {} echo "https://book.hacktricks.xyz/network-services-pentesting/{}"
}

function gtfo() {
    find "${HOME}/tools/repos/GTFOBins.github.io/_gtfobins" |
    grep "\/$1\.md" | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1 |
    xargs -I {} lynx "https://gtfobins.github.io/gtfobins/{}"
}

function platt() {
    find "${HOME}/tools/repos/PayloadsAllTheThings" |
    grep -i "$1" | xargs -I {} echo "splatt \"{}\""
}

function splatt() {
    pandoc "$1" | lynx -stdin
}
