#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="3x3cut0r"
REPO_NAME="environment"
BRANCH="${ENVIRONMENT_BRANCH:-main}"
TMP_DIR=""
REPO_ROOT=""
PACKAGES_FILE=""
ALIASES_FILE=""

cleanup_bootstrap() {
  local exit_code=${1:-$?}

  trap - EXIT ERR INT TERM HUP QUIT

  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
    TMP_DIR=""
  fi

  exit "${exit_code}"
}

ensure_bootstrap_tools() {
  for tool in curl tar; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      log_error "${tool} is required to bootstrap the environment setup."
      exit 1
    fi
  done
}

bootstrap_and_exec() {
  ensure_bootstrap_tools

  trap 'cleanup_bootstrap $?' EXIT
  trap 'cleanup_bootstrap $?' ERR
  trap 'cleanup_bootstrap 130' INT
  trap 'cleanup_bootstrap 143' TERM
  trap 'cleanup_bootstrap 129' HUP
  trap 'cleanup_bootstrap 131' QUIT

  local tarball_url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${BRANCH}"
  TMP_DIR="$(mktemp -d)"

  if [[ -z "${TMP_DIR}" || ! -d "${TMP_DIR}" ]]; then
    log_error "Failed to create temporary directory."
    exit 1
  fi

  if ! curl -fsSL "${tarball_url}" | tar -xz -C "${TMP_DIR}" --strip-components=1; then
    log_error "Failed to download or extract repository archive from ${tarball_url}."
    exit 1
  fi

  local script_path="${TMP_DIR}/setup.sh"
  if [[ ! -x "${script_path}" ]]; then
    if [[ -f "${script_path}" ]]; then
      chmod +x "${script_path}"
    else
      log_error "Expected setup script not found in repository archive."
      exit 1
    fi
  fi

  ENVIRONMENT_BOOTSTRAPPED=1 ENVIRONMENT_REPO_ROOT="${TMP_DIR}" "${script_path}" "$@"
  cleanup_bootstrap "$?"
}

determine_repo_root() {
  if [[ -n "${ENVIRONMENT_BOOTSTRAPPED:-}" && -n "${ENVIRONMENT_REPO_ROOT:-}" ]]; then
    if [[ -f "${ENVIRONMENT_REPO_ROOT}/packages.list" ]]; then
      REPO_ROOT="${ENVIRONMENT_REPO_ROOT}"
      return 0
    fi
  fi

  local source_path="${BASH_SOURCE[0]:-$0}"
  if [[ -n "${source_path}" && "${source_path}" != "-" ]]; then
    local candidate_dir
    if candidate_dir="$(cd "$(dirname "${source_path}")" && pwd 2>/dev/null)"; then
      if [[ -f "${candidate_dir}/packages.list" ]]; then
        REPO_ROOT="${candidate_dir}"
        return 0
      fi
    fi
  fi

  if [[ -f "${PWD}/packages.list" ]]; then
    REPO_ROOT="${PWD}"
    return 0
  fi

  return 1
}

if ! determine_repo_root; then
  bootstrap_and_exec "$@"
fi

PACKAGES_FILE="${REPO_ROOT}/packages.list"
ALIASES_FILE="${REPO_ROOT}/aliases.list"

MODE="all"
PACKAGES=()
ENSURED_PACKAGES=()
STEP_COUNTER=0
TOTAL_STEPS=9
CONFIG_APPLIED=false
TPM_INSTALLED=false
ALIASES_CONFIGURED=false
JETBRAINS_FONT_INSTALLED=false
TMUX_PLUGINS_INSTALLED=false
STARSHIP_CONFIGURED=false
INSTALL_PACKAGES=true
PACKAGES_SKIPPED=false
STARSHIP_SKIPPED=false
INSTALL_STARSHIP=true
OPERATING_SYSTEM_LABEL=""

LOG_CONTEXT="[Environment]"

