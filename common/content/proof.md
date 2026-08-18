# Proof Collection

This document contains commands for finding and retrieving proof files during
penetration tests.

---

## Finding Proof Files

### Linux

```bash
# Find all proof files recursively from current directory
find . -type f \( -name "secret.txt" -o -name "proof.txt" -o -name "local.txt" \)
```

### Windows

```bash
# CMD - Find all proof files recursively
dir /s /b secret.txt proof.txt local.txt
```

```powershell
# PowerShell - Find all proof files recursively
Get-ChildItem -Recurse -File -Include secret.txt, proof.txt, local.txt
```

---

## System Information & Proof Collection

### Linux Commands

```bash
# Use this template and replace FILENAME with local.txt, proof.txt, or secret.txt as needed
# Shows system info and retrieves the specified proof file
echo " ";
echo "uname -a";
uname -a;
echo " ";
echo "hostname";
hostname -f;
echo" ";
echo "id";
id;
echo " ";
echo "ifconfig";
/sbin/ifconfig -a 2>/dev/null || /usr/bin/ip addr 2>/dev/null;
echo " ";
echo "cat FILENAME";
# For local.txt (usually in user home)
cat ~/local.txt 2>/dev/null; cat local.txt 2>/dev/null;
# For proof.txt (usually in root directory)
# cat /root/proof.txt 2>/dev/null; cat proof.txt 2>/dev/null;
# For secret.txt
# cat secret.txt 2>/dev/null;
echo " "
```

### Specific Linux Commands

#### Local.txt (User Level)

```bash
echo " ";echo "uname -a";uname -a;echo " ";echo "hostname";hostname -f;echo" ";echo "id";id;echo " ";echo "ifconfig";/sbin/ifconfig -a 2>/dev/null || /usr/bin/ip addr 2>/dev/null;echo " ";echo "cat local.txt";cat ~/local.txt 2>/dev/null; cat local.txt 2>/dev/null;echo " "
```

#### Proof.txt (Root Level)

```bash
echo " ";echo "uname -a";uname -a;echo " ";echo "hostname -f";hostname -f;echo " ";echo "id";id;echo " ";echo "ifconfig";/sbin/ifconfig -a 2>/dev/null || /usr/bin/ip addr 2>/dev/null;echo " ";echo "cat proof.txt";cat /root/proof.txt 2>/dev/null; cat proof.txt 2>/dev/null;echo " "
```

#### Secret.txt

```bash
echo " ";echo "uname -a";uname -a;echo " ";echo "hostname -f";hostname -f;echo " ";echo "id";id;echo " ";echo "ifconfig";/sbin/ifconfig -a 2>/dev/null || /usr/bin/ip addr 2>/dev/null;echo " ";echo "cat secret.txt";cat secret.txt 2>/dev/null; cat secret.txt 2>/dev/null;echo " "
```

### Windows Commands

```bash
# Use this template and replace FILENAME with local.txt, proof.txt, or secret.txt
# Shows system info and retrieves the specified proof file
echo. & echo. & echo whoami: & whoami 2> nul & echo %username% 2> nul & echo. & echo Hostname: & hostname & echo. & ipconfig /all & echo. & echo FILENAME: & type FILENAME
```

### Specific Windows Commands

#### Local.txt

```bash
echo. & echo. & echo whoami: & whoami 2> nul & echo %username% 2> nul & echo. & echo Hostname: & hostname & echo. & ipconfig /all & echo. & echo local.txt: & type local.txt
```

#### Proof.txt

```bash
echo. & echo. & echo whoami & whoami 2> nul & echo %username% 2> nul & echo. & echo Hostname & hostname & echo. & ipconfig /all & echo. & echo type proof.txt & type proof.txt
```

#### Secret.txt

```bash
echo. & echo. & echo whoami & whoami 2> nul & echo %username% 2> nul & echo. & echo Hostname & hostname & echo. & ipconfig /all & echo. & echo type secret.txt & type secret.txt
```
