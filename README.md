# Environment

This repository provides a foundational setup script and configuration snippets to prepare a workstation with common tooling. The script detects the host environment, installs required packages, and merges configuration updates into existing dotfiles.

## Repository layout

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

```bash
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

Append flags after `--` to tailor the bootstrap:

```bash
# answer prompts automatically
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- -y

# skip package installation
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --skip-packages

# skip Nerd Font, Starship, or Catppuccin steps
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --skip-nerd-font --skip-starship --skip-catppuccin
```

Set `ENVIRONMENT_AUTO_CONFIRM=yes` to bypass the confirmation prompt entirely:

```bash
ENVIRONMENT_AUTO_CONFIRM=yes curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash
```

Prefer a local clone? Fetch the repository and run `./setup.sh` from its root directory.
