#!/usr/bin/env bash
set -euo pipefail

AUTO_CONFIRM="${ENVIRONMENT_AUTO_CONFIRM:-no}"
SKIP_PACKAGES="no"
SKIP_NERD_FONT="no"
SKIP_STARSHIP="no"
SKIP_CATPPUCCIN_VIM="no"
SKIP_CATPPUCCIN_NEOVIM="no"

parse_args() {
    SHOW_HELP=0
    POSITIONAL_ARGS=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                SHOW_HELP=1
                shift
                ;;
            -y|--yes)
                AUTO_CONFIRM="yes"
                shift
                ;;
            --skip-packages|-sp)
                SKIP_PACKAGES="yes"
                shift
                ;;
            --skip-nerd-font|--skip-nerdfont|-sn)
                SKIP_NERD_FONT="yes"
                shift
                ;;
            --skip-starship|-ss)
                SKIP_STARSHIP="yes"
                shift
                ;;
            --skip-catppuccin|-sc)
                SKIP_CATPPUCCIN_VIM="yes"
                SKIP_CATPPUCCIN_NEOVIM="yes"
                shift
                ;;
            --skip-catppuccin-vim|-scv)
                SKIP_CATPPUCCIN_VIM="yes"
                shift
                ;;
            --skip-catppuccin-nvim|--skip-catppuccin-neovim|-scn)
                SKIP_CATPPUCCIN_NEOVIM="yes"
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_message ERROR "Unknown option: $1"
                exit 1
                ;;
            *)
                POSITIONAL_ARGS+="$1 "
                shift
                ;;
        esac
    done

    if [ "$SHOW_HELP" -eq 1 ]; then
        cat <<'USAGE'
Environment bootstrap script

Usage:
  setup.sh [options]

Options:
  -h, --help        Show this help message and exit
  -y, --yes         Automatically answer prompts with yes
      --skip-packages
                     Skip package installation step
      --skip-nerd-font, --skip-nerdfont
                     Skip Nerd Font installation
      --skip-starship
                     Skip Starship installation
      --skip-catppuccin
                     Skip Catppuccin installations for Vim and Neovim
      --skip-catppuccin-vim
                     Skip Catppuccin installation for Vim
      --skip-catppuccin-nvim, --skip-catppuccin-neovim
                     Skip Catppuccin installation for Neovim
USAGE
        exit 0
    fi
}

log_message() {
    local level="$1"
    shift
    local message="$*"

    local color reset="\033[0m" # reset
    case "$level" in
        INFO)
            color="\033[32m" # green
            ;;
        WARN)
            color="\033[33m" # yellow
            ;;
        ERROR)
            color="\033[31m" # red
            ;;
        INPUT)
            color="\033[35m" # magenta
            ;;
        *)
            color="\033[0m" # default
            ;;
    esac

    printf '[Environment][%b%s%b] %s\n' "$color" "$level" "$reset" "$message"
}

# shellcheck disable=SC2034
OS_NAME=""
# shellcheck disable=SC2034
OS_VERSION=""
# shellcheck disable=SC2034
OS_ID=""
# shellcheck disable=SC2034
OS_ARCH=""
# shellcheck disable=SC2034
OS_KERNEL=""
# shellcheck disable=SC2034
OS_DISTRIBUTION=""
# shellcheck disable=SC2034
INSTALLED_SHELLS=""
# shellcheck disable=SC2034
ACTIVE_SHELL=""
# shellcheck disable=SC2034
CURRENT_USER=""
# shellcheck disable=SC2034
HOSTNAME_VALUE=""
# shellcheck disable=SC2034
WORKING_DIRECTORY=""
# shellcheck disable=SC2034
AVAILABLE_PACKAGE_MANAGERS=()
# shellcheck disable=SC2034
TEMP_DIR=""
# shellcheck disable=SC2034
TEMP_ARCHIVE=""
# shellcheck disable=SC2034
REPOSITORY_DIR=""

