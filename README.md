# environment

This repository provides a foundational setup script and configuration snippets to prepare a workstation with common tooling. The script detects the host environment, installs required packages, and merges configuration updates into existing dotfiles.

## Repository layout

- `setup.sh` – bootstrap and setup script that installs packages and applies configuration.
- `home/` – configuration snippets that replaces or will append to the user's home directory files.
- `vars/` – common variables, such as `packages.list`, `aliases.list` or `PS1`, that will applied or inserted into multiple files

## Usage

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

2. Run the setup script:

   ```bash
   ./setup.sh
   ```

   **or**

   ```bash
   ENVIRONMENT_AUTO_CONFIRM=yes ./setup.sh
   ```

3. When prompted, confirm the installation. The script will:
   - Install the tools listed in [`packages.list`](packages.list) using the appropriate package manager.
   - Append the repository's configuration snippets from the [`home/`](home/) directory to the corresponding files in your home directory, adding markers to avoid duplicate entries.

The script requires administrative privileges to install packages and will request elevation with `sudo` or `doas` when necessary.
