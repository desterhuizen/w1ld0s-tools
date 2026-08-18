#!/bin/bash
#
# target - A penetration testing project management script
#
# This script helps organize penetration testing projects by managing
# target information and project directories.

# Set script directory path dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"

# Create config directory if it doesn't exist
mkdir -p "${CONFIG_DIR}"

# Define config files
CONFIG_FILE="${CONFIG_DIR}/config.sh"
TARG_FILE="${CONFIG_DIR}/targ.sh"
BASE_FILE="${CONFIG_DIR}/base.sh"
NAME_FILE="${CONFIG_DIR}/name.sh"
VPN_FILE="${CONFIG_DIR}/vpn.sh"
LAB_FILE="${CONFIG_DIR}/lab.sh"

# Create default config files if they don't exist
if [ ! -f "${CONFIG_FILE}" ]; then
    cat > "${CONFIG_FILE}" << EOF
# Main configuration file for target script
# Created: $(date)

# Default directory structure to create for each project
PROJECT_DIRS=(
    "scans"
    "exploits"
    "files"
    "notes"
    "evidence"
    "credentials"
)

# Default files to create for each project
PROJECT_FILES=(
    "users"
    "passwords"
    "words"
    "notes.md"
)

# Default symlinks to create
declare -A PROJECT_SYMLINKS=(
    ["/var/www/html"]="www"
    ["$HOME/smbshare"]="smb"
)
EOF
fi

if [ ! -f "${BASE_FILE}" ]; then
    echo "export TARGET_BASE=$HOME/pentest-projects" > "${BASE_FILE}"
fi

if [ ! -f "${TARG_FILE}" ]; then
    echo "export IP=" > "${TARG_FILE}"
    echo "export URL=" >> "${TARG_FILE}"
fi

if [ ! -f "${NAME_FILE}" ]; then
    echo "export TARGET_NAME=" > "${NAME_FILE}"
fi

if [ ! -f "${VPN_FILE}" ]; then
    echo "export TARGET_VPN=" > "${VPN_FILE}"
fi

if [ ! -f "${LAB_FILE}" ]; then
    echo "export TARGET_LAB=" > "${LAB_FILE}"
fi

# Source configuration files
source "${CONFIG_FILE}"
source "${TARG_FILE}"
source "${BASE_FILE}"
source "${NAME_FILE}"
source "${VPN_FILE}"
source "${LAB_FILE}"

# Set window title if in a terminal
export TITLE="${TARGET_NAME:-$IP}"

# Function to display error messages and exit
function error_exit() {
    echo -e "\033[1;31mERROR:\033[0m $1" >&2
    exit 1
}

# Function to display success messages
function success_message() {
    echo -e "\033[1;32mSUCCESS:\033[0m $1"
}

# Function to display info messages
function info_message() {
    echo -e "\033[1;34mINFO:\033[0m $1"
}

# Function to validate IP address
function validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    return $stat
}

# Resolve the full path to a host project, lab-aware.
# With a lab set:  ${TARGET_BASE}/${TARGET_LAB}/${host}
# Without a lab:   ${TARGET_BASE}/${host}   (flat, legacy behaviour)
function hostPath() {
    local host="${1:-${TARGET_NAME:-$IP}}"
    if [[ -n "$TARGET_LAB" ]]; then
        echo "${TARGET_BASE}/${TARGET_LAB}/${host}"
    else
        echo "${TARGET_BASE}/${host}"
    fi
}

# Resolve the full path to the current lab root
function labPath() {
    echo "${TARGET_BASE}/${TARGET_LAB}"
}

