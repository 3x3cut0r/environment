# environment

This repository provides a foundational setup script and configuration snippets to prepare a workstation with common tooling. The script detects the host environment, installs required packages, and merges configuration updates into existing dotfiles.

## Repository layout

```
.
├── .gitignore                       # Ignored files configuration for the repository
├── .vscode/                         # Editor recommendations for VS Code users
│   ├── extensions.json              # Suggested VS Code extensions
│   └── settings.json                # Workspace-specific VS Code settings
├── LICENSE                          # Repository license (MIT)
├── README.md                        # Project documentation and usage guide
├── home/                            # Dotfile snippets applied to the target system
│   ├── .bash_profile.append         # Additional Bash profile configuration
│   ├── .bashrc.append               # Additional Bash runtime configuration
│   ├── .config/                     # Configuration directory for assorted tools
│   │   ├── aliases.list             # Common shell aliases to append
│   │   ├── nvim/                    # Neovim configuration directory for themed setup
│   │   │   └── init.vim             # Neovim configuration with Catppuccin theme support
│   │   └── starship.toml            # Starship prompt theme configuration
│   ├── .exrc                        # Ex/Vi editor configuration
│   ├── .profile.append              # POSIX shell profile additions
│   ├── .tmux.conf                   # tmux configuration with TPM setup
│   ├── .vimrc                       # Vim configuration with Catppuccin theme support
│   ├── .zprofile.append             # Zsh login shell profile additions
│   └── .zshrc.append                # Zsh interactive shell configuration
├── packages.list                    # Packages to install with the detected package manager
├── setup.sh                         # Bootstrap script orchestrating the environment setup
└── vars/                            # Prompt and helper data consumed by the setup script
    ├── PS1                          # Bash prompt template snippet
    ├── PS1.zsh                      # Zsh prompt template snippet
    └── comment_prefix.list          # Prefix tokens used when merging config files
```

## Usage

```
Environment bootstrap script

Usage:
  setup.sh [options]

Options:
  -h, --help                      Show this help message and exit
  -y, --yes                       Automatically answer prompts with yes
  --skip-packages, -sp            Skip package installation step
  --skip-nerd-font, --skip-nerdfont, -sn
                                  Skip Nerd Font installation
  --skip-starship, -ss            Skip Starship installation
  --skip-catppuccin, -sc          Skip Catppuccin installations for Vim and Neovim
  --skip-catppuccin-vim, -scv     Skip Catppuccin installation for Vim only
  --skip-catppuccin-nvim, --skip-catppuccin-neovim, -scn
                                  Skip Catppuccin installation for Neovim only
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
   - Collect details about the operating system, shell, user, and working directory.
   - Show a summary of the detected environment information.
   - Ask for confirmation before continuing unless automatic approval is enabled.
   - Install the packages declared in [`packages.list`](packages.list) with the available package manager.
   - Download and install the JetBrainsMono Nerd Font if it is not already present.
   - Offer to install the Starship prompt and run the official installer when accepted.
   - Set up the tmux plugin manager (TPM) and install plugins when tmux is available.
   - Apply the configuration snippets from [`home/`](home/) into the user's home directory with managed markers.
