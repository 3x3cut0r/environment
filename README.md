# Environment

<img width="1038" height="713" alt="tmux example" src="https://github.com/user-attachments/assets/2e307b02-9b49-4c7c-93fe-7b2c26baf27d" />

This repository provides a setup script that performs fundamental shell customizations and merges curated configuration snippets into an existing workstation.

- `install_packages`: Installs the baseline package set required for the configured tooling.
- `install_nerd_font`: Downloads and installs the Nerd Font variant used across prompts and editors.
- `install_starship`: Sets up the Starship prompt with the repository's theme defaults.
- `install_tmux_plugin_manager`: Fetches and configures the tmux plugin manager (TPM) for plugin handling.
- `install_vim_plugin_manager`: Installs the Vim/Neovim plugin manager to bootstrap editor plugins.
- `install_catppuccin_vim`: Applies the Catppuccin color scheme to the Vim configuration.
- `install_catppuccin_neovim`: Mirrors the Catppuccin theme setup for Neovim.
- `configure_environment`: Applies the curated dotfile snippets, Starship theme settings, and environment variables.

## Repository overview

```
.
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

Run the bootstrap script directly from GitHub (recommended):  
<span style="color:red">⚠️ <strong>Warning:</strong> This script overwrites existing configurations.</span>

```bash
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

Append flags after `--` to tailor the bootstrap:

```bash
# answer prompts automatically
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- -y

# skip package installation
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --skip-packages

# or both
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --skip-packages -y
```

Set `ENVIRONMENT_AUTO_CONFIRM=yes` to bypass the confirmation prompt entirely:

```bash
ENVIRONMENT_AUTO_CONFIRM=yes curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

Prefer a local clone? Fetch the repository and run `./setup.sh` from its root directory.
