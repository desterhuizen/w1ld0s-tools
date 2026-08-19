# AutoRecon Installation Guide

AutoRecon is an automated reconnaissance tool designed for penetration testing and bug bounty hunting. This guide will help you install all the necessary dependencies to run AutoRecon effectively.

## Prerequisites

- A Linux or macOS system
- Go programming language installed
- Python 3.x installed
- Git installed
- Administrative privileges for system-wide installations

## Required Tools

AutoRecon relies on the following tools:

1. assetfinder - For finding domains and subdomains
2. amass - For subdomain enumeration
3. httprobe - For checking live hosts
4. gowitness - For taking web screenshots
5. whatweb - For fingerprinting web technologies
6. waybackurls - For discovering historical URLs
7. subjack - For checking subdomain takeover possibilities
8. nmap - For port scanning
9. nuclei - For vulnerability scanning
10. ffuf - For directory brute forcing

## Installation Instructions

### For Kali Systems

```bash
# Update package repositories
sudo apt update

# Install basic tools
sudo apt install -y nmap whatweb git python3 python3-pip golang

# Install Go-based tools
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/OWASP/Amass/v3/...@latest
go install -v github.com/tomnomnom/httprobe@latest
go install -v github.com/sensepost/gowitness@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/haccer/subjack@latest
go install -v github.com/ffuf/ffuf@latest
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Install Python-based tools (if any)
pipx install subfinder

# Add Go binaries to your PATH (if not already done)
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.zshrc
source ~/.zshrc
```

### For macOS

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install basic tools
brew install nmap whatweb git python3 go

# Install Go-based tools
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/OWASP/Amass/v3/...@latest
go install -v github.com/tomnomnom/httprobe@latest
go install -v github.com/sensepost/gowitness@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/haccer/subjack@latest
go install -v github.com/ffuf/ffuf@latest
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Install Python-based tools (if any)
pip3 install subfinder

# Add Go binaries to your PATH (if not already done)
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.zshrc
source ~/.zshrc
```

## Additional Configuration

### Subjack Configuration

Subjack requires fingerprints.json to be present in `/usr/share/subjack/`. You can set this up with:

```bash
sudo mkdir -p /usr/share/subjack/
sudo wget -O /usr/share/subjack/fingerprints.json https://raw.githubusercontent.com/haccer/subjack/master/fingerprints.json
```

### Wordlists for Directory Brute Forcing

The script uses `/usr/share/wordlists/dirb/common.txt` for directory brute forcing. Make sure this file exists or install it:

```bash
# For Debian/Ubuntu
sudo apt install -y wordlists

# For other systems, you can manually create the directory and download wordlists
sudo mkdir -p /usr/share/wordlists/dirb/
sudo wget -O /usr/share/wordlists/dirb/common.txt https://raw.githubusercontent.com/v0re/dirb/master/wordlists/common.txt
```

## Verifying Installation

To verify that all the required tools are installed correctly, run:

```bash
# Check if tools are available in your PATH
command -v assetfinder amass httprobe gowitness whatweb waybackurls subjack nmap nuclei ffuf
```

If any tool is missing, you'll need to install it using the instructions above.

## Usage

Once all dependencies are installed, you can use AutoRecon as follows:

```bash
./autorecon.sh example.com
```

This will:
1. Perform subdomain enumeration
2. Check for live hosts
3. Take screenshots of web pages
4. Fingerprint web technologies
5. Discover historical URLs
6. Check for subdomain takeover possibilities
7. Run port scans
8. Scan for vulnerabilities
9. Perform directory brute forcing (on sample targets)
10. Generate a summary report

All results will be stored in a timestamped directory with the domain name.

## Troubleshooting

If you encounter any issues:

1. Ensure all tools are correctly installed and accessible in your PATH
2. Check that you have the necessary permissions to execute the script
3. Verify that required configuration files (like fingerprints.json) exist in the expected locations
4. Make sure wordlists are available in the specified paths

For more detailed information about each tool, refer to their respective GitHub repositories or documentation.
