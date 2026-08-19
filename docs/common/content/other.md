# Miscellaneous Useful Commands

This document contains miscellaneous commands and techniques that don't fit
elsewhere.

---

## Shell Escapes & Restrictions Bypass

### Restricted Bash (rbash) Escape

```bash
# Connect with SSH and force a non-profile bash shell
ssh <user>@<host> -t "bash --noprofile"
```

### Vi/Vim Escape

```bash
# Set shell and escape to it from within vi/vim
:set shell=/bin/sh
:shell
```

---

## Environment Configuration

### PATH Environment Variable

```bash
# Export a comprehensive PATH for standard directories
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games:/home/kallie/.local/bin
```

---

## Text Manipulation

### Vi/Vim Search and Replace

| Action                       | Command       | Description                                        |
| ---------------------------- | ------------- | -------------------------------------------------- |
| Replace spaces with colons   | `%s/\s\+/:/g` | Converts all whitespace sequences to single colons |
| Replace colons with newlines | `%s/:/\r/g`   | Splits colon-delimited text into multiple lines    |

### Additional Useful Vi Commands

```bash
# Save a file when opened without sudo
:w !sudo tee %

# Convert tabs to spaces
:set expandtab
:retab

# Set specific indentation
:set tabstop=4
:set shiftwidth=4
```
