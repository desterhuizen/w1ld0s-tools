# attack

## Overview
The `attack` tool manages your own device information during an engagement — the other half of what `target` records. It sets and retrieves your attack interface and IP address so tools that need them (reverse shells, payload templates, the `serve`/`rssh` helpers in `aliases`) can read one authoritative value.

`setup_links` publishes it as the `attack` command; there is nothing to install by hand.

## Usage

### Basic Commands

* Show current attack configuration:
```bash
attack
```

* Set attack interface (automatically detects the IP):
```bash
attack eth0
```

* Set attack IP manually:
```bash
attack 192.168.1.100
```

* Show help and available interfaces:
```bash
attack -h
# or
attack --help
```

### Integration with Other Tools

The attack tool creates a configuration file named `attacker` beside the `attack` script itself, in `engagement/attack/` of the checkout — or under `$W1LD0S_TOOLS_DIR/engagement/attack/` when that variable is set. It contains environment variables, and you can source it in your scripts by resolving the published `attack` command back to the checkout the same way `attack` locates itself:

```bash
source "$(dirname "$(readlink -f "$(command -v attack)")")/attacker"
echo "Using attack IP: $A_IP"
```

## Examples

### Setting up for a pentest

```bash
# Check available interfaces
attack -h

# Set your attack interface
attack tun0

# Verify configuration
attack

# Use in another script
echo "Starting listener on $A_IP"
nc -lvnp 4444
```

### Troubleshooting

If you're having issues with the tool not detecting your interfaces correctly, you can manually specify the IP address:

```bash
attack 10.10.14.2
```

## Configuration

The tool stores configuration in `engagement/attack/attacker` inside the checkout, or in `$W1LD0S_TOOLS_DIR/engagement/attack/attacker` when that variable is set.

You can manually edit this file if needed, or simply run the tool again to update it.