cleanup_temp_resources() {
    if [ -n "${TEMP_ARCHIVE:-}" ] && [ -f "$TEMP_ARCHIVE" ]; then
        rm -f "$TEMP_ARCHIVE"
    fi

    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

create_temp_directory() {
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/environment-XXXXXX")
    log_message INFO "Created temporary directory at $TEMP_DIR"
}

download_repository_contents() {
    local repo_tarball_url="https://codeload.github.com/3x3cut0r/environment/tar.gz/refs/heads/main"
    TEMP_ARCHIVE=$(mktemp "${TMPDIR:-/tmp}/environment-archive-XXXXXX.tar.gz")

    log_message INFO "Downloading repository contents"
    curl -fsSL -H 'Cache-Control: no-cache, no-store, must-revalidate' \
        -H 'Pragma: no-cache' \
        -o "$TEMP_ARCHIVE" \
        "$repo_tarball_url"

    log_message INFO "Extracting repository archive"
    tar -xzf "$TEMP_ARCHIVE" -C "$TEMP_DIR" --strip-components=1
    rm -f "$TEMP_ARCHIVE"
    TEMP_ARCHIVE=""
    REPOSITORY_DIR="$TEMP_DIR"
    log_message INFO "Repository extracted to $TEMP_DIR"
}

normalize_shell_list() {
    local shells_file="/etc/shells"
    if [ -f "$shells_file" ]; then
        INSTALLED_SHELLS=$(awk -F/ '
            /^[ \t]*#/ { next }
            NF {
                name = $NF
                if (!seen[name]++) {
                    shells[++count] = name
                }
            }
            END {
                for (i = 1; i <= count; i++) {
                    printf "%s", shells[i]
                    if (i < count) {
                        printf ","
                    }
                }
            }
        ' "$shells_file")
        if [ -z "$INSTALLED_SHELLS" ]; then
            INSTALLED_SHELLS="Unknown"
        fi
    else
        INSTALLED_SHELLS="Unknown"
    fi
}

detect_package_managers() {
    AVAILABLE_PACKAGE_MANAGERS=()

    local manager_mappings=(
        "apt-get:apt-get install -y"
        "apt:apt install -y"
        "dnf:dnf install -y"
        "yum:yum install -y"
        "zypper:zypper install -y"
        "pacman:pacman -Sy --noconfirm"
        "yay:yay -Sy --noconfirm"
        "brew:brew install"
        "apk:apk add --no-cache"
        "pkg:pkg install -y"
        "emerge:emerge --ask=n"
    )

    local mapping manager install_cmd
    for mapping in "${manager_mappings[@]}"; do
        manager=${mapping%%:*}
        install_cmd=${mapping#*:}
        if command -v "$manager" >/dev/null 2>&1; then
            AVAILABLE_PACKAGE_MANAGERS+=("$manager:$install_cmd")
        fi
    done

    if [ ${#AVAILABLE_PACKAGE_MANAGERS[@]} -gt 0 ]; then
        local detected_names=()
        for mapping in "${AVAILABLE_PACKAGE_MANAGERS[@]}"; do
            detected_names+=("${mapping%%:*}")
        done
        log_message INFO "Detected package managers: ${detected_names[*]}"
    else
        log_message WARN "No supported package managers detected. Skipping package installation."
    fi

    printf '\n'
}

ensure_homebrew_for_macos() {
    local os_id_lower os_name_lower
    os_id_lower=$(printf '%s' "${OS_ID:-}" | tr '[:upper:]' '[:lower:]')
    os_name_lower=$(printf '%s' "${OS_NAME:-}" | tr '[:upper:]' '[:lower:]')

    if [ "$OS_KERNEL" != "Darwin" ] && [ "$os_id_lower" != "macos" ] && [ "$os_name_lower" != "macos" ]; then
        return
    fi

    if command -v brew >/dev/null 2>&1; then
        return
    fi

    log_message INFO "Homebrew not detected. Installing Homebrew."

    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    local potential_brew
    for potential_brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$potential_brew" ]; then
            eval "$($potential_brew shellenv)"
        fi
    done

    if command -v brew >/dev/null 2>&1; then
        log_message INFO "Homebrew installation completed."
    else
        log_message WARN "Homebrew installation did not make the 'brew' command available."
    fi
}

detect_operating_system() {
    OS_KERNEL=$(uname -s 2>/dev/null || echo "unknown")
    OS_ARCH=$(uname -m 2>/dev/null || echo "unknown")

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_NAME=${NAME:-$OS_KERNEL}
        OS_VERSION=${VERSION:-${VERSION_ID:-"unknown"}}
        OS_ID=${ID:-"unknown"}
        OS_DISTRIBUTION=${ID_LIKE:-$OS_ID}
    elif command -v sw_vers >/dev/null 2>&1; then
        OS_KERNEL="Darwin"
        OS_NAME="macOS"
        OS_VERSION=$(sw_vers -productVersion)
        OS_ID="macos"
        OS_DISTRIBUTION="darwin"
    elif command -v systeminfo >/dev/null 2>&1; then
        OS_KERNEL="Windows"
        OS_NAME="Windows"
        OS_VERSION=$(systeminfo | awk -F: '/OS Name|OS Version/ {gsub(/^ +/, ""); printf "%s ", $2}' | sed 's/ $//')
        OS_ID="windows"
        OS_DISTRIBUTION="windows"
    else
        OS_NAME=$OS_KERNEL
        OS_VERSION="unknown"
        OS_ID="unknown"
        OS_DISTRIBUTION="unknown"
    fi

    if grep -qi 'microsoft' /proc/version 2>/dev/null; then
        OS_DISTRIBUTION="wsl"
    fi
}

gather_environment_info() {
    detect_operating_system
    normalize_shell_list

    ACTIVE_SHELL=${SHELL:-$(ps -p "$PPID" -o comm= 2>/dev/null || echo "unknown")}
    CURRENT_USER=${USER:-$(id -un 2>/dev/null || echo "unknown")}
    HOSTNAME_VALUE=$(hostname 2>/dev/null || uname -n 2>/dev/null || echo "unknown")
    WORKING_DIRECTORY=$(pwd 2>/dev/null || echo "unknown")
}

display_environment_info() {
    log_message INFO "OS details:"
    printf '  %-20s %s\n' "Kernel" "$OS_KERNEL"
    printf '  %-20s %s\n' "Operating System" "$OS_NAME"
    printf '  %-20s %s\n' "Version" "$OS_VERSION"
    printf '  %-20s %s\n' "ID" "$OS_ID"
    printf '  %-20s %s\n' "Distribution" "$OS_DISTRIBUTION"
    printf '  %-20s %s\n' "Architecture" "$OS_ARCH"
    printf '  %-20s %s\n' "Installed shells" "$INSTALLED_SHELLS"
    printf '  %-20s %s\n' "Active shell" "$ACTIVE_SHELL"
    printf '  %-20s %s\n' "Hostname" "$HOSTNAME_VALUE"
    printf '  %-20s %s\n' "Current user" "$CURRENT_USER"
    printf '  %-20s %s\n' "Working directory" "$WORKING_DIRECTORY"
    printf '  %-20s %s\n' "Temp directory" "$TEMP_DIR"
    printf '\n'
}

confirm_execution() {
    if [ "$AUTO_CONFIRM" != "yes" ]; then
        local prompt="Continue with setup? [y/N] "
        local response=""

        printf '[Environment][\033[35mINPUT\033[0m] %s' "$prompt"

        local read_status=0
        if [ -t 0 ]; then
            if ! read -r response; then
                read_status=$?
                response=""
            fi
        else
            if ! read -r response </dev/tty; then
                read_status=$?
                response=""
            fi
        fi

        if [ $read_status -ne 0 ]; then
            printf '\n'
        fi
        case "$response" in
            j|J|ja|JA|y|Y|yes|YES)
                log_message INFO "Confirmation received, proceeding with setup steps."
                printf '\n'
                return 0
                ;;
            *)
                log_message WARN "Execution cancelled by the user."
                exit 0
                ;;
        esac
    else
        log_message WARN "Auto confirmation enabled. Proceeding without prompt."
        printf '\n'
    fi
}

install_packages() {
    local packages_file="${REPOSITORY_DIR:-.}/packages.list"

    if [ ! -f "$packages_file" ]; then
        log_message WARN "packages.list not found. Skipping package installation."
        return
    fi

    ensure_homebrew_for_macos
    detect_package_managers
    if [ ${#AVAILABLE_PACKAGE_MANAGERS[@]} -eq 0 ]; then
        return
    fi

    local packages=()
    local line trimmed
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed=$(printf '%s\n' "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [ -n "$trimmed" ]; then
            packages+=("$trimmed")
        fi
    done < "$packages_file"

    if [ ${#packages[@]} -eq 0 ]; then
        log_message WARN "No packages specified in packages.list."
        return
    fi

    local mapping manager install_cmd
    local package_line packages_in_line package
    for package_line in "${packages[@]}"; do
        IFS=' ' read -r -a packages_in_line <<< "$package_line"
        if [ ${#packages_in_line[@]} -eq 0 ]; then
            continue
        fi

        local line_installed=0
        for package in "${packages_in_line[@]}"; do
            local installed_with_manager=0
            for mapping in "${AVAILABLE_PACKAGE_MANAGERS[@]}"; do
                manager=${mapping%%:*}
                install_cmd=${mapping#*:}

                IFS=' ' read -r -a install_parts <<< "$install_cmd"
                if "${install_parts[@]}" "$package" >/dev/null 2>&1; then
                    log_message INFO "Installed $package using $manager."
                    installed_with_manager=1
                    line_installed=1
                    break
                fi
            done

            if [ $installed_with_manager -eq 1 ]; then
                break
            fi
        done

        if [ $line_installed -eq 0 ]; then
            log_message WARN "Unable to install any package from line: ${packages_in_line[*]}"
        fi
    done

    printf '\n'
}

install_nerd_font() {
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local font_destination=""

    case "$OS_KERNEL" in
        Darwin)
            font_destination="$HOME/Library/Fonts"
            ;;
        *)
            font_destination="$HOME/.local/share/fonts"
            ;;
    esac

    local existing_font=""
    if [ -d "$font_destination" ]; then
        existing_font=$(find "$font_destination" -maxdepth 1 -type f -name 'JetBrains Mono * Nerd Font*.ttf' -print -quit 2>/dev/null || true)
        if [ -n "$existing_font" ]; then
            log_message INFO "JetBrainsMono Nerd Font already installed. Skipping installation step."
            printf '\n'
            return 0
        fi
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_message ERROR "curl is required to download JetBrainsMono Nerd Font."
        printf '\n'
        return 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        log_message WARN "unzip is required to install JetBrainsMono Nerd Font. Skipping installation."
        printf '\n'
        return 1
    fi

    local temp_dir
    temp_dir=$(mktemp -d) || {
        log_message ERROR "Unable to create temporary directory for JetBrainsMono Nerd Font installation."
        printf '\n'
        return 1
    }

    local archive_path="$temp_dir/JetBrainsMono.zip"
    if ! curl -fsSL -o "$archive_path" "$font_url"; then
        log_message ERROR "Failed to download JetBrainsMono Nerd Font."
        rm -rf "$temp_dir"
        printf '\n'
        return 1
    fi

    mkdir -p "$font_destination"

    if ! unzip -o "$archive_path" -d "$font_destination" >/dev/null 2>&1; then
        log_message ERROR "Failed to extract JetBrainsMono Nerd Font archive."
        rm -rf "$temp_dir"
        printf '\n'
        return 1
    fi

    rm -rf "$temp_dir"

    if command -v fc-cache >/dev/null 2>&1; then
        if ! fc-cache -f "$font_destination" >/dev/null 2>&1; then
            log_message WARN "Failed to refresh font cache. You may need to run 'fc-cache -f'."
        fi
    fi

    log_message INFO "Installed JetBrainsMono Nerd Font."
    printf '\n'
}

file_has_trailing_newline() {
    local file_path="$1"
    if [ ! -s "$file_path" ]; then
        return 0
    fi

    local last_byte
    last_byte=$(tail -c1 "$file_path" 2>/dev/null | od -An -t x1 | tr -d ' \n')
    if [ "$last_byte" = "0a" ]; then
        return 0
    fi
    return 1
}

insert_file_content() {
    local input_file="$1"
    local output_file="$2"
    local marker_regex='^# <<< (.+)$'

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ $marker_regex ]]; then
            local include_path="${BASH_REMATCH[1]}"
            local include_file="${REPOSITORY_DIR:-.}/$include_path"
            if [ -f "$include_file" ]; then
                if [ -s "$include_file" ]; then
                    cat "$include_file" >>"$output_file"
                    if file_has_trailing_newline "$include_file"; then
                        :
                    else
                        printf '\n' >>"$output_file"
                    fi
                fi
            else
                log_message WARN "Include file '$include_path' referenced in '$input_file' not found."
                printf '%s\n' "$line" >>"$output_file"
            fi
        else
            printf '%s\n' "$line" >>"$output_file"
        fi
    done <"$input_file"
}

determine_comment_prefix() {
    local relative_path="$1"
    local mapping_file=""

    if [ -n "${REPOSITORY_DIR:-}" ] && [ -f "$REPOSITORY_DIR/vars/comment_prefix.list" ]; then
        mapping_file="$REPOSITORY_DIR/vars/comment_prefix.list"
    else
        local script_source
        script_source="${BASH_SOURCE[0]:-$0}"
        if [ -n "$script_source" ]; then
            local script_dir
            script_dir=$(cd "$(dirname "$script_source")" && pwd)
            if [ -f "$script_dir/vars/comment_prefix.list" ]; then
                mapping_file="$script_dir/vars/comment_prefix.list"
            fi
        fi
    fi

    if [ -n "$mapping_file" ]; then
        local line pattern prefix
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                ''|'#'*)
                    continue
                    ;;
            esac

            IFS=$' \t' read -r pattern prefix _ <<<"$line"
            if [ -z "$pattern" ] || [ -z "$prefix" ]; then
                continue
            fi

            case "$relative_path" in
                $pattern)
                    printf '%s' "$prefix"
                    return
                    ;;
            esac
        done <"$mapping_file"
    fi

    printf '%s' '#'
}

remove_existing_marker_block() {
    local source_file_identifier="$1"
    local target_file="$2"

    local comment_prefix="$3"
    if [ -z "$comment_prefix" ]; then
        comment_prefix="#"
    fi

    local start_marker="$comment_prefix >>> environment ~/$source_file_identifier >>>"
    local end_marker="$comment_prefix <<< environment ~/$source_file_identifier <<<"

    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start {in_block=1; next}
        $0 == end {in_block=0; next}
        in_block {next}
        {print}
    ' "$target_file"
}

ensure_trailing_newline() {
    local file_path="$1"
    if [ ! -s "$file_path" ]; then
        return
    fi

    if file_has_trailing_newline "$file_path"; then
        return
    fi

    printf '\n' >>"$file_path"
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        log_message INFO "Starship prompt is already installed. Skipping installation step."
        printf '\n'
        return 0
    fi

    local response=""
    local proceed=0

    if [ "$AUTO_CONFIRM" = "yes" ]; then
        log_message WARN "Auto confirmation enabled. Installing Starship without prompt."
        proceed=1
    else
        local prompt="Install Starship prompt? [y/N] "
        printf '[Environment][\033[35mINPUT\033[0m] %s' "$prompt"

        if [ -t 0 ]; then
            if ! read -r response; then
                response=""
            fi
        else
            if ! read -r response </dev/tty; then
                response=""
            fi
        fi

        printf '\n'

        case "$response" in
            j|J|ja|JA|y|Y|yes|YES)
                proceed=1
                ;;
            *)
                proceed=0
                ;;
        esac
    fi

    if [ $proceed -eq 1 ]; then
        log_message INFO "Installing Starship prompt using official installer."
        if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes; then
            log_message INFO "Starship installation completed successfully."
        else
            log_message ERROR "Starship installation failed."
        fi
    else
        log_message INFO "Starship installation skipped by user."
    fi

    printf '\n'
}

install_tmux_plugin_manager() {
    if ! command -v tmux >/dev/null 2>&1; then
        log_message INFO "tmux is not installed. Skipping TPM (tmux plugin manager) setup."
        printf '\n'
        return 0
    fi

    local target_home="$HOME"
    if [ -z "$target_home" ] && command -v getent >/dev/null 2>&1 && [ -n "$CURRENT_USER" ]; then
        target_home=$(getent passwd "$CURRENT_USER" | cut -d: -f6)
    fi

    if [ -z "$target_home" ] || [ ! -d "$target_home" ]; then
        log_message WARN "Unable to determine a valid home directory for tmux plugin installation."
        printf '\n'
        return 0
    fi

    local plugins_dir="$target_home/.tmux/plugins"
    local tpm_dir="$plugins_dir/tpm"

    mkdir -p "$plugins_dir"

    if [ ! -d "$tpm_dir" ]; then
        log_message INFO "Installing TPM (tmux plugin manager)."
        if git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir" >/dev/null 2>&1; then
            log_message INFO "TPM installed successfully."
        else
            log_message ERROR "Failed to install TPM."
            printf '\n'
            return 1
        fi
    else
        log_message INFO "TPM (tmux plugin manager) already present. Updating existing installation."
        if git -C "$tpm_dir" pull --ff-only --quiet >/dev/null 2>&1; then
            log_message INFO "TPM updated successfully."
        else
            log_message WARN "Unable to update TPM automatically. Continuing with existing version."
        fi
    fi

    local tmux_conf="$target_home/.tmux.conf"
    local temporary_conf=0
    if [ ! -f "$tmux_conf" ]; then
        if [ -n "${REPOSITORY_DIR:-}" ] && [ -f "$REPOSITORY_DIR/home/.tmux.conf" ]; then
            cp "$REPOSITORY_DIR/home/.tmux.conf" "$tmux_conf"
            temporary_conf=1
        else
            log_message WARN "No tmux configuration file found. Skipping plugin installation."
            printf '\n'
            return 0
        fi
    fi

    tmux start-server >/dev/null 2>&1 || true
    tmux new-session -d -s bootstrap || true
    tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$plugins_dir" >/dev/null 2>&1 || true
    tmux kill-session -t bootstrap >/dev/null 2>&1 || true

    if TMUX_PLUGIN_MANAGER_PATH="$plugins_dir" "$tpm_dir/bin/install_plugins" >/dev/null 2>&1; then
        log_message INFO "tmux plugins installed successfully."
    else
        log_message WARN "tmux plugin installation encountered issues."
    fi



    if [ $temporary_conf -eq 1 ]; then
        rm -f "$tmux_conf"
    fi

    printf '\n'
}

install_catppuccin_vim() {
    local repo_url="https://github.com/catppuccin/vim.git"
    local pack_dir="$HOME/.vim/pack/vendor/start"
    local theme_dir="$pack_dir/catppuccin"

    if ! command -v git >/dev/null 2>&1; then
        log_message WARN "git is required to install the Catppuccin theme for Vim. Skipping installation."
        printf '\n'
        return 1
    fi

    mkdir -p "$pack_dir"

    if [ -d "$theme_dir/.git" ]; then
        log_message INFO "Updating Catppuccin theme for Vim."
        if ! git -C "$theme_dir" pull --ff-only >/dev/null 2>&1; then
            log_message WARN "Failed to update Catppuccin theme for Vim. Leaving existing installation in place."
            printf '\n'
            return 1
        fi
    else
        if [ -d "$theme_dir" ]; then
            rm -rf "$theme_dir"
        fi

        log_message INFO "Installing Catppuccin theme for Vim."
        if ! git clone --depth 1 "$repo_url" "$theme_dir" >/dev/null 2>&1; then
            log_message WARN "Failed to clone Catppuccin theme for Vim."
            printf '\n'
            return 1
        fi
    fi

    log_message INFO "Catppuccin theme for Vim is installed at $theme_dir."
    printf '\n'
}

install_catppuccin_neovim() {
    local repo_url="https://github.com/catppuccin/nvim.git"
    local pack_dir="$HOME/.local/share/nvim/site/pack/colors/start"
    local theme_dir="$pack_dir/catppuccin"
    local source_init="${REPOSITORY_DIR:-.}/home/.config/nvim/init.vim"
    local target_init="$HOME/.config/nvim/init.vim"

    if ! command -v git >/dev/null 2>&1; then
        log_message WARN "git is required to install the Catppuccin theme for Neovim. Skipping installation."
        printf '\n'
        return 1
    fi

    mkdir -p "$pack_dir"

    if [ -d "$theme_dir/.git" ]; then
        log_message INFO "Updating Catppuccin theme for Neovim."
        if ! git -C "$theme_dir" pull --ff-only >/dev/null 2>&1; then
            log_message WARN "Failed to update Catppuccin theme for Neovim. Leaving existing installation in place."
            printf '\n'
            return 1
        fi
    else
        if [ -d "$theme_dir" ]; then
            rm -rf "$theme_dir"
        fi

        log_message INFO "Installing Catppuccin theme for Neovim."
        if ! git clone --depth 1 "$repo_url" "$theme_dir" >/dev/null 2>&1; then
            log_message WARN "Failed to clone Catppuccin theme for Neovim."
            printf '\n'
            return 1
        fi
    fi

    log_message INFO "Catppuccin theme for Neovim is installed at $theme_dir."

    if [ -f "$source_init" ]; then
        mkdir -p "$(dirname "$target_init")"
        if cp "$source_init" "$target_init"; then
            log_message INFO "Configured Neovim init.vim with Catppuccin settings at $target_init."
        else
            log_message WARN "Failed to copy Catppuccin settings to $target_init."
        fi
    else
        log_message WARN "Catppuccin settings for Neovim not found in repository. Skipping init.vim configuration."
    fi

    printf '\n'
}

configure_environment() {
    local source_home="${REPOSITORY_DIR:-.}/home"
    if [ ! -d "$source_home" ]; then
        log_message WARN "No home directory in repository. Skipping environment configuration."
        return
    fi

    local target_home="$HOME"
    if [ -z "$target_home" ]; then
        if command -v getent >/dev/null 2>&1 && [ -n "$CURRENT_USER" ]; then
            target_home=$(getent passwd "$CURRENT_USER" | cut -d: -f6)
        fi
    fi

    if [ -z "$target_home" ]; then
        log_message ERROR "Unable to determine target home directory."
        return 1
    fi

    if [ ! -d "$target_home" ]; then
        log_message WARN "Target home directory '$target_home' does not exist. Skipping environment configuration."
        return
    fi

    local file_path relative_path marker_identifier target_relative target_path target_directory append_mode
    while IFS= read -r -d '' file_path; do
        relative_path=${file_path#"$source_home/"}
        marker_identifier="$relative_path"

        append_mode=0
        target_relative="$relative_path"
        if [[ "$target_relative" == *.append ]]; then
            append_mode=1
            target_relative="${target_relative%.append}"
        fi

        local path_segment
        local traversal_detected=0
        local path_segments=()
        IFS='/' read -r -a path_segments <<<"$target_relative"
        for path_segment in "${path_segments[@]}"; do
            if [ "$path_segment" = ".." ]; then
                traversal_detected=1
                break
            fi
        done

        if [ $traversal_detected -eq 1 ]; then
            log_message WARN "Skipping '$relative_path' because the path attempts to traverse directories."
            continue
        fi

        target_path="$target_home/$target_relative"
        target_directory=$(dirname "$target_path")
        mkdir -p "$target_directory"

        local processed_file
        processed_file=$(mktemp)
        : >"$processed_file"
        insert_file_content "$file_path" "$processed_file"

        local comment_prefix
        comment_prefix=$(determine_comment_prefix "$target_relative")

        local start_marker="$comment_prefix >>> environment ~/$marker_identifier >>>"
        local end_marker="$comment_prefix <<< environment ~/$marker_identifier <<<"

        if [ "$append_mode" -eq 1 ]; then
            local cleaned_target
            cleaned_target=$(mktemp)
            : >"$cleaned_target"
            if [ -f "$target_path" ]; then
                remove_existing_marker_block "$marker_identifier" "$target_path" "$comment_prefix" >"$cleaned_target"
            fi

            if [ -s "$cleaned_target" ]; then
                ensure_trailing_newline "$cleaned_target"
                printf '\n' >>"$cleaned_target"
            fi

            printf '%s\n' "$start_marker" >>"$cleaned_target"
            if [ -s "$processed_file" ]; then
                cat "$processed_file" >>"$cleaned_target"
                ensure_trailing_newline "$cleaned_target"
            fi
            printf '%s\n' "$end_marker" >>"$cleaned_target"

            mv "$cleaned_target" "$target_path"
        else
            local new_file
            new_file=$(mktemp)
            : >"$new_file"
            printf '%s\n' "$start_marker" >>"$new_file"
            if [ -s "$processed_file" ]; then
                cat "$processed_file" >>"$new_file"
                ensure_trailing_newline "$new_file"
            fi
            printf '%s\n' "$end_marker" >>"$new_file"

            mv "$new_file" "$target_path"
        fi

        rm -f "$processed_file"
        log_message INFO "Configured $target_relative"
    done < <(find "$source_home" -type f -print0)
}

main() {
    parse_args "$@"
    trap 'cleanup_temp_resources' EXIT
    trap 'cleanup_temp_resources; exit 129' HUP
    trap 'cleanup_temp_resources; exit 130' INT
    trap 'cleanup_temp_resources; exit 131' QUIT
    trap 'cleanup_temp_resources; exit 143' TERM
    create_temp_directory
    download_repository_contents
    gather_environment_info
    display_environment_info
    confirm_execution
    if [ "$SKIP_PACKAGES" = "yes" ]; then
        log_message WARN "Skipping package installation as requested."
    else
        install_packages
    fi

    if [ "$SKIP_NERD_FONT" = "yes" ]; then
        log_message WARN "Skipping Nerd Font installation as requested."
    else
        install_nerd_font
    fi

    if [ "$SKIP_STARSHIP" = "yes" ]; then
        log_message WARN "Skipping Starship installation as requested."
    else
        install_starship
    fi
    install_tmux_plugin_manager
    if [ "$SKIP_CATPPUCCIN_VIM" = "yes" ]; then
        log_message WARN "Skipping Catppuccin installation for Vim as requested."
    else
        install_catppuccin_vim
    fi

    if [ "$SKIP_CATPPUCCIN_NEOVIM" = "yes" ]; then
        log_message WARN "Skipping Catppuccin installation for Neovim as requested."
    else
        install_catppuccin_neovim
    fi
    configure_environment
}

main "$@"
