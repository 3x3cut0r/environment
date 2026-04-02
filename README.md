# Environment

<img width="1082" height="757" alt="tmux" src="https://github.com/user-attachments/assets/f47f450f-5d9e-4d08-98fe-03a8abf98fe8" />

This repository provides a setup script that performs fundamental shell customizations and merges curated configuration snippets into an existing workstation.

- `install_packages`: Installs the baseline package set required for the configured tooling.
- `install_go_official`: Installs or updates Go from the latest official `go.dev` archive, with local `sources/` fallback on failure.
- `install_neovim_official`: Installs or updates Neovim from the latest official GitHub `tar.gz` release, deploys to `/opt/nvim/neovim-<version>`, and links `/usr/local/bin/nvim`.
- `install_nerd_font`: Downloads and installs the Nerd Font variant used across prompts and editors.
- `install_starship`: Sets up the Starship prompt with the repository's theme defaults.
- `install_tmux_plugin_manager`: Fetches and configures the tmux plugin manager (TPM) for plugin handling.
- `install_vim_plugin_manager`: Installs the Vim/Neovim plugin manager to bootstrap editor plugins.
- `install_catppuccin_vim`: Applies the Catppuccin color scheme to the Vim configuration.
- `install_catppuccin_neovim`: Mirrors the Catppuccin theme setup for Neovim.
- `install_catppuccin_bat`: Downloads the latest Catppuccin Mocha bat theme, sets it as default, and rebuilds bat cache.
- `install_catppuccin_gedit`: Updates Catppuccin Mocha for Gedit from upstream and installs it with a bundled fallback.
- `install_catppuccin_gnome_text_editor`: Updates Catppuccin Mocha for GNOME Text Editor from upstream and installs it with a bundled fallback.
- `install_catppuccin_terminal_app`: Updates Catppuccin Mocha for Terminal.app on macOS and applies it as the default profile.
- `install_catppuccin_xfce4_terminal`: Checks for `xfce4-terminal` and installs the latest Catppuccin Mocha colorscheme from upstream.
- `install_catppuccin_hyprland`: Checks for Hyprland and installs Catppuccin Mocha from upstream, then auto-adds a `source` line to `hyprland.conf`.
- `install_environment_wrapper`: Installs the `environment` wrapper command at `~/.local/bin/environment`.
- `configure_environment`: Applies the curated dotfile snippets, Starship theme settings, and environment variables.
- `configure_terminals`: Optionally configures GNOME Terminal to use JetBrainsMono Nerd Font.

## Repository overview

