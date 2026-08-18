#!/bin/bash

# ========================================================
# recon_sweep - Automated external reconnaissance sweep
# Usage: recon_sweep <domain>
# ========================================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║                Recon Sweep                ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[-]${NC} $1"
}

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 not found. Please install it."
        return 1
    fi
    return 0
}

# Check if domain is provided
if [ -z "$1" ]; then
    print_banner
    echo "Usage: recon_sweep <domain>"
    echo "Example: recon_sweep example.com"
    exit 1
fi

# Configuration
url=$1
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="${url}_${timestamp}"
recon_dir="${output_dir}/recon"
enum_dir="${output_dir}/enum"
scans_dir="${output_dir}/scans"
screenshots_dir="${output_dir}/screenshots"
required_tools=("assetfinder" "amass" "httprobe" "gowitness" "whatweb" "waybackurls" "subjack" "nmap" "nuclei" "ffuf")

print_banner
log_info "Starting reconnaissance on $url"

# Check required tools
missing_tools=0
for tool in "${required_tools[@]}"; do
    if ! check_tool "$tool"; then
        missing_tools=$((missing_tools+1))
    fi
done

if [ $missing_tools -gt 0 ]; then
    log_warning "$missing_tools tools are missing. Some functionality might be limited."
fi

# Create directory structure
log_info "Creating directory structure"
mkdir -p "$recon_dir" "$enum_dir" "$scans_dir" "$screenshots_dir"
log_success "Created output directories in $output_dir"

# Subdomain enumeration
log_info "Starting subdomain enumeration"

# Run assetfinder
log_info "Running assetfinder"
assetfinder "$url" | tee "$recon_dir/assets_assetfinder.txt"
log_success "Assetfinder completed"

# Run amass
log_info "Running amass (this may take a while)"
amass enum -d "$url" -o "$recon_dir/assets_amass.txt"
cat "$recon_dir/assets_amass.txt" | grep "$url" | tee "$recon_dir/assets_amass_min.txt"
log_success "Amass completed"

# Additional subdomain discovery with subfinder (if available)
if command -v subfinder &> /dev/null; then
    log_info "Running subfinder"
    subfinder -d "$url" -o "$recon_dir/assets_subfinder.txt"
    log_success "Subfinder completed"
fi

# Combine and clean assets
log_info "Consolidating discovered subdomains"
find "$recon_dir" -name "assets_*.txt" -exec cat {} \; | sort -u | grep -E ".*$url$|.*\.$url$" > "$recon_dir/assets.txt"
log_success "Found $(wc -l < "$recon_dir/assets.txt") unique domains"

# Check domain liveness
log_info "Checking for live hosts with httprobe"
cat "$recon_dir/assets.txt" | httprobe --prefer-https | tee "$recon_dir/live_assets.txt"
log_success "Found $(wc -l < "$recon_dir/live_assets.txt") live hosts"

# Web screenshots
log_info "Taking screenshots with gowitness"
mkdir -p "$screenshots_dir"
cat "$recon_dir/live_assets.txt" | xargs -I {} gowitness single --disable-db --screenshot-path "$screenshots_dir/" --db-path "$enum_dir/host_info.sqlite3" {}
log_success "Screenshots saved to $screenshots_dir"

# Web technology fingerprinting
log_info "Fingerprinting web technologies with whatweb"
cat "$recon_dir/live_assets.txt" | xargs -I {} whatweb -a 3 {} | tee -a "$enum_dir/whatweb.txt"
log_success "Web technologies identified"

# Historical URL discovery
log_info "Discovering historical URLs with waybackurls"
cat "$recon_dir/live_assets.txt" | xargs -I {} waybackurls {} | sort -u | tee "$enum_dir/waybackurls.txt"
log_success "Historical URLs discovered"

# Check for potential subdomain takeovers
log_info "Checking for subdomain takeover possibilities"
subjack -w "$recon_dir/assets.txt" -timeout 30 -ssl -c /usr/share/subjack/fingerprints.json -v 3 -o "$enum_dir/subdomain_takeover.txt"
log_success "Subdomain takeover check completed"

# Run port scans
log_info "Running port scans with nmap (this may take a while)"
nmap -iL "$recon_dir/assets.txt" -sTV -T4 -p- --min-rate=1000 --max-retries=3 -oA "$scans_dir/nmap_full"
log_success "Port scans completed"

# Run vulnerability scan with nuclei
if command -v nuclei &> /dev/null; then
    log_info "Running vulnerability scan with nuclei"
    nuclei -l "$recon_dir/live_assets.txt" -t cves/ -c 50 -o "$enum_dir/nuclei_vulnerabilities.txt"
    log_success "Vulnerability scan completed"
fi

# Directory brute forcing with ffuf (on sample targets)
if command -v ffuf &> /dev/null; then
    log_info "Running directory brute force on first 5 live hosts"
    head -n 5 "$recon_dir/live_assets.txt" | while read -r host; do
        log_info "Scanning directories on $host"
        ffuf -u "${host}/FUZZ" -w /usr/share/wordlists/dirb/common.txt -c -v -o "$enum_dir/$(echo "$host" | sed 's/[:/]/_/g')_dirs.json"
    done
    log_success "Directory brute force completed for sample targets"
fi

# Generate summary report
log_info "Generating summary report"
echo "# Recon Sweep Summary Report for $url" > "$output_dir/summary.md"
{
  echo "Generated on: $(date)"
  echo ""
  echo "## Discovered Assets"
  echo "- Total subdomains found: $(wc -l < "$recon_dir/assets.txt")"
  echo "- Live hosts: $(wc -l < "$recon_dir/live_assets.txt")"
  echo ""
  echo "## Top Findings"
  echo "### Web Technologies"
  grep -E "^http" "$enum_dir/whatweb.txt" | head -n 10
  echo ""
} >> "$output_dir/summary.md"

log_success "Reconnaissance completed successfully!"
log_info "Results stored in: $output_dir"
log_info "Summary report: $output_dir/summary.md"
