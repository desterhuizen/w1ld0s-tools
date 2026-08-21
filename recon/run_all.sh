#!/bin/bash

# Check if target IP parameter is provided
if [ -z "$1" ]
then
    echo "Please provide a target IP as a parameter"
    exit 1
fi

target_ip=$1

# Fast port scan
sudo nmap -sS -p- -T4 "$target_ip" -oN fast_scan.txt

# Complete version and script scan
ports=$(grep open fast_scan.txt | cut -d '/' -f 1 | tr '\n' ',' | sed 's/,$//')
sudo nmap -sV -sC -p"$ports" "$target_ip" -oN full_scan.txt

# Directory scan using gobuster
gobuster dir --u "http://$target_ip" -w "${WORDLISTS:-/opt/w1ld0s/wordlists}/dirb/common.txt" -o gobuster_scan.txt

# vhost discovery
nmap -sV --script http-vhosts "$target_ip" -oN vhost_scan.txt

# Nikto host scan
nikto -h "$target_ip" -o nikto_scan.txt

# enum4linux
enum4linux -a "$target_ip" > enum4linux_scan.txt
