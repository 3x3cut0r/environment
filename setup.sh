#!/usr/bin/env bash
set -euo pipefail

parse_args() {
    SHOW_HELP=0
    POSITIONAL_ARGS=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                SHOW_HELP=1
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
  -h, --help    Show this help message and exit
USAGE
        exit 0
    fi
}

log_message() {
    local level="$1"
    shift
    local message="$*"

    local color reset="\033[0m"
    case "$level" in
        INFO)
            color="\033[32m"
            ;;
        WARN)
            color="\033[33m"
            ;;
        ERROR)
            color="\033[31m"
            ;;
        INPUT)
            color="\033[35m"
            ;;
        *)
            color="\033[0m"
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
    if [ "${ENVIRONMENT_AUTO_CONFIRM:-no}" != "yes" ]; then
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
        log_message WARN "Auto confirmation enabled via ENVIRONMENT_AUTO_CONFIRM."
    fi
}

install_packages() {
    local packages_file="${REPOSITORY_DIR:-.}/packages.list"

    if [ ! -f "$packages_file" ]; then
        log_message WARN "packages.list not found. Skipping package installation."
        return
    fi

    detect_package_managers
    if [ ${#AVAILABLE_PACKAGE_MANAGERS[@]} -eq 0 ]; then
        return
    fi

    local packages=()
    local line trimmed
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed=$(printf '%s\n' "$line" | sed 's/#.*//; s/^[ \t]*//; s/[ \t]*$//')
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
    install_packages
}

main "$@"
