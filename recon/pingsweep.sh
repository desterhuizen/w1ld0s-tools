#!/bin/bash
# Parallel ping sweep of a /24. Every host is pinged in a background job, so a
# full sweep finishes in about a second instead of walking 254 hosts serially.

usage() {
  echo "Usage: ${0##*/} <network-prefix>"
  echo
  echo "Sweeps <network-prefix>.1-254 and prints the hosts that reply."
  echo "The prefix is the first three octets; a trailing .0, .0/24 or . is"
  echo "accepted and trimmed."
  echo
  echo "  ${0##*/} 192.168.1"
  echo "  ${0##*/} 10.10.10.0/24"
  exit "${1:-1}"
}

case "$1" in
  -h | --help) usage 0 ;;
esac

[ $# -eq 1 ] || usage

# Accept the forms an operator actually types and reduce them to three octets.
# The trailing .0 is only the network address when there are four octets to
# begin with — stripping it unconditionally would eat the third octet of a
# prefix like 10.0.0.
subnet="${1%/24}"
subnet="${subnet%.}"
if [[ "$subnet" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\.0$ ]]; then
  subnet="${BASH_REMATCH[1]}"
fi

if [[ ! "$subnet" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "Not a network prefix: $1" >&2
  usage
fi

# The regex only bounds the digit count, so range-check each octet.
IFS=. read -r a b c <<< "$subnet"
for octet in "$a" "$b" "$c"; do
  if [ "$octet" -gt 255 ]; then
    echo "Octet out of range in $1: $octet" >&2
    usage
  fi
done

echo "[*] Sweeping ${subnet}.1-254"
for i in $(seq 1 254); do
  (ping -c1 -W1 "$subnet.$i" >/dev/null 2>&1 && echo "$subnet.$i") &
done
wait