if [[ -t 1 ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_INFO=$'\033[32m'
  COLOR_WARN=$'\033[38;5;208m'
  COLOR_ERROR=$'\033[31m'
else
  COLOR_RESET=""
  COLOR_INFO=""
  COLOR_WARN=""
  COLOR_ERROR=""
fi

format_log_context() {
  local label="$1"
  if [[ -n "${label}" ]]; then
    LOG_CONTEXT="[${label}]"
  else
    LOG_CONTEXT="[Environment]"
  fi
}

log_message() {
  local level="$1"
  shift
  local color="$1"
  shift
  local destination="$1"
  shift
  local message="$*"
  local formatted_message="${LOG_CONTEXT}"
  if [[ -n "${level}" ]]; then
    formatted_message+="[${level}]"
  fi
  formatted_message+=" ${message}"
  if [[ "${destination}" == "stderr" ]]; then
    printf '%b%s%b\n' "${color}" "${formatted_message}" "${COLOR_RESET}" >&2
  else
    printf '%b%s%b\n' "${color}" "${formatted_message}" "${COLOR_RESET}"
  fi
}

log_info() {
  log_message "INFO" "${COLOR_INFO}" "stdout" "$*"
}

log_warn() {
  log_message "WARN" "${COLOR_WARN}" "stdout" "$*"
}

log_error() {
  log_message "ERROR" "${COLOR_ERROR}" "stderr" "$*"
}

log_input_prompt() {
  local prompt="$1"
  local destination="${2:-stdout}"
  local formatted="${LOG_CONTEXT}[INPUT] ${prompt}"
  if [[ "${destination}" == "tty" ]]; then
    printf '%b%s%b ' "${COLOR_WARN}" "${formatted}" "${COLOR_RESET}" > /dev/tty
  else
    printf '%b%s%b ' "${COLOR_WARN}" "${formatted}" "${COLOR_RESET}"
  fi
}

log_step_message() {
  local step_number="$1"
  shift
  local message="$*"
  local formatted="${LOG_CONTEXT}[${step_number}][INFO] ${message}"
  printf '%b%s%b\n' "${COLOR_INFO}" "${formatted}" "${COLOR_RESET}"
}

sanitize_prompt_reply() {
  local input="$1"

  # Remove carriage returns and line feeds that can be appended by
  # environments emitting Windows-style line endings. These extra
  # characters prevent straightforward confirmation inputs from
  # matching validation checks later on.
  input="${input//$'\r'/}"
  input="${input//$'\n'/}"

  # Trim leading and trailing spaces or tabs so accidental whitespace
  # entered before or after the response does not cause mismatches.
  while [[ "${input}" == ' '* || "${input}" == $'\t'* ]]; do
    input="${input#?}"
  done

  while [[ "${input}" == *' ' || "${input}" == *$'\t' ]]; do
    input="${input%?}"
  done

  printf '%s' "${input}"
}

prompt_for_input() {
  local prompt="$1"
  local __resultvar="$2"
  local user_reply=""

  if [[ -t 0 ]]; then
    log_input_prompt "${prompt}"
    if ! read -r user_reply; then
      return 1
    fi
  elif [[ -r /dev/tty ]]; then
    log_input_prompt "${prompt}" "tty"
    if ! read -r user_reply < /dev/tty; then
      return 1
    fi
  else
    return 2
  fi

  # Normalise the response to avoid issues caused by carriage returns or
  # accidental surrounding whitespace, which otherwise prevent simple inputs
  # like "y" from matching confirmation checks later on.
  user_reply="$(sanitize_prompt_reply "${user_reply}")"

  # Use printf -v to propagate the sanitized reply back to the caller. The
  # destination variable might be local to the caller, so avoid naming clashes
  # with our own locals that would otherwise shadow it.
  printf -v "${__resultvar}" '%s' "${user_reply}"
  return 0
}

section_heading() {
  printf '\n'
  log_info "$1"
  log_info "------------------------------"
}

display_environment_info() {
  section_heading "Environment information"

  local kernel arch shell_name workdir os_label

  if kernel=$(uname -r 2>/dev/null); then
    :
  else
    kernel="unknown"
  fi

  if arch=$(uname -m 2>/dev/null); then
    :
  else
    arch="unknown"
  fi

  if [[ -z "${OPERATING_SYSTEM_LABEL:-}" ]]; then
    detect_environment
  fi

  shell_name="${SHELL:-unknown}"
  workdir="${PWD:-unknown}"

  log_info "  User: $(whoami 2>/dev/null || echo unknown)"
  log_info "  Host: $(hostname 2>/dev/null || echo unknown)"
  os_label="${OPERATING_SYSTEM_LABEL:-unknown}"

  log_info "  Operating system: ${os_label} ${kernel}"
  log_info "  Architecture: ${arch}"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local distro_name distro_version
    distro_name="${NAME:-${ID:-unknown}}"
    distro_version="${VERSION:-${VERSION_ID:-unknown}}"
    log_info "  Distribution: ${distro_name} ${distro_version}"
  fi

  log_info "  Shell: ${shell_name}"
  log_info "  Working directory: ${workdir}"
}

usage() {
  cat <<'EOF'
Usage: setup.sh [OPTIONS]

Options:
  -p, --packages    Only install packages listed in packages.list
  -h, --help        Display this help message and exit
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      -p|--packages)
        MODE="packages"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        log_error "Unknown option: $1"
        usage >&2
        exit 1
        ;;
      *)
        break
        ;;
    esac
  done
}

