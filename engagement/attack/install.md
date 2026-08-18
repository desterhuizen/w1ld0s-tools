# Attack Tool Installation and Usage

## Overview
The `attack` tool simplifies the management of attacker device information during penetration testing. It allows you to quickly set and retrieve your attack interface and IP address, making it easier to configure tools that need this information.

## Installation

1. Ensure the script is in your path:

```bash
# Option 1: Create a symbolic link in a directory that's in your PATH
ln -sf $(pwd)/attack /usr/local/bin/attack
# OR
ln -sf $(pwd)/attack ~/bin/attack

# Option 2: Add the directory to your PATH
echo 'export PATH=$PATH:$(pwd)' >> ~/.bashrc
# OR for Zsh
echo 'export PATH=$PATH:$(pwd)' >> ~/.zshrc
```

2. Make the script executable:

```bash
chmod +x attack
```

3. Create the configuration directory if it doesn't exist:

```bash
mkdir -p $HOME/tools/repos/w1ld0s-tools/attack
```

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

The attack tool creates a configuration file at `$HOME/tools/repos/w1ld0s-tools/attack/attacker` that contains environment variables. You can source this file in your scripts:

```bash
source $HOME/tools/repos/w1ld0s-tools/attack/attacker
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

The tool stores configuration in: `$HOME/tools/repos/w1ld0s-tools/attack/attacker`

You can manually edit this file if needed, or simply run the tool again to update it.