```
.
├── home/                            # Dotfile snippets applied to the target system
│   ├── .bash_history.touch          # Create ~/.bash_history if missing
│   ├── .bash_profile.append         # Additional Bash profile configuration
│   ├── .bashrc.append               # Additional Bash runtime configuration
│   ├── .config/                     # Configuration directory for assorted tools
│   │   ├── aliases.list             # Common shell aliases to append
│   │   ├── bat/                     # bat configuration and themes
│   │   │   ├── config               # bat defaults (Catppuccin Mocha)
│   │   │   └── themes/              # Theme directory (updated from upstream during setup)
│   │   ├── eza/                     # eza color theme configuration
│   │   │   └── theme.yml            # Catppuccin Mocha theme (mauve accent)
│   │   ├── hypr/                    # Hyprland configuration snippets
│   │   │   └── autostart.conf       # Hyprland autostart entries
│   │   ├── nvim/                    # Neovim configuration directory for themed setup
│   │   │   ├── init.lua             # Neovim entrypoint
│   │   │   └── lua/                 # Neovim Lua configuration modules
│   │   ├── opencode/                # OpenCode profile snippets and slash-commands
│   │   │   ├── commands/            # Custom slash-command definitions
│   │   │   │   ├── commit.md        # Create a Conventional Commit for git or svn
│   │   │   │   ├── jira.md          # Draft a Jira proposal from changes, path, or workspace context
│   │   │   │   ├── load.md          # Load TASKS.md context and optionally execute an instruction
│   │   │   │   ├── readme.md        # Create, review, simplify, or expand a README
│   │   │   │   ├── review.md        # Review staged or working changes for commit readiness
│   │   │   │   ├── save.md          # Save current session context into TASKS.md
│   │   │   │   └── update.md        # Update working copy for git or svn
│   │   │   ├── opencode.jsonc.ask   # Ask profile configuration
│   │   │   └── opencode.jsonc.proxmox # Proxmox profile configuration
│   │   ├── starship.toml            # Starship prompt theme configuration
│   │   ├── tmux/                    # tmux configuration and helper scripts
│   │       ├── tmux.conf            # tmux configuration with TPM setup
│   │       └── tmux.example.sh      # Example tmux session bootstrap script
│   │   └── vscode/                  # VS Code helper assets
│   │       └── extensions.list      # Extension IDs for bulk installation
│   ├── .exrc                        # Ex/Vi editor configuration
│   ├── .local/                      # User-local binaries managed by setup
│   │   ├── bin/
│   │   │   ├── environment          # Wrapper command to run latest setup from GitHub
│   │   │   └── install-vscode-extensions # Installs VS Code extensions from list
│   │   └── share/
│   │       ├── gtksourceview-5/
│   │       │   └── styles/
│   │       │       └── catppuccin-mocha.xml # Bundled GNOME Text Editor Catppuccin Mocha fallback theme
│   │       └── libgedit-gtksourceview-300/
│   │           └── styles/
│   │               └── catppuccin-mocha.xml # Bundled Gedit Catppuccin Mocha fallback theme
│   ├── .profile.append              # POSIX shell profile additions
│   ├── .vimrc                       # Vim configuration with Catppuccin theme support
│   ├── .zsh_history.touch           # Create ~/.zsh_history if missing
│   ├── .zprofile.append             # Zsh login shell profile additions
│   └── .zshrc.append                # Zsh interactive shell configuration
├── packages.list                    # System packages (before marker) and pip packages (after marker)
├── sources/                         # Bundled Go archives used as fallback during setup
├── setup.sh                         # Bootstrap script orchestrating the environment setup
└── vars/                            # Prompt and helper data consumed by the setup script
    ├── PATH                         # PATH snippet merged into shell profiles
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

```bash
# Do not ask user (install everything)
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --yes

# Just reconfigure (update configs only)
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --reconfigure --yes

# On Proxmox hosts (skip starship)
curl -fsSL https://raw.githubusercontent.com/3x3cut0r/environment/main/setup.sh | bash -s -- --skip-starship --yes
```

Prefer a local clone? Fetch the repository and run `./setup.sh` from its root directory.

```bash
git clone https://github.com/3x3cut0r/environment.git
cd environment
./setup.sh --help
```

`packages.list` is split by the marker `# <<< Add python packages below`:

- Entries before the marker are installed as system packages via the detected package manager.
- Entries before the marker can also contain one or more quoted commands. Everything inside `"..."` is treated as a shell command.
  Example lines:
  `fd fd-find fdfind`
  `make gmake`
  If a line starts with a quoted command, the command runs first and package-manager fallback runs afterwards.
  Otherwise, package-manager install runs first and quoted commands run afterwards.
- Entries after the marker are installed via `python3 -m pip install`.
- On macOS, setup ensures Homebrew is installed before running installation steps.
- Go is installed separately from the official `go.dev` release archive (latest stable, dynamic version lookup), not from the system package manager, before package processing starts.
- Neovim is installed separately from the latest GitHub release `tar.gz` archive (not from the system package manager), then linked to `/usr/local/bin/nvim`. On macOS, setup falls back to `brew install neovim` if the archive-based installation fails.
- After successful Neovim installation, old versions under `/opt/nvim/neovim-*` are removed automatically.
- If official Go archive download or installation fails, setup falls back to a matching local archive from `sources/` (for example `go*.linux-amd64.tar.gz` or `go*.linux-arm64.tar.gz`).
- If that local archive is missing or present as a Git LFS pointer (common when running via `curl ... | bash` tarball flow), setup fetches it on demand (first from `go.dev`, then from GitHub `sources/`) and then installs it.
- When Go is installed in `/usr/local/go`, the setup also adds `/usr/local/go/bin` and (if present) `$HOME/go/bin` to `PATH`.
- After `install_packages`, setup installs `lazygit`, `lazydocker`, `lazysvn`, and `lazynpm` via `go install`.
- If `go install` fails for one of these tools, setup falls back to `git clone --depth 1` and `go install .` from the cloned repository.