load_packages() {
  if [[ ! -r "${PACKAGES_FILE}" ]]; then
    log_error "Packages file not found: ${PACKAGES_FILE}"
    exit 1
  fi

  mapfile -t PACKAGES < <(grep -vE '^(\s*$|\s*#)' "${PACKAGES_FILE}")

  if ((${#PACKAGES[@]} == 0)); then
    log_error "No packages defined in ${PACKAGES_FILE}"
    exit 1
  fi
}

display_execution_plan() {
  section_heading "Planned actions"

  local package_count=${#PACKAGES[@]}
  local package_label="packages"
  if ((package_count == 1)); then
    package_label="package"
  fi

  if ((package_count > 0)); then
    log_info "  - Confirm package installation and install up to ${package_count} ${package_label} listed in packages.list"
  else
    log_info "  - Skip package installation because no packages are listed"
  fi

  if [[ "${MODE}" == "packages" ]]; then
    log_info "  - Run in packages-only mode, skipping configuration and tooling setup steps"
  else
    log_info "  - Apply the repository's configuration files for bash, Vim, Neovim, and tmux"
    log_info "  - Install the curated bash and zsh prompts defined in the repository"
    log_info "  - Configure shell aliases for bash, sh, zsh, and fish"
    log_info "  - Offer Starship prompt installation aligned with the repository configuration"
    log_info "  - Ensure the JetBrainsMono Nerd Font is installed"
    log_info "  - Ensure the tmux plugin manager (TPM) is installed"
    log_info "  - Install tmux plugins via TPM"
  fi

  log_info "  - Provide a summary of the actions performed"
}

is_shell_available() {
  local shell_name="$1"
  case "${shell_name}" in
    bash|zsh|fish)
      command -v "${shell_name}" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

step() {
  STEP_COUNTER=$((STEP_COUNTER + 1))
  printf '\n'
  log_step_message "${STEP_COUNTER}" "$1"
}

confirm_execution() {
  printf '\n'
  local prompt="Do you want to continue? [y/N]"
  local reply=""

  if [[ "${ENVIRONMENT_AUTO_CONFIRM:-}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    reply="yes"
  else
    local prompt_status=0
    if ! prompt_for_input "${prompt}" reply; then
      prompt_status=$?
      case "${prompt_status}" in
        1)
          log_warn "Aborted by user (no input)."
          exit 0
          ;;
        2)
          log_error "No interactive terminal available for confirmation. Set ENVIRONMENT_AUTO_CONFIRM=yes to run non-interactively."
          exit 1
          ;;
      esac
    fi
  fi

  case "${reply:-}" in
    [yY][eE][sS]|[yY])
      log_info "Proceeding with setup."
      ;;
    *)
      log_warn "Aborted by user."
      exit 0
      ;;
  esac
}

confirm_package_installation() {
  if ((${#PACKAGES[@]} == 0)); then
    INSTALL_PACKAGES=false
    PACKAGES_SKIPPED=true
    log_info "No packages defined to install; skipping package installation."
    return
  fi

  case "${ENVIRONMENT_AUTO_INSTALL_PACKAGES:-}" in
    [yY][eE][sS]|[yY])
      INSTALL_PACKAGES=true
      return
      ;;
    [nN][oO]|[nN])
      INSTALL_PACKAGES=false
      PACKAGES_SKIPPED=true
      log_warn "Skipping package installation (ENVIRONMENT_AUTO_INSTALL_PACKAGES set to no)."
      return
      ;;
  esac

  if [[ "${ENVIRONMENT_AUTO_CONFIRM:-}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    INSTALL_PACKAGES=true
    return
  fi

  step "Confirm package installation"

  local prompt message reply
  if [[ -n "${PKG_MANAGER:-}" ]]; then
    message="Install required packages using ${PKG_MANAGER}?"
  else
    message="Install required packages now?"
  fi

  if ((${#PACKAGES[@]} > 0)); then
    log_info "The following packages are queued for installation:"
    for pkg in "${PACKAGES[@]}"; do
      log_info "  - ${pkg}"
    done
    printf '\n'
  fi

  prompt="${message} [Y/n] "

  local prompt_status=0
  if ! prompt_for_input "${prompt}" reply; then
    prompt_status=$?
    case "${prompt_status}" in
      1)
        log_warn "Skipped package installation (no input)."
        INSTALL_PACKAGES=false
        PACKAGES_SKIPPED=true
        return
        ;;
      2)
        log_warn "No interactive terminal available to confirm package installation. Set ENVIRONMENT_AUTO_INSTALL_PACKAGES=yes to proceed non-interactively."
        INSTALL_PACKAGES=false
        PACKAGES_SKIPPED=true
        return
        ;;
    esac
  fi

  case "${reply:-}" in
    [nN][oO]|[nN])
      INSTALL_PACKAGES=false
      PACKAGES_SKIPPED=true
      log_warn "Package installation skipped by user."
      ;;
    *)
      INSTALL_PACKAGES=true
      ;;
  esac
}

confirm_starship_setup() {
  if [[ "${MODE}" == "packages" ]]; then
    INSTALL_STARSHIP=false
    STARSHIP_SKIPPED=true
    return
  fi

  case "${ENVIRONMENT_AUTO_INSTALL_STARSHIP:-}" in
    [yY][eE][sS]|[yY])
      INSTALL_STARSHIP=true
      return
      ;;
    [nN][oO]|[nN])
      INSTALL_STARSHIP=false
      STARSHIP_SKIPPED=true
      return
      ;;
  esac

  if [[ "${ENVIRONMENT_AUTO_CONFIRM:-}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    INSTALL_STARSHIP=true
    return
  fi

  printf '\n'
  log_info "Starship prompt customization will perform:"
  log_info "  - Installation of the Starship prompt for bash, zsh, and fish via the official script"
  log_info "  - Installation of the repository's Starship configuration"
  log_info "  - Activation snippets so supported shells initialize Starship with that configuration"

  local prompt reply
  prompt="Activate these Starship prompt customizations? [Y/n] "

  local prompt_status=0
  if ! prompt_for_input "${prompt}" reply; then
    prompt_status=$?
    case "${prompt_status}" in
      1)
        INSTALL_STARSHIP=false
        STARSHIP_SKIPPED=true
        log_warn "Skipped Starship prompt customization (no input)."
        return
        ;;
      2)
        INSTALL_STARSHIP=false
        STARSHIP_SKIPPED=true
        log_warn "No interactive terminal available to confirm Starship prompt customization. Set ENVIRONMENT_AUTO_INSTALL_STARSHIP=yes to continue automatically."
        return
        ;;
    esac
  fi

  case "${reply:-}" in
    [nN][oO]|[nN])
      INSTALL_STARSHIP=false
      STARSHIP_SKIPPED=true
      log_warn "Starship prompt customization skipped by user."
      ;;
    *)
      INSTALL_STARSHIP=true
      ;;
  esac
}

