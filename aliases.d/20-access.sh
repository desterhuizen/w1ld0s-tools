# shellcheck shell=bash
# Sourced by ../aliases at interactive shell startup -- never executed.

# Getting and holding a shell: listeners, encoders, payload tooling.

# --- Listeners ---

alias revl="rlwrap nc -lvnp"

# --- PowerShell encoding ---

alias tops64="iconv -f utf-8 -t utf-16le | base64 -w 0"
alias fromps64="base64 -d | iconv -f utf-16le -t utf-8"

# Produces the same bytes as PowerShell's
# [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd)) without
# handing the payload back to PowerShell to re-parse. It used to splice $1 into
# a double-quoted PowerShell string, where $variables interpolated away,
# `backtick` escapes vanished and a " ended the string early -- the three
# characters a reverse-shell one-liner is built from.
function powershell_encode() {
    if [ $# -ne 1 ]; then
        printf 'usage: powershell_encode <command>\n' >&2
        return 1
    fi

    local encoded
    encoded=$(printf '%s' "$1" | iconv -f utf-8 -t utf-16le | base64 -w 0) || return 1
    printf '%s\n' "$encoded"
}

# --- .NET ---

alias dotNetToJScript='mono ${HOME}/tools/binaries/DotNetToJScript/bin/x64/Release/DotNetToJScript.exe'

# --- Java ---

# ysoserial's gadget chains break on JDK 17 and later, so this pins JDK 11
# rather than using whatever `java` resolves to. The package directory is
# suffixed with the dpkg architecture, so the path cannot be a literal: it was
# java-11-openjdk-amd64 and is java-11-openjdk-arm64 on an arm workstation.
function ysoserial() {
    local arch java
    arch=$(dpkg --print-architecture 2>/dev/null)
    java="/usr/lib/jvm/java-11-openjdk-$arch/bin/java"

    if [ ! -x "$java" ]; then
        printf 'ysoserial: no JDK 11 at %s\n' "$java" >&2
        return 1
    fi

    "$java" -jar "${HOME}/tools/binaries/ysoserial/ysoserial.jar" "$@"
}
