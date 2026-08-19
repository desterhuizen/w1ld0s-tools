#!/bin/bash
versions=("linpeas.sh" "linpeas_linux_386" "linpeas_linux_amd64" "winPEAS.bat" "winPEASany.exe" "winPEASx64.exe" "winPEASx86.exe" "winPEASany_ofs.exe")
# Same directory `serve peas` lists and serves. aliases exports PEAS_DIR; the
# fallback keeps this script usable on its own.
PEAS_DIR="${PEAS_DIR:-$HOME/tools/binaries/peas}"
mkdir -p "$PEAS_DIR"
for version in "${versions[@]}"; do
	echo "Getting $version"
	wget -q "https://github.com/carlospolop/PEASS-ng/releases/latest/download/$version" -O "$PEAS_DIR/$version"
done
