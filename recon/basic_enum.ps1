# Function to display headers
function Print-Header {
    param ($message)
    Write-Host "`n[+] $message" -ForegroundColor Cyan
    Write-Host "------------------------------------"
}

# 1. System Information
Print-Header "Gathering System Information"
systeminfo | Select-String "OS Name", "OS Version", "System Manufacturer", "System Model"
Write-Host "`nHotfixes Installed:" -ForegroundColor Yellow
wmic qfe get Caption,Description,HotFixID,InstalledOn

# 2. User Enumeration
Print-Header "Enumerating Users & Privileges"
whoami /priv
Write-Host "`nLogged-in Users:" -ForegroundColor Yellow
query user
Write-Host "`nDomain Admins:" -ForegroundColor Yellow
net group "Domain Admins" /domain
Write-Host "`nLocal Administrators:" -ForegroundColor Yellow
net localgroup Administrators

# 3. Privilege Escalation Checks
Print-Header "Checking Privilege Escalation Paths"
Write-Host "`nChecking for AlwaysInstallElevated Misconfiguration..." -ForegroundColor Yellow
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated

Write-Host "`nChecking Writable Directories in PATH..." -ForegroundColor Yellow
echo $env:PATH -split ";" | % { if (Test-Path $_) { Get-Acl $_ } }

# 4. Lateral Movement
Print-Header "Finding Lateral Movement Opportunities"
Write-Host "`nChecking Network Shares..." -ForegroundColor Yellow
net view \\127.0.0.1
Write-Host "`nMapped Drives:" -ForegroundColor Yellow
net use

Write-Host "`nFinding Service Accounts for Kerberoasting..." -ForegroundColor Yellow
function Get-KerberoastableAccounts {
    Write-Host "`n[+] Checking for Kerberoastable Accounts..." -ForegroundColor Cyan

    try {
        # Try LDAP Query to fetch users with SPNs (Requires Privileges)
        $searcher = New-Object DirectoryServices.DirectorySearcher
        $searcher.Filter = "(&(objectClass=user)(servicePrincipalName=*))"
        $searcher.SearchRoot = "LDAP://$env:USERDOMAIN"
        $searcher.PageSize = 1000
        $searcher.PropertiesToLoad.Add("sAMAccountName")
        $results = $searcher.FindAll()

        if ($results.Count -gt 0) {
            Write-Host "[+] Found Potential Kerberoast Targets (Excluding Machine Accounts):" -ForegroundColor Yellow

            # Filter out machine accounts (those ending with $)
            $results | ForEach-Object {
                $user = $_.Properties["sAMAccountName"][0]
                if ($user -notlike "*$") {  # Exclude machine accounts
                    Write-Host "    -> $user"
                }
            }
        } else {
            Write-Host "[*] No Kerberoastable accounts found via LDAP." -ForegroundColor Green
        }
    } catch {
        Write-Host "[!] Access Denied! Falling back to klist..." -ForegroundColor Red

        # Alternative: Use klist to list available tickets (No Privileges Needed)
        $tickets = klist | Select-String "ServiceName" | ForEach-Object { ($_ -split ":")[1].Trim() }
        if ($tickets) {
            Write-Host "[+] Found Kerberos Service Tickets:" -ForegroundColor Yellow
            $tickets | ForEach-Object { Write-Host "    -> $_" }
        } else {
            Write-Host "[*] No Kerberos tickets found on this machine." -ForegroundColor Green
        }
    }
}


# Run Kerberoasting Check
Get-KerberoastableAccounts


# 5. Delegation Checks (Non-PowerView)
Print-Header "Checking Delegation Settings"

# Function to get delegation settings via LDAP
function Get-LDAPDelegation {
    param (
        [string]$ldapFilter
    )
    $searcher = New-Object DirectoryServices.DirectorySearcher
    $searcher.Filter = $ldapFilter
    $searcher.SearchRoot = "LDAP://$env:USERDOMAIN"
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.AddRange(@("cn", "sAMAccountName", "userAccountControl", "msDS-AllowedToDelegateTo", "msDS-AllowedToActOnBehalfOfOtherIdentity"))
    $results = $searcher.FindAll()

    foreach ($entry in $results) {
        $cn = $entry.Properties["cn"][0]
        $sam = $entry.Properties["sAMAccountName"][0]
        $uac = $entry.Properties["userAccountControl"][0]
        $constrained = $entry.Properties["msDS-AllowedToDelegateTo"]
        $rbcd = $entry.Properties["msDS-AllowedToActOnBehalfOfOtherIdentity"]

        # Flag to track if the entry has delegation settings
        $hasDelegation = $false

        # Identify Unconstrained Delegation (UAC flag 0x80000)
        if ($uac -band 0x80000) {
            Write-Host "[!] Unconstrained Delegation: $sam ($cn)" -ForegroundColor Red
            $hasDelegation = $true
        }

        # Identify Constrained Delegation
        if ($constrained) {
            Write-Host "[+] Constrained Delegation: $sam ($cn) -> $($constrained -join ', ')" -ForegroundColor Yellow
            $hasDelegation = $true
        }

        # Identify Resource-Based Constrained Delegation (RBCD)
        if ($rbcd) {
            Write-Host "[*] RBCD Delegation: $sam ($cn)" -ForegroundColor Cyan
            $hasDelegation = $true
        }

        # If no delegation, do not print anything
    }
}

# Run Delegation Checks for Computers & Users
Write-Host "`n[+] Checking Delegation Settings for Users & Computers..." -ForegroundColor Cyan
Get-LDAPDelegation "(&(|(objectClass=computer)(objectClass=user)))"

Write-Host "`nChecking for New User Accounts..." -ForegroundColor Yellow
net user


