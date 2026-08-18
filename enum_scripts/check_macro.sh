#!/bin/bash
file_name=$1
echo "[+] Generating file name hash"
# Filename goes in as argv rather than spliced into the source, so a name with
# a quote or a space cannot break out of the one-liner.
encoded_name=$(python3 -c 'import sys; code = sys.argv[1]; print("".join([f"{(ord(c)+17):03}" for c in code]))' "$file_name")
echo "[+] Extracting the vba macro from the file"
olevba "$file_name" > /tmp/file_test

if grep -qF -- "$encoded_name" /tmp/file_test; then
   echo "[+] File has the correct filename in the Virus Check"
else
   echo "[-] Check the file name in the Macro it should be:"
   echo "$encoded_name"
fi
