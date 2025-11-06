# environment

This repository provides a foundational setup script and configuration snippets to prepare a workstation with common tooling. The script detects the host environment, installs required packages, and merges configuration updates into existing dotfiles.

## Repository layout

- `setup.sh` – bootstrap and setup script that installs packages and applies configuration.
- `home/` – configuration snippets that replaces or will append to the user's home directory files.
- `vars/` – common variables, such as `packages.list`, `aliases.list` or `PS1`, that will applied or inserted into multiple files

## Usage

```
Environment bootstrap script

Usage:
  setup.sh [options]

Options:
  -h, --help        Show this help message and exit
  -y, --yes         Automatically answer prompts with yes
```

### Run directly (recommended)

Execute the setup without cloning the repository by streaming the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

To run the script non-interactively (for example in automated setups), set `ENVIRONMENT_AUTO_CONFIRM=yes` before invoking it to bypass the confirmation prompt:

```bash
ENVIRONMENT_AUTO_CONFIRM=yes curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

### Run from a local clone

1. Clone the repository and change into its directory.

   ```bash
   git clone https://github.com/3x3cut0r/environment.git
   cd environment
   ```

2. Execute the setup script with one of the following commands.

   ```bash
   ./setup.sh
   ```

3. When prompted, confirm the installation. The script will:
   - Install packages from [`packages.list`](packages.list).
   - Merge the configuration snippets from [`home/`](home/) into your home directory.