confirm_homebrew_installation() {
  case "${ENVIRONMENT_AUTO_INSTALL_HOMEBREW:-}" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    [nN][oO]|[nN])
      return 1
      ;;
  esac

  if [[ "${ENVIRONMENT_AUTO_CONFIRM:-}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    return 0
  fi

  local prompt reply
  prompt="Homebrew is required to install packages on MacOS. Install Homebrew now? [y/N] "

  if ! prompt_for_input "${prompt}" reply; then
    case "$?" in
      1)
        return 1
        ;;
      2)
        log_warn "Cannot prompt to install Homebrew (no interactive terminal). Set ENVIRONMENT_AUTO_INSTALL_HOMEBREW=yes to continue."
        return 1
        ;;
    esac
  fi

  case "${reply:-}" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_environment() {
  local uname_out
  uname_out="$(uname -s)"
  OPERATING_SYSTEM_LABEL="${uname_out}"
  format_log_context ""

  if [[ "${uname_out}" == "Darwin" ]]; then
    ENVIRONMENT="mac"
    if command -v brew >/dev/null 2>&1; then
      PKG_MANAGER="brew"
    else
      PKG_MANAGER=""
    fi

    if command -v sw_vers >/dev/null 2>&1; then
      local macos_version
      macos_version="$(sw_vers -productVersion 2>/dev/null || true)"
      if [[ -n "${macos_version}" ]]; then
        OPERATING_SYSTEM_LABEL="macOS ${macos_version}"
      else
        OPERATING_SYSTEM_LABEL="macOS"
      fi
    else
      OPERATING_SYSTEM_LABEL="macOS"
    fi

    return 0
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release

    local distro_name distro_version
    distro_name="${PRETTY_NAME:-${NAME:-${ID:-unknown}}}"
    distro_version="${VERSION:-${VERSION_ID:-}}"
    if [[ -n "${distro_name}" ]]; then
      if [[ -n "${distro_version}" && "${distro_name}" != *"${distro_version}"* ]]; then
        OPERATING_SYSTEM_LABEL="${distro_name} ${distro_version}"
      else
        OPERATING_SYSTEM_LABEL="${distro_name}"
      fi
    fi

    case "${ID}" in
      arch|manjaro|endeavouros|omarchy)
        ENVIRONMENT="arch"
        PKG_MANAGER="pacman"
        ;;
      ubuntu|debian|linuxmint|raspbian|pop|neon|zorin|elementary|proxmox)
        ENVIRONMENT="debian"
        PKG_MANAGER="apt-get"
        ;;
      rhel|centos|fedora|rocky|almalinux|alma|ol|scientific)
        ENVIRONMENT="rhel"
        if command -v dnf >/dev/null 2>&1; then
          PKG_MANAGER="dnf"
        else
          PKG_MANAGER="yum"
        fi
        ;;
      *)
        if [[ -n "${ID_LIKE:-}" ]]; then
          case "${ID_LIKE}" in
            *arch*)
              ENVIRONMENT="arch"
              PKG_MANAGER="pacman"
              ;;
            *debian*|*ubuntu*)
              ENVIRONMENT="debian"
              PKG_MANAGER="apt-get"
              ;;
            *rhel*|*fedora*)
              ENVIRONMENT="rhel"
              if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
              else
                PKG_MANAGER="yum"
              fi
              ;;
          esac
        fi
        ;;
    esac
  fi

  if [[ -z "${ENVIRONMENT:-}" || -z "${PKG_MANAGER:-}" ]]; then
    log_error "Unsupported or undetected environment."
    exit 1
  fi

  format_log_context ""
}

