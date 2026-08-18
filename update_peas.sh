#!/bin/bash
versions=("linpeas.sh" "linpeas_linux_386" "linpeas_linux_amd64" "winPEAS.bat" "winPEASany.exe" "winPEASx64.exe" "winPEASx86.exe" "winPEASany_ofs.exe")
for version in "${versions[@]}"; do
	echo "Getting $version"
	wget -q "https://github.com/carlospolop/PEASS-ng/releases/latest/download/$version" -O "$HOME/tools/binaries/peas/$version"
done
