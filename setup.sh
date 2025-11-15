#!/usr/bin/env bash
set -euo pipefail

AUTO_CONFIRM="${ENVIRONMENT_AUTO_CONFIRM:-no}"
SKIP_PACKAGES="no"
SKIP_NERD_FONT="no"
SKIP_STARSHIP="no"
SKIP_TMUX_PLUGIN_MANAGER="no"
SKIP_VIM_PLUGIN_MANAGER="no"
SKIP_CATPPUCCIN_VIM="no"
SKIP_CATPPUCCIN_NEOVIM="no"
RECONFIGURE_MODE="no"

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
            -r|--reconfigure)
                RECONFIGURE_MODE="yes"
                SKIP_PACKAGES="yes"
                SKIP_NERD_FONT="yes"
                SKIP_STARSHIP="yes"
                SKIP_TMUX_PLUGIN_MANAGER="yes"
                SKIP_VIM_PLUGIN_MANAGER="yes"
                SKIP_CATPPUCCIN_VIM="yes"
                SKIP_CATPPUCCIN_NEOVIM="yes"
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
            --skip-tpm|-st)
                SKIP_TMUX_PLUGIN_MANAGER="yes"
                shift
                ;;
            --skip-vim-plug|-sv)
                SKIP_VIM_PLUGIN_MANAGER="yes"
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
  -h,   --help              Show this help message and exit
  -y,   --yes               Automatically answer prompts with yes
  -r,   --reconfigure       Reconfigure environment (update config files only)
  -sp,  --skip-packages     Skip package installation step
  -sn,  --skip-nerd-font,
        --skip-nerdfont     Skip Nerd Font installation
  -ss,  --skip-starship     Skip Starship installation
  -st,  --skip-tpm          Skip tmux plugin manager installation
  -sv,  --skip-vim-plug     Skip vim plugin manager installation
  -sc,  --skip-catppuccin   Skip Catppuccin installations for Vim and Neovim
  -scv, --skip-catppuccin-vim
                            Skip Catppuccin installation for Vim
  -scn, --skip-catppuccin-nvim,
        --skip-catppuccin-neovim 
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
    log_message INFO "Removing temporary directory at $TEMP_DIR"

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

    if [ -d "$REPOSITORY_DIR" ]; then
        log_message INFO "Setting execute permissions on repository shell scripts"
        find "$REPOSITORY_DIR" -type f -name '*.sh' -exec chmod 755 {} +
    fi
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
        "apt-get:env DEBIAN_FRONTEND=noninteractive apt-get install -y"
        "apt:env DEBIAN_FRONTEND=noninteractive apt install -y"
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

manager_requires_privilege() {
    case "$1" in
        apt-get|apt|dnf|yum|zypper|pacman|apk|pkg|emerge)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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
    if [ "${SKIP_PACKAGES:-no}" = "yes" ]; then
        log_message WARN "Skipping package installation."
        printf '\n'
        return 0
    fi

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

                if manager_requires_privilege "$manager" && [ "${EUID:-$(id -u)}" -ne 0 ]; then
                    if command -v sudo >/dev/null 2>&1; then
                        install_parts=("sudo" "${install_parts[@]}")
                    else
                        log_message WARN "Cannot install $package using $manager: elevated privileges required but sudo not available."
                        continue
                    fi
                fi

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
    if [ "${SKIP_NERD_FONT:-no}" = "yes" ]; then
        log_message WARN "Skipping Nerd Font installation."
        printf '\n'
        return 0
    fi

    local font_name="JetBrainsMono"
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local legacy_font_dir=""
    local nerd_font_dir=""

    case "$OS_KERNEL" in
        Darwin)
            legacy_font_dir="$HOME/Library/Fonts"
            nerd_font_dir="$legacy_font_dir/NerdFonts"
            ;;
        *)
            legacy_font_dir="$data_home/fonts"
            nerd_font_dir="$legacy_font_dir/NerdFonts"
            ;;
    esac

    local search_paths=("$nerd_font_dir" "$legacy_font_dir")
    local existing_font=""
    for font_path in "${search_paths[@]}"; do
        if [ -d "$font_path" ]; then
            existing_font=$(find "$font_path" -type f -name 'JetBrainsMono*NerdFont*.ttf' -print -quit 2>/dev/null || true)
            if [ -n "$existing_font" ]; then
                log_message INFO "JetBrainsMono Nerd Font already installed. Skipping installation step."
                printf '\n'
                return 0
            fi
        fi
    done

    if ! command -v git >/dev/null 2>&1; then
        log_message ERROR "git is required to install JetBrainsMono Nerd Font via the Nerd Fonts install script."
        printf '\n'
        return 1
    fi

    local temp_dir
    temp_dir=$(mktemp -d) || {
        log_message ERROR "Unable to create temporary directory for JetBrainsMono Nerd Font installation."
        printf '\n'
        return 1
    }

    local repo_dir="$temp_dir/nerd-fonts"
    log_message INFO "Cloning Nerd Fonts repository to run install script."
    if ! git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$repo_dir" >/dev/null 2>&1; then
        log_message ERROR "Failed to clone the Nerd Fonts repository."
        rm -rf "$temp_dir"
        printf '\n'
        return 1
    fi

    if ! (cd "$repo_dir" && ./install.sh -q --install-to-user-path "$font_name" >/dev/null 2>&1); then
        log_message ERROR "Nerd Fonts install script failed to install $font_name."
        rm -rf "$temp_dir"
        printf '\n'
        return 1
    fi

    rm -rf "$temp_dir"

    log_message INFO "Installed JetBrainsMono Nerd Font using the Nerd Fonts install script."
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
    if [ "${SKIP_STARSHIP:-no}" = "yes" ]; then
        log_message WARN "Skipping Starship installation."
        printf '\n'
        return 0
    fi

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
    if [ "${SKIP_TMUX_PLUGIN_MANAGER:-no}" = "yes" ]; then
        log_message WARN "Skipping TPM (tmux plugin manager) installation."
        printf '\n'
        return 0
    fi

    if ! command -v tmux >/dev/null 2>&1; then
        log_message INFO "tmux is not installed. Skipping TPM (tmux plugin manager) installation."
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