# Function to scaffold a lab / network root (shared, cross-host resources).
# Idempotent: safe to call whenever a host is created under a lab.
function createLab() {
    if [[ -z "$TARGET_LAB" ]]; then
        return 0
    fi

    local lab_path
    lab_path="$(labPath)"
    local created=0
    [[ -d "$lab_path" ]] || created=1

    mkdir -p "${lab_path}/credentials" || error_exit "Failed to create lab credentials directory"
    mkdir -p "${lab_path}/loot" || error_exit "Failed to create lab loot directory"

    # Shared VPN symlink into the lab root (VPN itself stays global)
    if [[ -n "$TARGET_VPN" ]]; then
        ln -sf "${TARGET_VPN}" "${lab_path}/vpn" || info_message "Failed to create lab vpn symlink"
    fi

    # Network map / host inventory (don't clobber an existing one)
    if [[ ! -f "${lab_path}/network.md" ]]; then
        cat > "${lab_path}/network.md" << EOF
# Network Map: ${TARGET_LAB}

- Created: $(date)
- VPN: ${TARGET_VPN:-Not set}

## Hosts

| Host | IP | Role | Creds | Notes |
|------|----|------|-------|-------|
|      |    |      |       |       |

## Pivots / Routes

-
EOF
    fi

    # Lab README (don't clobber an existing one)
    if [[ ! -f "${lab_path}/README.md" ]]; then
        cat > "${lab_path}/README.md" << EOF
# Lab / Network: ${TARGET_LAB}

- Created: $(date)
- VPN: ${TARGET_VPN:-Not set}

Shared, cross-host resources for this lab live here:

- \`credentials/\` — creds reusable across hosts
- \`loot/\` — loot gathered across hosts
- \`network.md\` — host inventory / network map
- \`vpn\` — symlink to the lab VPN config dir

Each host is its own subdirectory (\`target -m\`).
EOF
    fi

    if [[ $created -eq 1 ]]; then
        success_message "Lab created at: ${lab_path}"
    fi
}

# Function to create project structure
function createProject() {
    local folder=$1

    # Ensure the parent lab exists (no-op when no lab is set)
    createLab

    local project_path
    project_path="$(hostPath "$folder")"

    # Check if project directory already exists
    if [ -d "${project_path}" ]; then
        info_message "Project directory already exists at: ${project_path}"
        read -p "Do you want to overwrite it? (y/n): " confirm
        if [[ $confirm != [yY] ]]; then
            info_message "Project creation canceled."
            return
        fi
    fi

    # Create main project directory
    mkdir -p "${project_path}" || error_exit "Failed to create project directory"

    # Create subdirectories
    for dir in "${PROJECT_DIRS[@]}"; do
        mkdir -p "${project_path}/${dir}" || error_exit "Failed to create ${dir} directory"
    done

    # Create symlinks
    for source in "${!PROJECT_SYMLINKS[@]}"; do
        local target="${PROJECT_SYMLINKS[$source]}"
        ln -sf "${source}" "${project_path}/${target}" || info_message "Failed to create symlink to ${source}"
    done

    # Create empty files
    for file in "${PROJECT_FILES[@]}"; do
        touch "${project_path}/${file}" || info_message "Failed to create ${file}"
    done

    # Create a README file
    cat > "${project_path}/README.md" << EOF
# Penetration Testing Project: ${folder}

## Project Information
- Lab / Network: ${TARGET_LAB:-none}
- Target Name: ${TARGET_NAME}
- Target IP: ${IP}
- Target URL: ${URL}
- Created: $(date)

## Directory Structure
$(for dir in "${PROJECT_DIRS[@]}"; do echo "- ${dir}/"; done)

## Notes
- Add project notes here
EOF

    success_message "Project created successfully at: ${project_path}"
}

# Display usage information
function show_usage() {
    cat << EOF
Usage: target [IP_ADDRESS] [OPTION] [VALUE]

DESCRIPTION:
    Manage penetration testing project directories and target information.

OPTIONS:
    -c, --change       Change to target project directory
    -cb, --change-base Change to base directory
    -cv, --change-vpn  Change to VPN directory
    -cl, --change-lab  Change to lab/network directory (-cn alias)
    -m, --make         Create a new project directory structure
    -b, --base PATH    Set base directory to PATH
    -v, --vpn PATH     Set VPN directory to PATH
    -L, --lab NAME     Set lab/network to NAME (-N/--network alias; '-' clears)
    -n, --name NAME    Set target name to NAME
    -u, --url URL      Set target URL to URL
    -i, --info         Display current target information
    -l, --list         List all projects (or hosts, inside a lab)
    -h, --help         Display this help message

LAB / NETWORK LAYER:
    When a lab is set, projects nest under it:
        \${BASE}/\${LAB}/\${HOST}   e.g. ~/pentest-projects/dante/host-01
    The lab root holds shared credentials/, loot/, network.md and a vpn
    symlink. With no lab set, behaviour is the flat \${BASE}/\${HOST}.

EXAMPLES:
    target 192.168.1.1          Set target IP to 192.168.1.1
    target -n client-x          Set target name to client-x
    target -L dante             Set lab/network to dante (scaffolds it)
    target -b /path/to/base     Set base directory
    target -m                   Create project directory
    target -c                   Change to project directory
    target -cl                  Change to lab directory
    target -L -                 Clear lab (back to flat mode)
EOF
}

# Main logic
if [ $# -eq 0 ]; then
    # Display current configuration
    echo -e "Target Base\t: ${TARGET_BASE:-Not set}"
    echo -e "Target Lab\t: ${TARGET_LAB:-Not set}"
    echo -e "Target Name\t: ${TARGET_NAME:-Not set}"
    echo -e "Target IP\t: ${IP:-Not set}"
    echo -e "Target URL\t: ${URL:-Not set}"
    echo -e "Target VPN\t: ${TARGET_VPN:-Not set}"
    echo -e "\nUse 'target -h' for help"

elif [[ $1 == "-cb" || $1 == "--change-base" ]]; then
    info_message "Changing to: ${TARGET_BASE}"
    cd "${TARGET_BASE}" || error_exit "Failed to change directory to ${TARGET_BASE}"
    $SHELL

elif [[ $1 == "-cv" || $1 == "--change-vpn" ]]; then
    if [[ -z "${TARGET_VPN}" ]]; then
        error_exit "No VPN directory set. Use 'target -v /path/to/vpn' first."
    fi
    if [[ ! -d "${TARGET_VPN}" ]]; then
        error_exit "VPN directory does not exist: ${TARGET_VPN}"
    fi
    info_message "Changing to: ${TARGET_VPN}"
    cd "${TARGET_VPN}" || error_exit "Failed to change directory to ${TARGET_VPN}"
    $SHELL

elif [[ $1 == "-cl" || $1 == "--change-lab" || $1 == "-cn" ]]; then
    if [[ -z "${TARGET_LAB}" ]]; then
        error_exit "No lab set. Use 'target -L NAME' first."
    fi
    lab_path="$(labPath)"
    if [[ ! -d "$lab_path" ]]; then
        info_message "Lab directory does not exist: ${lab_path}"
        read -p "Would you like to create it now? (y/n): " create
        if [[ $create == [yY] ]]; then
            createLab
        else
            exit 0
        fi
    fi
    info_message "Changing to: ${lab_path}"
    cd "${lab_path}" || error_exit "Failed to change directory to ${lab_path}"
    $SHELL

elif [[ $1 == "-c" || $1 == "--change" ]]; then
    target_dir="${TARGET_NAME:-$IP}"
    if [[ -z "$target_dir" ]]; then
        error_exit "No target name or IP set. Use 'target IP' or 'target -n NAME' first."
    fi

    project_path="$(hostPath "$target_dir")"
    if [[ ! -d "$project_path" ]]; then
        info_message "Project directory does not exist: ${project_path}"
        read -p "Would you like to create it now? (y/n): " create
        if [[ $create == [yY] ]]; then
            createProject "$target_dir"
        else
            exit 0
        fi
    fi

    info_message "Changing to: ${project_path}"
    cd "${project_path}" || error_exit "Failed to change directory to ${project_path}"
    $SHELL

elif [[ $1 == "-m" || $1 == "--make" ]]; then
    target_dir="${TARGET_NAME:-$IP}"
    if [[ -z "$target_dir" ]]; then
        error_exit "No target name or IP set. Use 'target IP' or 'target -n NAME' first."
    fi
    createProject "$target_dir"

elif [[ $1 == "-b" || $1 == "--base" ]]; then
    if [[ -z $2 ]]; then
        info_message "Current base directory: ${TARGET_BASE}"
        info_message "To change base directory, use: target -b /path/to/directory"
    else
        # Expand ~ to $HOME if present
        new_base=${2/#\~/$HOME}

        # Create directory if it doesn't exist
        if [[ ! -d "$new_base" ]]; then
            read -p "Directory does not exist. Create it? (y/n): " create
            if [[ $create == [yY] ]]; then
                mkdir -p "$new_base" || error_exit "Failed to create directory: $new_base"
            else
                error_exit "Base directory change canceled."
            fi
        fi

        echo "export TARGET_BASE=\"$new_base\"" > "${BASE_FILE}"
        source "${BASE_FILE}"
        success_message "Base directory set to: ${TARGET_BASE}"
    fi

elif [[ $1 == "-v" || $1 == "--vpn" ]]; then
    if [[ -z $2 ]]; then
        info_message "Current VPN directory: ${TARGET_VPN:-Not set}"
        info_message "To change VPN directory, use: target -v /path/to/directory"
    else
        new_vpn=${2/#\~/$HOME}

        if [[ ! -d "$new_vpn" ]]; then
            read -p "Directory does not exist. Create it? (y/n): " create
            if [[ $create == [yY] ]]; then
                mkdir -p "$new_vpn" || error_exit "Failed to create directory: $new_vpn"
            else
                error_exit "VPN directory change canceled."
            fi
        fi

        echo "export TARGET_VPN=\"$new_vpn\"" > "${VPN_FILE}"
        source "${VPN_FILE}"
        success_message "VPN directory set to: ${TARGET_VPN}"
    fi

elif [[ $1 == "-L" || $1 == "--lab" || $1 == "-N" || $1 == "--network" ]]; then
    if [[ -z $2 ]]; then
        info_message "Current lab/network: ${TARGET_LAB:-Not set}"
        info_message "To set a lab, use: target -L NAME   (use '-' to clear)"
    elif [[ $2 == "-" || $2 == "none" ]]; then
        echo "export TARGET_LAB=" > "${LAB_FILE}"
        source "${LAB_FILE}"
        success_message "Lab cleared. Projects will use flat layout: \${BASE}/\${HOST}"
    else
        echo "export TARGET_LAB=\"$2\"" > "${LAB_FILE}"
        source "${LAB_FILE}"
        success_message "Lab/network set to: ${TARGET_LAB}"

        lab_path="$(labPath)"
        if [[ ! -d "$lab_path" ]]; then
            read -p "Lab directory does not exist. Create it now? (y/n): " create
            if [[ $create == [yY] ]]; then
                createLab
            fi
        fi
    fi

elif [[ $1 == "-n" || $1 == "--name" ]]; then
    if [[ -z $2 ]]; then
        error_exit "No name provided. Usage: target -n NAME"
    fi
    echo "export TARGET_NAME=\"$2\"" > "${NAME_FILE}"
    source "${NAME_FILE}"
    success_message "Target name set to: ${TARGET_NAME}"

elif [[ $1 == "-u" || $1 == "--url" ]]; then
    if [[ -z $2 ]]; then
        error_exit "No URL provided. Usage: target -u URL"
    fi

    # Update URL in targ file while preserving IP
    if [[ -f "${TARG_FILE}" && -n "$(grep IP "${TARG_FILE}")" ]]; then
        current_ip=$(grep "export IP=" "${TARG_FILE}" | cut -d= -f2)
        echo "export IP=${current_ip}" > "${TARG_FILE}"
        echo "export URL=\"$2\"" >> "${TARG_FILE}"
    else
        echo "export IP=" > "${TARG_FILE}"
        echo "export URL=\"$2\"" >> "${TARG_FILE}"
    fi

    source "${TARG_FILE}"
    success_message "Target URL set to: ${URL}"

elif [[ $1 == "-l" || $1 == "--list" ]]; then
    if [[ -n "${TARGET_LAB}" ]]; then
        # Inside a lab: list host projects, hiding shared lab resources
        lab_path="$(labPath)"
        if [[ ! -d "$lab_path" ]]; then
            error_exit "Lab directory does not exist: ${lab_path}"
        fi
        echo "Hosts in lab '${TARGET_LAB}' (${lab_path}):"
        for entry in "${lab_path}"/*/; do
            [[ -d "$entry" ]] || continue
            name="$(basename "$entry")"
            case "$name" in
                credentials|loot|vpn) continue ;;
            esac
            echo "  - ${name}"
        done
    else
        # No lab: list base entries, marking which are labs (have a network.md)
        if [[ ! -d "${TARGET_BASE}" ]]; then
            error_exit "Base directory does not exist: ${TARGET_BASE}"
        fi
        echo "Projects in ${TARGET_BASE}:"
        for entry in "${TARGET_BASE}"/*/; do
            [[ -d "$entry" ]] || continue
            name="$(basename "$entry")"
            if [[ -f "${entry}network.md" ]]; then
                echo "  - ${name}/  (lab)"
            else
                echo "  - ${name}"
            fi
        done
    fi

elif [[ $1 == "-i" || $1 == "--info" ]]; then
    echo "Target Configuration:"
    echo "--------------------"
    echo "Base Directory: ${TARGET_BASE}"
    echo "Target Lab:     ${TARGET_LAB:-Not set}"
    echo "Target Name:    ${TARGET_NAME:-Not set}"
    echo "Target IP:      ${IP:-Not set}"
    echo "Target URL:     ${URL:-Not set}"
    echo "VPN Directory:  ${TARGET_VPN:-Not set}"
    echo "Config Dir:     ${CONFIG_DIR}"
    echo "Project Path:   $(hostPath)"

elif [[ $1 == "-h" || $1 == "--help" ]]; then
    show_usage

elif [[ ${1:0:1} == "-" ]]; then
    error_exit "Invalid option: $1. Use 'target -h' for help."

else
    # Assume it's an IP address
    if validate_ip "$1"; then
        echo "export IP=\"$1\"" > "${TARG_FILE}"
        echo "export URL=\"http://$1\"" >> "${TARG_FILE}"
        source "${TARG_FILE}"
        success_message "Target IP set to: ${IP}"
        success_message "Target URL set to: ${URL}"
    else
        error_exit "Invalid IP address: $1"
    fi
fi