install_packages() {
  step "Install required packages"

  if [[ "${INSTALL_PACKAGES}" != true ]]; then
    log_warn "Skipping package installation."
    return
  fi

  local sudo_cmd=""
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    elif command -v doas >/dev/null 2>&1; then
      sudo_cmd="doas"
    else
      log_error "This script requires administrative privileges to install packages."
      exit 1
    fi
  fi

  if [[ -z "${PKG_MANAGER}" ]]; then
    log_warn "Homebrew not detected."
    if confirm_homebrew_installation; then
      if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        PKG_MANAGER="brew"
        install_packages
      else
        log_warn "Failed to install Homebrew; skipping package installation."
        PACKAGES_SKIPPED=true
      fi
    else
      log_warn "Homebrew installation skipped."
      PACKAGES_SKIPPED=true
    fi
    return
  fi

  local resolved_packages=()
  local requested_packages=()
  local package_managers=()
  ENSURED_PACKAGES=()
  for pkg in "${PACKAGES[@]}"; do
    local resolved
    resolved="$(resolve_package_name "${pkg}")"
    if [[ -z "${resolved}" ]]; then
      log_warn "Skipping ${pkg} (not supported on ${ENVIRONMENT})."
      continue
    fi
    local manager=""
    if is_package_available "${resolved}" "${PKG_MANAGER}"; then
      manager="${PKG_MANAGER}"
    elif [[ "${PKG_MANAGER}" == "pacman" ]] && command -v yay >/dev/null 2>&1 && is_package_available "${resolved}" "yay"; then
      manager="yay"
    else
      if [[ "${PKG_MANAGER}" == "pacman" ]]; then
        if command -v yay >/dev/null 2>&1; then
          log_warn "Package ${resolved} (requested as ${pkg}) not available via pacman or yay; skipping."
        else
          log_warn "Package ${resolved} (requested as ${pkg}) not available via pacman and yay not found; skipping."
        fi
      else
        log_warn "Package ${resolved} (requested as ${pkg}) not available via ${PKG_MANAGER}; skipping."
      fi
      continue
    fi

    resolved_packages+=("${resolved}")
    requested_packages+=("${pkg}")
    package_managers+=("${manager}")
  done

  if ((${#resolved_packages[@]} == 0)); then
    log_warn "No packages available to install for ${PKG_MANAGER}."
    return
  fi

  local managers_to_refresh=()
  for manager in "${package_managers[@]}"; do
    local found=false
    for existing in "${managers_to_refresh[@]}"; do
      if [[ "${existing}" == "${manager}" ]]; then
        found=true
        break
      fi
    done
    if [[ "${found}" == false ]]; then
      managers_to_refresh+=("${manager}")
    fi
  done

  local failed_refresh_managers=()
  for manager in "${managers_to_refresh[@]}"; do
    case "${manager}" in
      pacman)
        if ! ${sudo_cmd} pacman -Sy --noconfirm; then
          log_warn "Failed to refresh pacman package databases; skipping pacman installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      yay)
        if ! yay -Sy --noconfirm; then
          log_warn "Failed to refresh yay package databases; skipping yay installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      apt-get)
        if ! ${sudo_cmd} apt-get update; then
          log_warn "Failed to update apt package lists; skipping apt-get installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      brew)
        if ! brew update; then
          log_warn "Failed to update Homebrew; skipping brew installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      dnf)
        if ! ${sudo_cmd} dnf makecache; then
          log_warn "Failed to refresh dnf metadata; skipping dnf installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      yum)
        if ! ${sudo_cmd} yum makecache; then
          log_warn "Failed to refresh yum metadata; skipping yum installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      *)
        log_warn "Package manager ${manager} is not supported by this script."
        failed_refresh_managers+=("${manager}")
        ;;
    esac
  done

  for i in "${!resolved_packages[@]}"; do
    local resolved_pkg="${resolved_packages[$i]}"
    local requested_pkg="${requested_packages[$i]}"
    local install_failed=false
    local manager="${package_managers[$i]}"

    local skip_install=false
    for failed in "${failed_refresh_managers[@]}"; do
      if [[ "${failed}" == "${manager}" ]]; then
        skip_install=true
        break
      fi
    done

    if [[ "${skip_install}" == true ]]; then
      log_warn "Skipping ${requested_pkg}; package manager ${manager} not available for installation."
      continue
    fi

    log_info "Installing ${requested_pkg} via ${manager} (${resolved_pkg})."

    case "${manager}" in
      pacman)
        if ! ${sudo_cmd} pacman -S --noconfirm --needed "${resolved_pkg}"; then
          install_failed=true
        fi
        ;;
      yay)
        if ! yay -S --noconfirm --needed "${resolved_pkg}"; then
          install_failed=true
        fi
        ;;
      apt-get)
        if ! ${sudo_cmd} apt-get install -y "${resolved_pkg}"; then
          install_failed=true
        fi
        ;;
      dnf)
        if ! ${sudo_cmd} dnf install -y "${resolved_pkg}"; then
          install_failed=true
        fi
        ;;
      yum)
        if ! ${sudo_cmd} yum install -y "${resolved_pkg}"; then
          install_failed=true
        fi
        ;;
      brew)
        if ! brew install "${resolved_pkg}"; then
          install_failed=true
        fi
        ;;
      *)
        log_error "Package manager ${manager} is not supported by this script."
        return 1
        ;;
    esac

    if [[ "${install_failed}" == true ]]; then
      log_warn "Failed to install ${resolved_pkg} (requested as ${requested_pkg}); skipping."
      continue
    fi

    ENSURED_PACKAGES+=("${requested_pkg}")
  done

  if ((${#ENSURED_PACKAGES[@]} == 0)); then
    log_warn "No packages were installed due to installation failures."
  fi
}

resolve_package_name() {
  local pkg="$1"
  case "${pkg}" in
    dnsutils)
      case "${ENVIRONMENT}" in
        arch)
          echo "bind"
          ;;
        debian)
          echo "dnsutils"
          ;;
        rhel)
          echo "bind-utils"
          ;;
        mac)
          echo "bind"
          ;;
        *)
          echo "${pkg}"
          ;;
      esac
      ;;
    vi)
      echo "vim"
      ;;
    watch)
      case "${ENVIRONMENT}" in
        arch)
          echo "procps-ng"
          ;;
        debian)
          echo "procps"
          ;;
        rhel)
          echo "procps-ng"
          ;;
        mac)
          echo "watch"
          ;;
        *)
          echo "${pkg}"
          ;;
      esac
      ;;
    wormhole)
      echo "magic-wormhole"
      ;;
    *)
      echo "${pkg}"
      ;;
  esac
}

is_package_available() {
  local pkg="$1"
  local manager="${2:-${PKG_MANAGER}}"
  case "${manager}" in
    pacman)
      pacman -Si "${pkg}" >/dev/null 2>&1
      ;;
    yay)
      if command -v yay >/dev/null 2>&1; then
        yay -Si "${pkg}" >/dev/null 2>&1
      else
        return 1
      fi
      ;;
    apt-get)
      apt-cache show "${pkg}" >/dev/null 2>&1
      ;;
    dnf)
      dnf info "${pkg}" >/dev/null 2>&1
      ;;
    yum)
      yum info "${pkg}" >/dev/null 2>&1
      ;;
    brew)
      brew info "${pkg}" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

