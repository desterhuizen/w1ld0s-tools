# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Engagement state: the target and attacker config written by `target` and
# `attack`, and everything derived from it. Loaded first; the fragments below
# it depend on $IP and $A_IP being set.

for _tf in targ base name lab vpn; do
    _target_source "${_W1LD0S_DIR}/engagement/target/config/${_tf}.sh"
done
unset _tf
_target_source "${_W1LD0S_DIR}/engagement/attack/attacker"

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
    ip -4 addr show dev "$dev" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1
}

# Common paths (accessible as variables)
export ROCKYOU="/usr/share/wordlists/rockyou.txt"
