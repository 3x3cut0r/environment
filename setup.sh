#!/usr/bin/env bash

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

normalize_shell_list() {
    local shells_file="/etc/shells"
    if [ -f "$shells_file" ]; then
        INSTALLED_SHELLS=$(grep -vE '^\s*#' "$shells_file" \
            | awk -F/ 'NF { name = $NF; if (!seen[name]++) print name }' \
            | paste -sd ',' -)
        if [ -z "$INSTALLED_SHELLS" ]; then
            INSTALLED_SHELLS="Unknown"
        fi
    else
        INSTALLED_SHELLS="Unknown"
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
    printf '\n'
}

confirm_execution() {
    if [ "${ENVIRONMENT_AUTO_CONFIRM:-no}" != "yes" ]; then
        local response=""

        printf '[Environment][\033[35mINPUT\033[0m] %s' "Continue with setup? [y/N] "

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
            y|Y|yes|YES)
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

main() {
    parse_args "$@"
    gather_environment_info
    display_environment_info
    confirm_execution
}

main "$@"