apply_config() {
  local source_file="$1"
  local target_file="$2"
  local comment_prefix="${3:-#}"
  local mode="${4:-auto}"

  mkdir -p "$(dirname "${target_file}")"

  if [[ "${mode}" == append || "${source_file}" == *.append ]]; then
    local start_marker end_marker

    start_marker="${comment_prefix} >>> environment repo config >>>"
    end_marker="${comment_prefix} <<< environment repo config <<<"

    if [[ -e "${target_file}" ]]; then
      if grep -Fq "${start_marker}" "${target_file}"; then
        local tmp_file
        tmp_file="$(mktemp)"
        awk -v start="${start_marker}" -v end="${end_marker}" '
          $0 == start {in_block=1; next}
          $0 == end {in_block=0; next}
          !in_block {print}
        ' "${target_file}" > "${tmp_file}"
        if [[ -s "${tmp_file}" ]]; then
          printf '\n' >> "${tmp_file}"
        fi
        {
          echo "${start_marker}"
          cat "${source_file}"
          echo "${end_marker}"
        } >> "${tmp_file}"
        mv "${tmp_file}" "${target_file}"
        log_info "Updated configuration block in ${target_file}."
        return
      fi
      {
        echo ""
        echo "${start_marker}"
        cat "${source_file}"
        echo "${end_marker}"
      } >> "${target_file}"
      log_info "Appended configuration to ${target_file}."
    else
      {
        echo "${start_marker}"
        cat "${source_file}"
        echo "${end_marker}"
      } > "${target_file}"
      log_info "Created ${target_file} with new configuration."
    fi
    return
  fi

  if [[ -e "${target_file}" ]] && cmp -s "${source_file}" "${target_file}"; then
    log_info "${target_file} is already up to date."
    return
  fi

  cp "${source_file}" "${target_file}"
  log_info "Installed ${target_file} from ${source_file}."
}

install_shell_configuration() {
  local shell_name="$1"
  local template="${REPO_ROOT}/home/.${shell_name}rc"
  local ps1_source="${REPO_ROOT}/home/PS1.${shell_name}"
  local target="${HOME}/.${shell_name}rc"
  local start_marker="# >>> PS1.${shell_name} >>>"
  local end_marker="# <<< PS1.${shell_name} <<<"

  if [[ ! -f "${template}" ]]; then
    return
  fi

  mkdir -p "$(dirname "${target}")"

  local tmp_file
  tmp_file="$(mktemp)"

  local in_prompt_block=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "${start_marker}" ]]; then
      echo "${line}" >> "${tmp_file}"
      if [[ -f "${ps1_source}" ]]; then
        cat "${ps1_source}" >> "${tmp_file}"
      fi
      in_prompt_block=1
      continue
    fi

    if [[ "${line}" == "${end_marker}" ]]; then
      in_prompt_block=0
      echo "${line}" >> "${tmp_file}"
      continue
    fi

    if (( in_prompt_block )); then
      continue
    fi

    echo "${line}" >> "${tmp_file}"
  done < "${template}"

  mv "${tmp_file}" "${target}"
  log_info "Installed ${target} from ${template} with prompt configuration from ${ps1_source}."
}

configure_environment() {
  step "Apply configuration files"

  if [[ "${MODE}" == "packages" ]]; then
    log_warn "Skipping configuration (packages-only mode)."
    return
  fi

  if is_shell_available bash; then
    install_shell_configuration bash
    if [[ -f "${REPO_ROOT}/home/.bash_profile" ]]; then
      apply_config "${REPO_ROOT}/home/.bash_profile" "${HOME}/.bash_profile" "#"
    fi
    if [[ -f "${REPO_ROOT}/home/.profile" ]]; then
      apply_config "${REPO_ROOT}/home/.profile" "${HOME}/.profile" "#"
    fi
  fi

  if is_shell_available zsh; then
    install_shell_configuration zsh
  fi

  apply_config "${REPO_ROOT}/home/.vimrc" "${HOME}/.vimrc" "\""
  apply_config "${REPO_ROOT}/home/.tmux.conf" "${HOME}/.tmux.conf" "#"
  apply_config "${REPO_ROOT}/home/.config/nvim/init.vim" "${HOME}/.config/nvim/init.vim" "\""
  CONFIG_APPLIED=true
}

configure_aliases() {
  step "Configure shell aliases"

  if [[ "${MODE}" == "packages" ]]; then
    log_warn "Skipping alias configuration (packages-only mode)."
    return
  fi

  if [[ ! -f "${ALIASES_FILE}" ]]; then
    log_error "Aliases file not found: ${ALIASES_FILE}"
    return
  fi

  local alias_dir="${HOME}/.config/environment"
  local alias_list_target="${alias_dir}/aliases.list"
  local fish_alias_target="${alias_dir}/aliases.fish"
  local posix_snippet fish_snippet

  mkdir -p "${alias_dir}"
  cp "${ALIASES_FILE}" "${alias_list_target}"
  log_info "Installed alias definitions to ${alias_list_target}."

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "${alias_list_target}" "${fish_alias_target}"
import pathlib
import re
import sys

source_path = pathlib.Path(sys.argv[1])
target_path = pathlib.Path(sys.argv[2])
lines = [f"# Generated fish aliases from {source_path}"]
alias_pattern = re.compile(r"^alias\s+([^=\s]+)\s*=\s*(.+)$")
if_command_pattern = re.compile(r"^if\s+command\s+-v\s+([^\s;]+).*")

indent_stack = []

def current_indent():
    return "  " * len(indent_stack)

for raw in source_path.read_text().splitlines():
    stripped = raw.strip()
    if not stripped or stripped.startswith("#"):
        continue

    if stripped == "fi":
        if indent_stack:
            indent_stack.pop()
            lines.append(f"{current_indent()}end")
        else:
            lines.append(f"# Skipped unsupported alias line: {stripped}")
        continue

    if stripped == "else":
        if indent_stack:
            lines.append(f"{'  ' * (len(indent_stack) - 1)}else")
        else:
            lines.append(f"# Skipped unsupported alias line: {stripped}")
        continue

    if_match = if_command_pattern.match(stripped)
    if if_match:
        command = if_match.group(1)
        lines.append(f"{current_indent()}if type -q {command}")
        indent_stack.append("if")
        continue

    match = alias_pattern.match(stripped)
    if match:
        name, value = match.groups()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f"{current_indent()}alias {name} \"{escaped}\"")
        continue

    lines.append(f"# Skipped unsupported alias line: {stripped}")

