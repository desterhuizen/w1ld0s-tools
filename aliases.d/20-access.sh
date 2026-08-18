# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Getting and holding a shell: listeners, encoders, payload tooling.

# Reverse shells and listeners
alias revl="rlwrap nc -lvnp "

# --- PowerShell encoding ---

# PowerShell encoding/decoding
alias tops64="iconv -t utf-16le | base64 -w 0"
alias fromps64="base64 -d | iconv -f utf-16le"

function powershell_encode() {
    pwsh -c '[System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("'"$1"'"))'
}

# .NET tools
alias dotNetToJScript='mono ${HOME}/tools/binaries/DotNetToJScript/bin/x64/Release/DotNetToJScript.exe'

# --- Java ---

alias ysoserial='/usr/lib/jvm/java-11-openjdk-amd64/bin/java -jar ${HOME}/tools/binaries/ysoserial/ysoserial.jar'
