# environment

This repository provides a foundational setup script and configuration snippets to prepare a workstation with common tooling. The script detects the host environment, installs required packages, and merges configuration updates into existing dotfiles.

## Repository layout

- `scripts/` – contains automation such as `setup_environment.sh`.
- `home/` – configuration snippets that are appended to the user's home directory files.
- `home/.config/` – nested configurations, for example Neovim's `init.vim`.
- `etc/` – placeholder for system-wide configuration managed by future automation.

## Usage

1. Clone the repository and change into its directory.
2. Run the setup script:

   ```bash
   ./scripts/setup_environment.sh
   ```

3. When prompted, confirm the installation. The script will:
   - Detect whether the system is based on Arch, Debian/Ubuntu, RHEL, Proxmox, or macOS.
   - Install the following tools using the appropriate package manager: `curl`, `wget`, `exa`, `ranger`, `tmux`, `ncdu`, `git`, `bash-completion`, `neovim`, `vim`, and `mtr`.
   - Append the repository's configuration snippets to `~/.bashrc`, `~/.vimrc`, `~/.tmux.conf`, and `~/.config/nvim/init.vim`, adding markers to avoid duplicate entries.

The script requires administrative privileges to install packages and will request elevation with `sudo` or `doas` when necessary.
