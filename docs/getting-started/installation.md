# Installation

## Prerequisites

Before installing Tekhton, you need:

1. **Bash 4.3 or later** — Tekhton uses `declare -g`, associative arrays, and other bash 4.3+ features
2. **Claude CLI** — Installed and authenticated ([Claude CLI docs](https://docs.anthropic.com/en/docs/claude-cli))
3. **Git** — For version control integration

### Optional Dependencies

- **Python 3.8+** — Required only for the tree-sitter repo map indexer (`--setup-indexer`)
- **tree-sitter** — Installed automatically by the indexer setup

## Install Tekhton

### One-liner (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/geoffgodwin/tekhton/main/install.sh | bash
```

This installs Tekhton to `~/.tekhton` and adds `tekhton` to your PATH.

For a pinned install from a specific release tag:

```bash
curl -sSL https://raw.githubusercontent.com/geoffgodwin/tekhton/v4.78.0/install.sh | bash
```

Replace `v4.78.0` with the desired [release tag](https://github.com/geoffgodwin/tekhton/releases).

To review the script before running:

```bash
curl -sSL https://raw.githubusercontent.com/geoffgodwin/tekhton/main/install.sh -o install.sh
less install.sh    # review
bash install.sh
```

### Homebrew (macOS)

```bash
brew install geoffgodwin/tekhton/tekhton
```

This installs bash 4.3+ and other dependencies automatically.

### From source

```bash
git clone https://github.com/geoffgodwin/tekhton.git ~/.tekhton
cd ~/.tekhton && ./install.sh
```

### Verify Installation

```bash
tekhton --version
```

## Platform Notes

### macOS

macOS ships with bash 3.2, which is too old for Tekhton (Tekhton requires bash 4.3+). Install a modern bash via Homebrew:

```bash
brew install bash
```

After installing, verify the version:

```bash
/opt/homebrew/bin/bash --version   # Apple Silicon
/usr/local/bin/bash --version      # Intel Mac
```

!!! warning "macOS Default Shell"
    Even after installing bash 4.3+ via Homebrew, your default `/bin/bash` is still 3.2.
    Tekhton's shebang (`#!/usr/bin/env bash`) will pick up the Homebrew version
    automatically as long as it's on your PATH before `/bin`.

    Verify with: `which bash` — it should point to the Homebrew version.

### Linux

Most modern Linux distributions ship with bash 4.3+ out of the box. Ubuntu 18.04+,
Debian 10+, Fedora, and Arch all include bash 4.3 or later.

Check your version:

```bash
bash --version
```

### Windows

Tekhton requires Windows Subsystem for Linux (WSL). Native Windows shells
(PowerShell, cmd.exe) and Git Bash are **not supported** — they lack bash 4.3+
features that Tekhton depends on.

**Install WSL:**

1. Open PowerShell as Administrator
2. Run: `wsl --install`
3. Restart your computer
4. Open the Ubuntu terminal from the Start menu
5. Install Tekhton inside WSL following the Linux instructions above

!!! note "Git Bash Is Not Sufficient"
    Git Bash on Windows provides bash 4.4+ but lacks full POSIX compatibility
    that Tekhton requires (particularly around process management and signal
    handling). Use WSL instead.

## Claude CLI Setup

Tekhton requires the Claude CLI to be installed and authenticated. If you haven't
set it up yet:

1. Install the Claude CLI following [Anthropic's instructions](https://docs.anthropic.com/en/docs/claude-cli)
2. Authenticate: `claude auth`
3. Verify: `claude --version`

## What's Next?

Once installed, head to [Your First Project](first-project.md) to set up Tekhton
in a project directory.