target_path.write_text("\n".join(lines) + "\n")
PY
    log_info "Generated fish aliases at ${fish_alias_target}."
  else
    {
      echo "# python3 not available; falling back to bash-compatible aliases"
      echo "# Source file: ${alias_list_target}"
    } > "${fish_alias_target}"
    cat "${alias_list_target}" >> "${fish_alias_target}"
    log_warn "python3 not found. Copied aliases to ${fish_alias_target} without conversion."
  fi

  local posix_snippet="${REPO_ROOT}/home/.config/environment/snippets/aliases_posix.append"
  if [[ -f "${posix_snippet}" ]]; then
    if is_shell_available bash; then
      apply_config "${posix_snippet}" "${HOME}/.bashrc" "# alias" append
      if [[ -f "${HOME}/.profile" ]]; then
        apply_config "${posix_snippet}" "${HOME}/.profile" "# alias" append
      fi
    elif [[ -f "${HOME}/.profile" ]]; then
      apply_config "${posix_snippet}" "${HOME}/.profile" "# alias" append
    fi
    if is_shell_available zsh; then
      apply_config "${posix_snippet}" "${HOME}/.zshrc" "# alias" append
    fi
  fi

  local fish_snippet="${REPO_ROOT}/home/.config/environment/snippets/aliases_fish.append"
  if is_shell_available fish && [[ -f "${fish_snippet}" ]]; then
    apply_config "${fish_snippet}" "${HOME}/.config/fish/config.fish" "# alias" append
  fi

  ALIASES_CONFIGURED=true
}

install_starship_prompt() {
  step "Install Starship prompt"

  if [[ "${MODE}" == "packages" ]]; then
    log_warn "Skipping Starship prompt setup (packages-only mode)."
    STARSHIP_SKIPPED=true
    return
  fi

  if [[ "${INSTALL_STARSHIP}" != true ]]; then
    log_warn "Starship prompt setup skipped."
    STARSHIP_SKIPPED=true
    local fish_starship_config="${HOME}/.config/fish/conf.d/starship.fish"
    if [[ -e "${fish_starship_config}" ]]; then
      rm -f "${fish_starship_config}"
      log_warn "Removed ${fish_starship_config} to prevent Starship initialization."
    fi
    return
  fi

  if command -v starship >/dev/null 2>&1; then
    log_info "Starship prompt already installed."
  else
    if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
      log_info "Installed Starship prompt using the official installer."
    else
      log_error "Failed to install Starship prompt."
      exit 1
    fi
  fi

  if [[ -f "${REPO_ROOT}/home/.config/starship.toml" ]]; then
    apply_config "${REPO_ROOT}/home/.config/starship.toml" "${HOME}/.config/starship.toml" "#"
  fi

  if is_shell_available fish; then
    apply_config "${REPO_ROOT}/home/.config/fish/conf.d/starship.fish" "${HOME}/.config/fish/conf.d/starship.fish" "#"
  fi

  log_info "Aligned Starship prompt with the repository configuration."
  STARSHIP_CONFIGURED=true
  STARSHIP_SKIPPED=false
}

ensure_jetbrainsmono_nerd_font() {
  step "Ensure JetBrainsMono Nerd Font"

  if [[ "${MODE}" == "packages" ]]; then
    log_warn "Skipping JetBrainsMono Nerd Font installation (packages-only mode)."
    return
  fi

  local fonts_dir font_file font_url temp_dir archive extract_dir copied

  case "${ENVIRONMENT}" in
    mac)
      fonts_dir="${HOME}/Library/Fonts"
      ;;
    *)
      fonts_dir="${HOME}/.local/share/fonts"
      ;;
  esac

  font_file="${fonts_dir}/JetBrainsMonoNerdFont-Regular.ttf"
  font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

  if [[ -f "${font_file}" ]]; then
    log_info "JetBrainsMono Nerd Font already present at ${font_file}."
    JETBRAINS_FONT_INSTALLED=true
    return
  fi

  mkdir -p "${fonts_dir}"

  temp_dir="$(mktemp -d)"
  if [[ -z "${temp_dir}" || ! -d "${temp_dir}" ]]; then
    log_error "Failed to create temporary directory for JetBrainsMono Nerd Font installation."
    exit 1
  fi

  archive="${temp_dir}/JetBrainsMono.zip"
  if ! curl -fsSL "${font_url}" -o "${archive}"; then
    log_error "Failed to download JetBrainsMono Nerd Font from ${font_url}."
    rm -rf "${temp_dir}"
    exit 1
  fi

  extract_dir="${temp_dir}/fonts"
  mkdir -p "${extract_dir}"

  if command -v unzip >/dev/null 2>&1; then
    if ! unzip -oq "${archive}" -d "${extract_dir}"; then
      log_error "Failed to extract JetBrainsMono Nerd Font archive with unzip."
      rm -rf "${temp_dir}"
      exit 1
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if ! python3 - "${archive}" "${extract_dir}" <<'PY'; then
import pathlib
import sys
import zipfile

archive_path = pathlib.Path(sys.argv[1])
target_dir = pathlib.Path(sys.argv[2])
target_dir.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(archive_path) as zf:
    zf.extractall(target_dir)
