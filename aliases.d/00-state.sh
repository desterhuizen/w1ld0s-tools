# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Engagement state: the target and attacker config written by `target` and
# `attack`, and everything derived from it. Loaded first; the fragments below
# it depend on $IP and $A_IP being set.

_w1ld0s_load_state() {
    local _tf
    for _tf in targ base name lab vpn; do
        _target_source "${_W1LD0S_DIR}/engagement/target/config/${_tf}.sh"
    done
    _target_source "${_W1LD0S_DIR}/engagement/attack/attacker"
    return 0
}
_w1ld0s_load_state

# `target` and `attack` write these files after this shell has already started,
# so read them again before every prompt. Loading them only at startup meant a
# `target 10.10.11.42` in one terminal left every other shell holding the
# previous engagement's values indefinitely -- my_scan worked around it by
# re-sourcing targ.sh itself, which fixed $IP inside that one function and left
# $TARGET_BASE, $TARGET_NAME, $TARGET_LAB, $TARGET_VPN and $A_IP stale
# everywhere. Registered idempotently, because sourcing aliases twice in one
# shell must not stack the hook twice.
if [ -n "${ZSH_VERSION:-}" ]; then
    typeset -ga precmd_functions
    case " ${precmd_functions[*]} " in
        *" _w1ld0s_load_state "*) ;;
        *) precmd_functions+=(_w1ld0s_load_state) ;;
    esac
elif [ -n "${BASH_VERSION:-}" ]; then
    case "${PROMPT_COMMAND:-}" in
        *_w1ld0s_load_state*) ;;
        "") PROMPT_COMMAND="_w1ld0s_load_state" ;;
        *) PROMPT_COMMAND="${PROMPT_COMMAND%;};_w1ld0s_load_state" ;;
    esac
fi

# Our own address on the engagement network. Four functions below used to
# derive this by hand, each with its own ip/awk pipeline, while `attack` exists
# precisely to record it -- so `attack tun0` had no effect on any of them.
# Prefer what attack stored; fall back to reading the interface directly so the
# functions still work before attack has ever been run.
_my_ip() {
    local dev="${1:-${A_DEV:-tun0}}"
    if [ -n "$A_IP" ] && [ "$dev" = "${A_DEV:-tun0}" ]; then
        echo "$A_IP"
        return 0
    fi
    # A pipeline's status is its last command's, and cut succeeds on empty
    # input, so without this the interface-read path returned an empty string
    # and status 0. Callers writing LHOST=$(_my_ip) got an empty LHOST and no
    # reason to stop, then built a listener or payload pointing nowhere.
    local addr
    addr=$(ip -4 addr show dev "$dev" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    [ -n "$addr" ] || return 1
    echo "$addr"
}

# Where the wordlists were unpacked on this workstation. Scripts and
# cheatsheets used to spell out the prefix themselves, so moving the
# collection meant hunting down every copy; they go through $WORDLISTS now.
# Exported because the scripts reading it are child processes of this shell
# rather than sourced into it.
export WORDLISTS="/opt/w1ld0s/wordlists"
export ROCKYOU="$WORDLISTS/rockyou.txt"
