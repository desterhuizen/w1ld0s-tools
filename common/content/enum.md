# Network Enumeration Reference

This document provides organized commands for network enumeration during penetration testing.

---

## 1. Network Discovery

### ARP-based Host Discovery
```bash
# Scan local network using ARP
sudo arp-scan -I eth1 -l

# Alternative using netdiscover with specific range
sudo netdiscover -r 192.168.10.0/24 -i eth1
```

---

## 2. Port Scanning

### Nmap Methodology
```bash
# 1. Initial TCP SYN scan of top ports - quick overview
sudo nmap -sS -Pn -oA top_ports $IP

# 2. Version scan of discovered ports - identify services
sudo nmap -sVC -n -O -Pn -oA top_ports_version -p <portlist> $IP

# 3. Full TCP port scan - find all open ports
sudo nmap -sS -Pn -oA all_ports -p- $IP

# 4. Comprehensive scan of all discovered ports
sudo nmap -sVC -A -R -O -Pn -oA all_ports_version -p <portlist> $IP

# 5. Vulnerability scan of specific ports
sudo nmap --script vuln -p <portlist> $IP

# 6. UDP scan of top ports
sudo nmap -sU -Pn -oA udp_ports $IP
```

---

## 3. DNS Enumeration

### DNS Information Gathering
```bash
# TXT record lookup
host -t txt domain.com

# Forward lookup to test DNS
host doesnotexist.domain.com

# Interactive DNS lookup with specific server
nslookup
SERVER <IP>
127.0.0.1

# Zone transfer attempt
host -l domain.com nameserver.domain.com

# Comprehensive DNS reconnaissance
dnsrecon -r 127.0.0.0/24 -n $IP -d anything
```

---

## 4. SMB Enumeration

### SMB Service Enumeration
```bash
# Nmap SMB scripts
nmap --script="smb-enum-*" $IP

# Comprehensive SMB enumeration
enum4linux -a $IP
enum4linux-ng -A $IP -oA enum4linux

# Extract usernames from enum4linux JSON output
cat enum4linux.json | jq -c -r '.users | keys[] as $k | "\(.[$k] | .username)" '
```

### SMB Authentication & Access
```bash
# List SMB shares
smbclient -L $IP

# Connect with null session
smbclient //$IP/<share_name> -N

# User enumeration via RID bruteforcing
crackmapexec smb $IP -u <user> -p <password> --rid-brute
```

---

## 5. NFS Enumeration

### NFS Mount Discovery
```bash
# Show available NFS exports
showmounts -e $IP

# Mount NFS share on non-standard port
mount -t nfs -o port=1234 localhost:/home /mnt/nfs

# Mount with specific version (SMB/CIFS)
mount -t cifs -o rw,vers=3.0 //$IP/home ./tmp
```

---

## 6. Kerberos Enumeration

### Domain User Enumeration
```bash
# RID bruteforcing against domain controller
crackmapexec smb dc01.manager.htb -u anonymous -d manager.htb -p '' --rid-brute
```
