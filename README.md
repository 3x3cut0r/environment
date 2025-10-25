# environment

This repository provides a foundational setup script and configuration snippets to prepare a workstation with common tooling. The script detects the host environment, installs required packages, and merges configuration updates into existing dotfiles.

## Repository layout

- `scripts/` – contains automation such as `setup_environment.sh`.
- `home/` – configuration snippets that are appended to the user's home directory files.

## Usage

### Run directly (recommended)

Execute the setup without cloning the repository by streaming the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/environment.sh | bash
```

To run the script non-interactively (for example in automated setups), set `ENVIRONMENT_AUTO_CONFIRM=yes` before invoking it to bypass the confirmation prompt:

```bash
ENVIRONMENT_AUTO_CONFIRM=yes curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/environment.sh | bash
```

You can override the branch that should be executed by setting the `ENVIRONMENT_BRANCH` environment variable before running the command.

### Run from a local clone

1. Clone the repository and change into its directory.

   ```bash
   git clone https://github.com/3x3cut0r/environment.git
   cd environment
   ```
2. Run the setup script:

   ```bash
   ./scripts/setup_environment.sh
   ```

3. When prompted, confirm the installation. The script will:
   - Detect whether the system is based on Arch, Debian/Ubuntu, RHEL, Proxmox, or macOS.
   - Install the tools listed in [`scripts/packages.list`](scripts/packages.list) using the appropriate package manager.
   - Append the repository's configuration snippets from the [`home/`](home/) directory to the corresponding files in your home directory, adding markers to avoid duplicate entries.

The script requires administrative privileges to install packages and will request elevation with `sudo` or `doas` when necessary.