install_vim_plugin_manager() {
    if [ "${SKIP_VIM_PLUGIN_MANAGER:-no}" = "yes" ]; then
        log_message WARN "Skipping vim-plug (vim plugin manager) installation"
        printf '\n'
        return 0
    fi

    local plug_url="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    local vim_plug_path="$HOME/.vim/autoload/plug.vim"
    local nvim_plug_path="$HOME/.local/share/nvim/site/autoload/plug.vim"

    if ! command -v curl >/dev/null 2>&1; then
        log_message WARN "curl is required to install vim-plug. Skipping installation."
        printf '\n'
        return 1
    fi

    mkdir -p "$(dirname "$vim_plug_path")"
    if curl -fLo "$vim_plug_path" --create-dirs "$plug_url" >/dev/null 2>&1; then
        log_message INFO "Installed vim-plug for Vim at $vim_plug_path."
    else
        log_message WARN "Failed to install vim-plug for Vim."
    fi

    printf '\n'

    mkdir -p "$(dirname "$nvim_plug_path")"
    if curl -fLo "$nvim_plug_path" --create-dirs "$plug_url" >/dev/null 2>&1; then
        log_message INFO "Installed vim-plug for Neovim at $nvim_plug_path."
    else
        log_message WARN "Failed to install vim-plug for Neovim."
    fi

    printf '\n'
}

install_catppuccin_vim() {
    if [ "${SKIP_CATPPUCCIN_VIM:-no}" = "yes" ]; then
        log_message WARN "Skipping Catppuccin installation for Vim."
        printf '\n'
        return 0
    fi

    local source_vimrc="${REPOSITORY_DIR:-.}/home/.vimrc"

    if ! command -v vim >/dev/null 2>&1; then
        log_message WARN "Vim is required to install plugins. Skipping Catppuccin installation for Vim."
        printf '\n'
        return 1
    fi

    if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
        log_message WARN "vim-plug is not installed for Vim. Skipping Catppuccin installation for Vim."
        printf '\n'
        return 1
    fi

    if [ ! -f "$source_vimrc" ]; then
        log_message WARN "Vim configuration with Catppuccin plugin definition not found. Skipping installation."
        printf '\n'
        return 1
    fi

    log_message INFO "Installing Catppuccin theme for Vim using vim-plug."
    vim -es -u "$source_vimrc" +'PlugInstall --sync' +qall </dev/null >/dev/null 2>&1 || true
    printf '\n'
}

install_catppuccin_neovim() {
    if [ "${SKIP_CATPPUCCIN_NEOVIM:-no}" = "yes" ]; then
        log_message WARN "Skipping Catppuccin installation for Neovim."
        printf '\n'
        return 0
    fi

    local source_init="${REPOSITORY_DIR:-.}/home/.config/nvim/init.vim"

    if ! command -v nvim >/dev/null 2>&1; then
        log_message WARN "Neovim is required to install plugins. Skipping Catppuccin installation for Neovim."
        printf '\n'
        return 1
    fi

    if [ ! -f "$HOME/.local/share/nvim/site/autoload/plug.vim" ]; then
        log_message WARN "vim-plug is not installed for Neovim. Skipping Catppuccin installation for Neovim."
        printf '\n'
        return 1
    fi

    if [ ! -f "$source_init" ]; then
        log_message WARN "Neovim configuration with Catppuccin plugin definition not found. Skipping installation."
        printf '\n'
        return 1
    fi

    log_message INFO "Installing Catppuccin theme for Neovim using vim-plug."
    nvim --headless -u "$source_init" +'PlugInstall --sync' +qa </dev/null >/dev/null 2>&1 || true
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

    log_message INFO "Configure environment files from 'home/' to '$target_home'."

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

    printf '\n'
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
    if [ "$RECONFIGURE_MODE" = "yes" ]; then
        log_message INFO "Reconfigure mode enabled. Skipping all installation steps."
        printf '\n'
    fi
    install_packages
    install_nerd_font
    install_starship
    install_tmux_plugin_manager
    install_vim_plugin_manager
    install_catppuccin_vim
    install_catppuccin_neovim
    configure_environment
}

main "$@"