PY
      log_error "Failed to extract JetBrainsMono Nerd Font archive with python3."
      rm -rf "${temp_dir}"
      exit 1
    fi
  else
    log_error "Neither unzip nor python3 is available to extract the JetBrainsMono Nerd Font archive."
    rm -rf "${temp_dir}"
    exit 1
  fi

  copied=false

  if command -v python3 >/dev/null 2>&1; then
    while IFS= read -r -d '' font_path; do
      if install -m 0644 "${font_path}" "${fonts_dir}/"; then
        copied=true
      else
        log_error "Failed to install font file ${font_path}."
        rm -rf "${temp_dir}"
        exit 1
      fi
    done < <(python3 - "${extract_dir}" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for candidate in root.rglob('*'):
    if candidate.suffix.lower() in {'.ttf', '.otf'}:
        sys.stdout.write(f"{candidate}\0")
PY
    )
  else
    while IFS= read -r -d '' font_path; do
      if install -m 0644 "${font_path}" "${fonts_dir}/"; then
        copied=true
      else
        log_error "Failed to install font file ${font_path}."
        rm -rf "${temp_dir}"
        exit 1
      fi
    done < <(find "${extract_dir}" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
  fi

  if [[ "${copied}" == false ]]; then
    log_error "No font files were found in the JetBrainsMono Nerd Font archive."
    rm -rf "${temp_dir}"
    exit 1
  fi

  if command -v fc-cache >/dev/null 2>&1; then
    if fc-cache -f "${fonts_dir}" >/dev/null 2>&1; then
      log_info "Refreshed font cache via fc-cache."
    else
      log_warn "Warning: failed to refresh font cache with fc-cache."
    fi
  fi

  rm -rf "${temp_dir}"

  log_info "Installed JetBrainsMono Nerd Font to ${fonts_dir}."
  JETBRAINS_FONT_INSTALLED=true
}

ensure_tmux_plugin_manager() {
  step "Ensure tmux plugin manager"

  if [[ "${MODE}" == "packages" ]]; then
    log_warn "Skipping tmux plugin manager setup (packages-only mode)."
    return
  fi

  local tpm_dir="${HOME}/.tmux/plugins/tpm"

  if [[ -d "${tpm_dir}" ]]; then
    log_info "tmux plugin manager already installed at ${tpm_dir}."
    TPM_INSTALLED=true
    return
  fi

  mkdir -p "${HOME}/.tmux/plugins"
  if git clone https://github.com/tmux-plugins/tpm "${tpm_dir}"; then
    log_info "Installed tmux plugin manager to ${tpm_dir}."
    TPM_INSTALLED=true
  else
    log_error "Failed to install tmux plugin manager."
    exit 1
  fi
}

install_tmux_plugins() {
  step "Install tmux plugins"

  if [[ "${MODE}" == "packages" ]]; then
    log_warn "Skipping tmux plugin installation (packages-only mode)."
    return
  fi

  local install_script="${HOME}/.tmux/plugins/tpm/scripts/install_plugins.sh"

  if [[ ! -f "${install_script}" ]]; then
    log_error "tmux plugin installer not found at ${install_script}."
    exit 1
  fi

  if bash "${install_script}"; then
    log_info "Installed tmux plugins via TPM."
    TMUX_PLUGINS_INSTALLED=true
  else
    log_error "Failed to install tmux plugins via TPM."
    exit 1
  fi
}

summarize() {
  step "Summary"

  if [[ "${PACKAGES_SKIPPED}" == true ]]; then
    log_warn "Package installation was skipped."
  elif ((${#ENSURED_PACKAGES[@]} > 0)); then
    log_info "Packages ensured:"
    for pkg in "${ENSURED_PACKAGES[@]}"; do
      log_info "  - ${pkg}"
    done
  else
    log_warn "No packages were installed by this run."
  fi

  if [[ "${CONFIG_APPLIED}" == true ]]; then
    log_info "Configuration files managed:"
    log_info "  - ~/.bashrc"
    log_info "  - ~/.bash_profile"
    log_info "  - ~/.profile"
    log_info "  - ~/.zshrc"
    log_info "  - ~/.vimrc"
    log_info "  - ~/.tmux.conf"
    log_info "  - ~/.config/nvim/init.vim"
  else
    log_warn "Configuration files were not updated."
  fi

  if [[ "${ALIASES_CONFIGURED}" == true ]]; then
    log_info "Shell aliases configured for:"
    log_info "  - bash"
    log_info "  - sh"
    log_info "  - zsh"
    log_info "  - fish"
  else
    log_warn "Shell aliases were not configured."
  fi

  if [[ "${MODE}" != "packages" ]]; then
    if [[ "${STARSHIP_CONFIGURED}" == true ]]; then
      log_info "Starship prompt installed and aligned with the repository configuration."
    elif [[ "${STARSHIP_SKIPPED}" == true ]]; then
      log_warn "Starship prompt customization was skipped."
    else
      log_info "Starship prompt was not changed."
    fi
  fi

  if [[ "${TPM_INSTALLED}" == true ]]; then
    log_info "tmux plugin manager ensured."
  else
    log_warn "tmux plugin manager was not changed."
  fi

  if [[ "${TMUX_PLUGINS_INSTALLED}" == true ]]; then
    log_info "tmux plugins installed via TPM."
  else
    log_warn "tmux plugins were not installed."
  fi

  if [[ "${JETBRAINS_FONT_INSTALLED}" == true ]]; then
    log_info "JetBrainsMono Nerd Font ensured."
  else
    log_warn "JetBrainsMono Nerd Font was not changed."
  fi
}

main() {
  parse_args "$@"
  detect_environment
  load_packages
  display_environment_info
  display_execution_plan
  confirm_execution
  confirm_starship_setup
  confirm_package_installation
  install_packages
  configure_environment
  configure_aliases
  install_starship_prompt
  ensure_jetbrainsmono_nerd_font
  ensure_tmux_plugin_manager
  install_tmux_plugins
  summarize
}

main "$@"