# Check if PowerView is Loaded
function Check-PowerView {
    if (Get-Command Get-DomainTrust -ErrorAction SilentlyContinue) {
        Write-Host "[+] PowerView is Loaded!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[!] PowerView is NOT Loaded. Trust enumeration will not work." -ForegroundColor Red
        return $false
    }
}

# Enumerate Forest Trusts and Check for SID Filtering
function Get-ForestTrusts {
    if (-not (Check-PowerView)) { return }  # Stop if PowerView is not loaded

    Write-Host "`n[+] Enumerating Forest Trusts..." -ForegroundColor Cyan
    $trusts = Get-DomainTrust

    if ($trusts) {
        foreach ($trust in $trusts) {
            Write-Host "    -> Trust: $($trust.SourceName) -> $($trust.TargetName) ($($trust.TrustType) / $($trust.TrustDirection))"

            # Check if SID Filtering is enabled (TREAT_AS_EXTERNAL)
            if ($trust.TrustAttributes -match "TREAT_AS_EXTERNAL") {
                Write-Host "    [!] SID Filtering is Enabled (TREAT_AS_EXTERNAL) for this trust!" -ForegroundColor Yellow
                Write-Host "        -> Recommendation: Check for foreign group memberships, as SID history attacks are blocked." -ForegroundColor Cyan
            }

            # Highlight Potential Attack Paths
            if ($trust.TrustDirection -match "BiDirectional|Inbound") {
                Write-Host "    [!] Possible Attack: Inbound trust allows access from $($trust.TargetName)!" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "[*] No Forest Trusts Found." -ForegroundColor Green
    }
}


# Enumerate Foreign Group Memberships in Trusted Domains
function Get-ForeignGroupMemberships {
    if (-not (Check-PowerView)) { return }  # Stop if PowerView is not loaded

    # Check if running as SYSTEM
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($currentUser.Name -ne "NT AUTHORITY\SYSTEM") {
        Write-Host "[!] WARNING: This script should be run as SYSTEM for full results!" -ForegroundColor Red
    }

    Write-Host "`n[+] Enumerating Trusted Domains..." -ForegroundColor Cyan
    $trustedDomains = Get-DomainTrust | Select-Object -ExpandProperty TargetName

    if ($trustedDomains) {
        foreach ($domain in $trustedDomains) {
            Write-Host "`n[+] Checking Foreign Group Memberships in Trusted Domain: $domain" -ForegroundColor Cyan
            $foreignGroups = Get-DomainForeignGroupMember -Domain $domain

            if ($foreignGroups) {
                $foreignGroups | ForEach-Object {
                    # Resolve SID to Name if present
                    $resolvedName = $_.MemberName
                    if ($_.MemberName) {
                        try {
                            $resolvedName = ConvertFrom-SID $_.MemberName
                        } catch {
                            $resolvedName = $_.MemberName  # Fallback if conversion fails
                        }
                    }

                    Write-Host "    -> Foreign User: $resolvedName in $($_.GroupName) (Domain: $domain)"
                    
                    if ($_.GroupName -match "Administrators|Domain Admins|Enterprise Admins") {
                        Write-Host "    [!] Potential Risk: Foreign user in a privileged group!" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "[*] No Foreign Users Found in Privileged Groups for $domain." -ForegroundColor Green
            }
        }
    } else {
        Write-Host "[*] No Trusted Domains Found." -ForegroundColor Green
    }
}

# Check for exposed SpoolSS on all trusted domain controllers
function Check-AllTrustedDomainSpoolSS {
    if (-not (Check-PowerView)) { return }  # Ensure PowerView is loaded

    Write-Host "`n[+] Enumerating Trusted Domains..." -ForegroundColor Cyan
    $trustedDomains = Get-DomainTrust | Select-Object -ExpandProperty TargetName

    if (-not $trustedDomains) {
        Write-Host "[*] No Trusted Domains Found." -ForegroundColor Green
        return
    }

    foreach ($domain in $trustedDomains) {
        Write-Host "`n[+] Checking Domain: $domain" -ForegroundColor Cyan
        
        # Get domain controllers for the trusted domain
        $domainControllers = Get-DomainController -Domain $domain | Select-Object -ExpandProperty Name

        if (-not $domainControllers) {
            Write-Host "    [*] No Domain Controllers Found for $domain." -ForegroundColor Yellow
            continue
        }

        foreach ($dc in $domainControllers) {
            Write-Host "    -> Checking SpoolSS on $dc..."

            # Check if SMB (port 445) is open
            $smbCheck = Test-NetConnection -ComputerName $dc -Port 445 -InformationLevel Quiet
            if (-not $smbCheck) {
                Write-Host "        [!] SMB (port 445) is closed on $dc. Skipping SpoolSS check." -ForegroundColor Yellow
                continue
            }

            # Check for spoolss pipe
            $spoolssCheck = cmd /c "dir \\$dc\pipe\spoolss" 2>&1
            if ($spoolssCheck -match "File Not Found") {
                Write-Host "        [*] SpoolSS is NOT exposed on $dc." -ForegroundColor Green
            } else {
                Write-Host "        [!] WARNING: SpoolSS is exposed on $dc!" -ForegroundColor Red
                Write-Host "            -> This may allow Printer Bug exploitation (e.g., remote authentication coercion)." -ForegroundColor Yellow
            }
        }
    }
}


Write-Host "`nChecking forest Trusts..." -ForegroundColor Yellow
Get-ForestTrusts
Write-Host "`nChecking foreighn group memberships..." -ForegroundColor Yellow
Get-ForeignGroupMemberships

Write-Host "`nChecking domain spoolss..." -ForegroundColor Yellow
Check-AllTrustedDomainSpoolSS


Write-Host "`n[+] Basic ENUM Execution Completed!" -ForegroundColor Green

