# Reconnaissance Techniques

---

## Visual Reconnaissance

### Website Screenshots
```bash
# Generate a report from a list of URLs
eyewitness -f list.txt -d report

# Screenshot a single website
eyewitness --single http://site.com
```

---

## Domain Enumeration

### Certificate Reconnaissance
```bash
# Basic certificate enumeration for subdomains
enumcert example.com

# List DNS addresses from certificates
enumcert example.com -l
```

---

## Additional Reconnaissance Resources

- Certificate Transparency: [crt.sh](https://crt.sh/), [Entrust CT Search](https://ui.ctsearch.entrust.com/ui/ctsearchui)
- DNS aggregators: [SecurityTrails](https://securitytrails.com/), [VirusTotal](https://www.virustotal.com/)
- OSINT frameworks: [Shodan](https://www.shodan.io/), [Censys](https://censys.io/)
