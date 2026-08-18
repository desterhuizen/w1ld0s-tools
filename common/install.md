# w1ld0s-tools Installation Guide

This document explains how to set up the w1ld0s-tools repository and its dependencies for penetration testing operations.

## Prerequisites

### Required Tools

- **Terminal Markdown Viewer (glow)**: For viewing markdown files in the terminal
  - [GitHub Repo](https://github.com/charmbracelet/glow)

- **Task Warrior** (optional): For managing pentest checklists
  - [Official Website](https://taskwarrior.org/)

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/desterhuizen/w1ld0s-tools.git ~/tools/repos/w1ld0s-tools
```

### 2. Install Dependencies

#### On Debian/Ubuntu

```bash
# Install glow for markdown viewing
sudo apt-get update
sudo apt-get install -y golang
go install github.com/charmbracelet/glow@latest

# Install Task Warrior (optional - for checklists)
sudo apt-get install -y taskwarrior
```

#### On macOS

```bash
# Install glow using Homebrew
brew install glow

# Install Task Warrior (optional)
brew install task
```

#### On Arch Linux

```bash
# Install glow
sudo pacman -S glow

# Install Task Warrior (optional)
sudo pacman -S task
```

### 3. Set Up the Common Command

Link the common script to your path for easy access:

```bash
# Create a bin directory if it doesn't exist
mkdir -p ~/bin

# Link the common script
ln -s ~/tools/repos/w1ld0s-tools/common/common ~/bin/common

# Add ~/bin to your PATH if it's not already there
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
# Or for zsh users
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
```

### 4. Enable Command Completion (Optional)

For easy tab completion with the common command:

```bash
# For bash
common -c >> ~/.bashrc
source ~/.bashrc

# For zsh
common -c >> ~/.zshrc
source ~/.zshrc
```

## Usage

The `common` command provides quick access to various pentesting reference documents:

```bash
# Show usage information and available documents
common

# View a specific document
common ad        # Active Directory references
common web       # Web pentesting references
common shell     # Shell commands and techniques

# Edit a document
common -v ad     # Open the AD document in vi

# Search across all documents
common -g "password spray"  # Find references to "password spray"

# Import a checklist into Task Warrior
common -t web    # Import web pentest checklist
```

## Additional Tools

The repository includes many other scripts and tools; `scriptlist` enumerates them.

Provisioning the workstation itself — apt packages, pipx venvs, Go tools, wordlists,
i3 — is not this repository's job. That lives in
[w1ld0s](https://github.com/desterhuizen/w1ld0s), which also clones this repo and runs
`setup_links` for you.

## Updating

To update the repository with the latest scripts and techniques:

```bash
cd ~/tools/repos/w1ld0s-tools
git pull origin main
```
