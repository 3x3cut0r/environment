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
│   ├── tmux.example.sh              # Example tmux session bootstrap script
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
<span style="color:red">⚠️ <strong>Warning:</strong> This script overwrites existing configurations ⚠️</span>

```bash
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

Append flags after `--` to tailor the bootstrap.  
For example add `--reconfigure --yes` to update the configuration files only:

```bash
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --reconfigure --yes
```

Prefer a local clone? Fetch the repository and run `./setup.sh` from its root directory.

```bash
git clone https://github.com/3x3cut0r/environment.git
cd environment
./setup.sh --help
```

```bash
Environment bootstrap script

Usage:
  setup.sh [options]

Options:
  -h,   --help              Show this help message and exit
  -y,   --yes               Automatically answer prompts with yes
  -r,   --reconfigure       Reconfigure environment without installing dependencies
  -sp,  --skip-packages     Skip package installation step
  -sn,  --skip-nerd-font,
        --skip-nerdfont     Skip Nerd Font installation
  -ss,  --skip-starship     Skip Starship installation
  -sc,  --skip-catppuccin   Skip Catppuccin installations for Vim and Neovim
  -scv, --skip-catppuccin-vim
                            Skip Catppuccin installation for Vim
  -scn, --skip-catppuccin-nvim,
        --skip-catppuccin-neovim
                            Skip Catppuccin installation for Neovim
```