Archive files in this repository are tracked with Git LFS.
When using a local clone, `git lfs pull` remains optional because setup can now fetch fallback archives on demand if needed.

After a successful run, the script also tries to install the user-local wrapper command `environment` at `~/.local/bin/environment`.
The wrapper always downloads and runs the latest `setup.sh` from GitHub.

```bash
environment --reconfigure --yes
```

## Configuration

The setup supports these environment variables:

- `ENVIRONMENT_AUTO_CONFIRM=yes`: Enables non-interactive mode (same behavior as `--yes`).
- `ENVIRONMENT_WRAPPER_PATH=/custom/path/environment`: Overrides wrapper install location.
- `BAT_CONFIG_DIR=/custom/path/bat`: Overrides where bat config/themes are written.
- Shell PATH snippets now evaluate `brew shellenv` when Homebrew is available, so Homebrew toolchains (for example `python3`) are preferred over system defaults.

## Notes

- Current script behavior: `install_catppuccin_neovim` checks for `home/.config/nvim/init.vim`, while this repository currently provides `home/.config/nvim/init.lua`. This can cause the Neovim Catppuccin install step to be skipped.
- `install-vscode-extensions` now auto-detects the VS Code CLI on macOS via standard app bundle paths if `code` is not available in `PATH`.

```bash
Environment bootstrap script

Usage:
  setup.sh [options]

Options:
  -h,   --help              Show this help message and exit
  -y,   --yes               Automatically answer prompts with yes
  -r,   --reconfigure       Reconfigure dotfiles only (skip installs and terminal config)
  -sp,  --skip-packages     Skip package-related installs (system packages, Go, Neovim, lazy tools)
  -sn,  --skip-nerd-font,
         --skip-nerdfont     Skip Nerd Font installation
  -ss,  --skip-starship     Skip Starship installation
  -st,  --skip-tpm          Skip tmux plugin manager installation
  -sv,  --skip-vim-plug     Skip vim plugin manager installation
  -sc,  --skip-catppuccin   Skip Catppuccin installations for Vim, Neovim, bat, Gedit, GNOME Text Editor, Terminal.app, Xfce4 Terminal, and Hyprland
  -scv, --skip-catppuccin-vim
                              Skip Catppuccin installation for Vim
  -scn, --skip-catppuccin-nvim,
         --skip-catppuccin-neovim
                              Skip Catppuccin installation for Neovim
  -scb, --skip-catppuccin-bat
                              Skip Catppuccin installation for bat
  -scg, --skip-catppuccin-gedit
                              Skip Catppuccin installation for Gedit
  -scgte, --skip-catppuccin-gnome-text-editor
                              Skip Catppuccin installation for GNOME Text Editor
  -scta, --skip-catppuccin-terminal-app
                              Skip Catppuccin installation for Terminal.app (macOS)
  -scx, --skip-catppuccin-xfce4-terminal
                              Skip Catppuccin installation for Xfce4 Terminal
  -sch, --skip-catppuccin-hyprland
                              Skip Catppuccin installation for Hyprland
  -sw,  --skip-wrapper      Skip installation of the environment wrapper command
  -sce, --skip-configure-environment
                              Skip applying files from repository home/ to target home
  -sct, --skip-configure-terminals
                              Skip terminal font configuration prompts and changes
```

## Tests

There are currently no automated tests in this repository.

## Contributing

Issues and pull requests are welcome.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
