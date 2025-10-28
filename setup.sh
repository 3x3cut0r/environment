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
      echo "${tool} is required to bootstrap the environment setup." >&2
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
    echo "Failed to create temporary directory." >&2
    exit 1
  fi

  if ! curl -fsSL "${tarball_url}" | tar -xz -C "${TMP_DIR}" --strip-components=1; then
    echo "Failed to download or extract repository archive from ${tarball_url}." >&2
    exit 1
  fi

  local script_path="${TMP_DIR}/setup.sh"
  if [[ ! -x "${script_path}" ]]; then
    if [[ -f "${script_path}" ]]; then
      chmod +x "${script_path}"
    else
      echo "Expected setup script not found in repository archive." >&2
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
TOTAL_STEPS=10
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
PROMPT_CHOICE=1
PROMPT_EXAMPLE=""
PROMPT_BASH_VALUE='\\W \\$ '
PROMPT_ZSH_VALUE='%1~ %(!.#.\\$) '
PROMPT_STARSHIP_FORMAT='$directory$character'
PROMPT_STARSHIP_DIRECTORY_PREFIX=""
PROMPT_STARSHIP_TRUNCATION=1
PROMPT_STARSHIP_INCLUDE_USERNAME=false
PROMPT_STARSHIP_INCLUDE_HOSTNAME=false
PROMPT_CONTEXT_DIR=""
PROMPT_CONTEXT_BASENAME=""
PROMPT_CONTEXT_DISPLAY_PATH=""
PROMPT_CONTEXT_USER=""
PROMPT_CONTEXT_HOST=""

section_heading() {
  echo ""
  echo "$1"
  echo "------------------------------"
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

  echo "User: $(whoami 2>/dev/null || echo unknown)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  os_label="${OPERATING_SYSTEM_LABEL:-unknown}"

  echo "Operating system: ${os_label} ${kernel}"
  echo "Architecture: ${arch}"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local distro_name distro_version
    distro_name="${NAME:-${ID:-unknown}}"
    distro_version="${VERSION:-${VERSION_ID:-unknown}}"
    echo "Distribution: ${distro_name} ${distro_version}"
  fi

  echo "Shell: ${shell_name}"
  echo "Working directory: ${workdir}"
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
        echo "Unknown option: $1" >&2
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
    echo "Packages file not found: ${PACKAGES_FILE}" >&2
    exit 1
  fi

  mapfile -t PACKAGES < <(grep -vE '^(\s*$|\s*#)' "${PACKAGES_FILE}")

  if ((${#PACKAGES[@]} == 0)); then
    echo "No packages defined in ${PACKAGES_FILE}" >&2
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
    echo "  - Confirm package installation and install up to ${package_count} ${package_label} listed in packages.list"
  else
    echo "  - Skip package installation because no packages are listed"
  fi

  if [[ "${MODE}" == "packages" ]]; then
    echo "  - Run in packages-only mode, skipping configuration and tooling setup steps"
  else
    echo "  - Apply configuration snippets for bash, Vim, Neovim, and tmux"
    echo "  - Ask for your preferred prompt style and reuse it across bash, zsh, and Starship"
    echo "  - Configure shell aliases for bash, sh, zsh, and fish"
    echo "  - Offer Starship prompt installation aligned with the chosen prompt style"
    echo "  - Ensure the JetBrainsMono Nerd Font is installed"
    echo "  - Ensure the tmux plugin manager (TPM) is installed"
    echo "  - Install tmux plugins via TPM"
  fi

  echo "  - Provide a summary of the actions performed"
}

initialize_prompt_context() {
  local current_dir base display user host

  current_dir="${PWD:-${HOME:-/}}"
  if [[ -z "${current_dir}" ]]; then
    current_dir="${HOME:-/}"
  fi

  PROMPT_CONTEXT_DIR="${current_dir}"

  base="${current_dir##*/}"
  if [[ -z "${base}" ]]; then
    base="/"
  fi
  PROMPT_CONTEXT_BASENAME="${base}"

  display="${current_dir}"
  if [[ -n "${HOME:-}" && "${display}" == "${HOME}"* ]]; then
    display="~${display:${#HOME}}"
  fi
  PROMPT_CONTEXT_DISPLAY_PATH="${display}"

  if ! user=$(whoami 2>/dev/null); then
    user="user"
  fi
  PROMPT_CONTEXT_USER="${user}"

  if ! host=$(hostname 2>/dev/null); then
    host="host"
  fi
  host="${host%%.*}"
  if [[ -z "${host}" ]]; then
    host="host"
  fi
  PROMPT_CONTEXT_HOST="${host}"
}

set_prompt_values() {
  case "${PROMPT_CHOICE}" in
    1)
      PROMPT_BASH_VALUE='\\W \\$ '
      PROMPT_ZSH_VALUE='%1~ %(!.#.\\$) '
      PROMPT_STARSHIP_FORMAT='$directory$character'
      PROMPT_STARSHIP_DIRECTORY_PREFIX=""
      PROMPT_STARSHIP_TRUNCATION=1
      PROMPT_STARSHIP_INCLUDE_USERNAME=false
      PROMPT_STARSHIP_INCLUDE_HOSTNAME=false
      PROMPT_EXAMPLE="${PROMPT_CONTEXT_BASENAME} $"
      ;;
    2)
      PROMPT_BASH_VALUE='\\w \\$ '
      PROMPT_ZSH_VALUE='%~ %(!.#.\\$) '
      PROMPT_STARSHIP_FORMAT='$directory$character'
      PROMPT_STARSHIP_DIRECTORY_PREFIX=""
      PROMPT_STARSHIP_TRUNCATION=0
      PROMPT_STARSHIP_INCLUDE_USERNAME=false
      PROMPT_STARSHIP_INCLUDE_HOSTNAME=false
      PROMPT_EXAMPLE="${PROMPT_CONTEXT_DISPLAY_PATH} $"
      ;;
    3)
      PROMPT_BASH_VALUE='\\u:\\W \\$ '
      PROMPT_ZSH_VALUE='%n:%1~ %(!.#.\\$) '
      PROMPT_STARSHIP_FORMAT='$username$directory$character'
      PROMPT_STARSHIP_DIRECTORY_PREFIX=":"
      PROMPT_STARSHIP_TRUNCATION=1
      PROMPT_STARSHIP_INCLUDE_USERNAME=true
      PROMPT_STARSHIP_INCLUDE_HOSTNAME=false
      PROMPT_EXAMPLE="${PROMPT_CONTEXT_USER}:${PROMPT_CONTEXT_BASENAME} $"
      ;;
    4)
      PROMPT_BASH_VALUE='\\u@\\h:\\W \\$ '
      PROMPT_ZSH_VALUE='%n@%m:%1~ %(!.#.\\$) '
      PROMPT_STARSHIP_FORMAT='$username$hostname$directory$character'
      PROMPT_STARSHIP_DIRECTORY_PREFIX=":"
      PROMPT_STARSHIP_TRUNCATION=1
      PROMPT_STARSHIP_INCLUDE_USERNAME=true
      PROMPT_STARSHIP_INCLUDE_HOSTNAME=true
      PROMPT_EXAMPLE="${PROMPT_CONTEXT_USER}@${PROMPT_CONTEXT_HOST}:${PROMPT_CONTEXT_BASENAME} $"
      ;;
    *)
      PROMPT_CHOICE=1
      set_prompt_values
      ;;
  esac
}

step() {
  STEP_COUNTER=$((STEP_COUNTER + 1))
  echo ""
  echo "Step ${STEP_COUNTER}/${TOTAL_STEPS}: $1"
  echo "------------------------------"
}

confirm_execution() {
  echo ""
  local prompt="Do you want to continue? [y/N] "

  if [[ "${ENVIRONMENT_AUTO_CONFIRM:-}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    reply="yes"
  else
    if [[ -t 0 ]]; then
      if ! read -rp "${prompt}" reply; then
        echo "Aborted by user (no input)."
        exit 0
      fi
    elif [[ -r /dev/tty ]]; then
      if ! read -rp "${prompt}" reply < /dev/tty; then
        echo "Aborted by user (no input)."
        exit 0
      fi
    else
      echo "No interactive terminal available for confirmation. Set ENVIRONMENT_AUTO_CONFIRM=yes to run non-interactively."
      exit 1
    fi
  fi
  case "${reply:-}" in
    [yY][eE][sS]|[yY])
      echo "Proceeding with setup."
      ;;
    *)
      echo "Aborted by user."
      exit 0
      ;;
  esac
}

confirm_package_installation() {
  if ((${#PACKAGES[@]} == 0)); then
    INSTALL_PACKAGES=false
    PACKAGES_SKIPPED=true
    echo "No packages defined to install; skipping package installation."
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
      echo "Skipping package installation (ENVIRONMENT_AUTO_INSTALL_PACKAGES set to no)."
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
    echo "The following packages are queued for installation:"
    for pkg in "${PACKAGES[@]}"; do
      echo "  - ${pkg}"
    done
    echo
  fi

  prompt="${message} [Y/n] "

  if [[ -t 0 ]]; then
    if ! read -rp "${prompt}" reply; then
      echo "Skipped package installation (no input)."
      INSTALL_PACKAGES=false
      PACKAGES_SKIPPED=true
      return
    fi
  elif [[ -r /dev/tty ]]; then
    if ! read -rp "${prompt}" reply < /dev/tty; then
      echo "Skipped package installation (no input)."
      INSTALL_PACKAGES=false
      PACKAGES_SKIPPED=true
      return
    fi
  else
    echo "No interactive terminal available to confirm package installation. Set ENVIRONMENT_AUTO_INSTALL_PACKAGES=yes to proceed non-interactively."
    INSTALL_PACKAGES=false
    PACKAGES_SKIPPED=true
    return
  fi

  case "${reply:-}" in
    [nN][oO]|[nN])
      INSTALL_PACKAGES=false
      PACKAGES_SKIPPED=true
      echo "Package installation skipped by user."
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

  echo ""
  echo "Starship prompt customization will perform:"
  echo "  - Installation of the Starship prompt for bash, zsh, and fish via the official script"
  echo "  - Creation of a Starship configuration that mirrors your selected prompt style"
  echo "  - Activation snippets so supported shells initialize Starship with the chosen look"

  local prompt reply
  prompt="Activate these Starship prompt customizations? [Y/n] "

  if [[ -t 0 ]]; then
    if ! read -rp "${prompt}" reply; then
      INSTALL_STARSHIP=false
      STARSHIP_SKIPPED=true
      echo "Skipped Starship prompt customization (no input)."
      return
    fi
  elif [[ -r /dev/tty ]]; then
    if ! read -rp "${prompt}" reply < /dev/tty; then
      INSTALL_STARSHIP=false
      STARSHIP_SKIPPED=true
      echo "Skipped Starship prompt customization (no input)."
      return
    fi
  else
    echo "No interactive terminal available to confirm Starship prompt customization. Set ENVIRONMENT_AUTO_INSTALL_STARSHIP=yes to continue automatically."
    INSTALL_STARSHIP=false
    STARSHIP_SKIPPED=true
    return
  fi

  case "${reply:-}" in
    [nN][oO]|[nN])
      INSTALL_STARSHIP=false
      STARSHIP_SKIPPED=true
      echo "Starship prompt customization skipped by user."
      ;;
    *)
      INSTALL_STARSHIP=true
      ;;
  esac
}

prompt_for_shell_prompt() {
  step "Select shell prompt style"

  initialize_prompt_context

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping shell prompt selection (packages-only mode)."
    PROMPT_CHOICE=1
    set_prompt_values
    return
  fi

  local env_choice="${ENVIRONMENT_PROMPT_CHOICE:-}"
  if [[ "${env_choice}" =~ ^[1-4]$ ]]; then
    PROMPT_CHOICE="${env_choice}"
    set_prompt_values
    echo "Selected shell prompt style ${PROMPT_CHOICE} (${PROMPT_EXAMPLE}) via ENVIRONMENT_PROMPT_CHOICE."
    return
  fi

  echo "Shell prompt style options:"
  echo "  1) ${PROMPT_CONTEXT_BASENAME} \$"
  echo "  2) ${PROMPT_CONTEXT_DISPLAY_PATH} \$"
  echo "  3) ${PROMPT_CONTEXT_USER}:${PROMPT_CONTEXT_BASENAME} \$"
  echo "  4) ${PROMPT_CONTEXT_USER}@${PROMPT_CONTEXT_HOST}:${PROMPT_CONTEXT_BASENAME} \$"

  local prompt reply
  prompt="Choose a shell prompt style [1-4] (default: 1): "

  if [[ -t 0 ]]; then
    if ! read -rp "${prompt}" reply; then
      reply=""
    fi
  elif [[ -r /dev/tty ]]; then
    if ! read -rp "${prompt}" reply < /dev/tty; then
      reply=""
    fi
  else
    echo "No interactive input available; defaulting to option 1."
    PROMPT_CHOICE=1
    set_prompt_values
    return
  fi

  if [[ -z "${reply}" ]]; then
    reply="1"
  fi

  if [[ ! "${reply}" =~ ^[1-4]$ ]]; then
    echo "Invalid selection '${reply}'; defaulting to option 1."
    reply="1"
  fi

  PROMPT_CHOICE="${reply}"
  set_prompt_values
  echo "Using prompt style ${PROMPT_CHOICE}: ${PROMPT_EXAMPLE}"
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

  if [[ -t 0 ]]; then
    if ! read -rp "${prompt}" reply; then
      return 1
    fi
  elif [[ -r /dev/tty ]]; then
    if ! read -rp "${prompt}" reply < /dev/tty; then
      return 1
    fi
  else
    echo "Cannot prompt to install Homebrew (no interactive terminal). Set ENVIRONMENT_AUTO_INSTALL_HOMEBREW=yes to continue." >&2
    return 1
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
    echo "Unsupported or undetected environment."
    exit 1
  fi
}

install_packages() {
  step "Install required packages"

  if [[ "${INSTALL_PACKAGES}" != true ]]; then
    echo "Skipping package installation."
    return
  fi

  local sudo_cmd=""
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    elif command -v doas >/dev/null 2>&1; then
      sudo_cmd="doas"
    else
      echo "This script requires administrative privileges to install packages."
      exit 1
    fi
  fi

  if [[ -z "${PKG_MANAGER}" ]]; then
    echo "Homebrew not detected."
    if confirm_homebrew_installation; then
      if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        PKG_MANAGER="brew"
        install_packages
      else
        echo "Failed to install Homebrew; skipping package installation."
        PACKAGES_SKIPPED=true
      fi
    else
      echo "Homebrew installation skipped."
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
      echo "Skipping ${pkg} (not supported on ${ENVIRONMENT})."
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
          echo "Package ${resolved} (requested as ${pkg}) not available via pacman or yay; skipping."
        else
          echo "Package ${resolved} (requested as ${pkg}) not available via pacman and yay not found; skipping."
        fi
      else
        echo "Package ${resolved} (requested as ${pkg}) not available via ${PKG_MANAGER}; skipping."
      fi
      continue
    fi

    resolved_packages+=("${resolved}")
    requested_packages+=("${pkg}")
    package_managers+=("${manager}")
  done

  if ((${#resolved_packages[@]} == 0)); then
    echo "No packages available to install for ${PKG_MANAGER}."
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
          echo "Failed to refresh pacman package databases; skipping pacman installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      yay)
        if ! yay -Sy --noconfirm; then
          echo "Failed to refresh yay package databases; skipping yay installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      apt-get)
        if ! ${sudo_cmd} apt-get update; then
          echo "Failed to update apt package lists; skipping apt-get installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      brew)
        if ! brew update; then
          echo "Failed to update Homebrew; skipping brew installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      dnf)
        if ! ${sudo_cmd} dnf makecache; then
          echo "Failed to refresh dnf metadata; skipping dnf installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      yum)
        if ! ${sudo_cmd} yum makecache; then
          echo "Failed to refresh yum metadata; skipping yum installations."
          failed_refresh_managers+=("${manager}")
        fi
        ;;
      *)
        echo "Package manager ${manager} is not supported by this script."
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
      echo "Skipping ${requested_pkg}; package manager ${manager} not available for installation."
      continue
    fi

    echo "Installing ${requested_pkg} via ${manager} (${resolved_pkg})."

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
        echo "Package manager ${manager} is not supported by this script."
        return 1
        ;;
    esac

    if [[ "${install_failed}" == true ]]; then
      echo "Failed to install ${resolved_pkg} (requested as ${requested_pkg}); skipping."
      continue
    fi

    ENSURED_PACKAGES+=("${requested_pkg}")
  done

  if ((${#ENSURED_PACKAGES[@]} == 0)); then
    echo "No packages were installed due to installation failures."
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
        echo "Updated configuration block in ${target_file}."
        return
      fi
      {
        echo ""
        echo "${start_marker}"
        cat "${source_file}"
        echo "${end_marker}"
      } >> "${target_file}"
      echo "Appended configuration to ${target_file}."
    else
      {
        echo "${start_marker}"
        cat "${source_file}"
        echo "${end_marker}"
      } > "${target_file}"
      echo "Created ${target_file} with new configuration."
    fi
    return
  fi

  if [[ -e "${target_file}" ]] && cmp -s "${source_file}" "${target_file}"; then
    echo "${target_file} is already up to date."
    return
  fi

  cp "${source_file}" "${target_file}"
  echo "Installed ${target_file} from ${source_file}."
}

write_prompt_configuration() {
  if [[ -z "${PROMPT_EXAMPLE}" ]]; then
    initialize_prompt_context
    set_prompt_values
  fi

  local prompt_dir="${HOME}/.config/environment"
  local prompt_file="${prompt_dir}/prompt.sh"
  local starship_enabled="false"

  if [[ "${INSTALL_STARSHIP}" == true ]]; then
    starship_enabled="true"
  fi

  mkdir -p "${prompt_dir}"

  cat <<EOF > "${prompt_file}"
# shellcheck shell=sh
# Generated by environment setup. Do not edit manually.
ENVIRONMENT_PROMPT_CHOICE="${PROMPT_CHOICE}"
ENVIRONMENT_PROMPT_PREVIEW="${PROMPT_EXAMPLE}"
ENVIRONMENT_STARSHIP_ENABLED="${starship_enabled}"
export ENVIRONMENT_STARSHIP_ENABLED

if [ -n "\${PS1-}" ]; then
  if [ "\${ENVIRONMENT_STARSHIP_ENABLED}" = "true" ] && command -v starship >/dev/null 2>&1; then
    if [ -n "\${ZSH_VERSION-}" ]; then
      eval "\$(starship init zsh)"
    else
      eval "\$(starship init bash)"
    fi
  else
    if [ -n "\${ZSH_VERSION-}" ]; then
      PROMPT="${PROMPT_ZSH_VALUE}"
      PS1="\${PROMPT}"
    else
      PS1="${PROMPT_BASH_VALUE}"
    fi
  fi
fi
EOF

  echo "Wrote prompt configuration to ${prompt_file} (style ${PROMPT_CHOICE}: ${PROMPT_EXAMPLE})."
}

configure_environment() {
  step "Apply configuration files"

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping configuration (packages-only mode)."
    return
  fi

  local shell_snippet="${REPO_ROOT}/home/.shell.append"
  local shell_targets=(
    "${HOME}/.bashrc"
    "${HOME}/.bash_profile"
    "${HOME}/.profile"
    "${HOME}/.zshrc"
    "${HOME}/.zprofile"
  )

  for shell_target in "${shell_targets[@]}"; do
    apply_config "${shell_snippet}" "${shell_target}" "#"
  done
  apply_config "${REPO_ROOT}/home/.vimrc" "${HOME}/.vimrc" "\""
  apply_config "${REPO_ROOT}/home/.tmux.conf" "${HOME}/.tmux.conf" "#"
  apply_config "${REPO_ROOT}/home/.config/nvim/init.vim" "${HOME}/.config/nvim/init.vim" "\""
  write_prompt_configuration
  CONFIG_APPLIED=true
}

configure_aliases() {
  step "Configure shell aliases"

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping alias configuration (packages-only mode)."
    return
  fi

  if [[ ! -f "${ALIASES_FILE}" ]]; then
    echo "Aliases file not found: ${ALIASES_FILE}" >&2
    return
  fi

  local alias_dir="${HOME}/.config/environment"
  local alias_list_target="${alias_dir}/aliases.list"
  local fish_alias_target="${alias_dir}/aliases.fish"
  local posix_snippet fish_snippet

  mkdir -p "${alias_dir}"
  cp "${ALIASES_FILE}" "${alias_list_target}"
  echo "Installed alias definitions to ${alias_list_target}."

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
    echo "Generated fish aliases at ${fish_alias_target}."
  else
    {
      echo "# python3 not available; falling back to bash-compatible aliases"
      echo "# Source file: ${alias_list_target}"
    } > "${fish_alias_target}"
    cat "${alias_list_target}" >> "${fish_alias_target}"
    echo "python3 not found. Copied aliases to ${fish_alias_target} without conversion."
  fi

  posix_snippet="$(mktemp)"
  cat <<'EOF' > "${posix_snippet}"
if [ -f "${HOME}/.config/environment/aliases.list" ]; then
  # shellcheck disable=SC1090
  . "${HOME}/.config/environment/aliases.list"
fi
EOF
  apply_config "${posix_snippet}" "${HOME}/.bashrc" "# alias" append
  apply_config "${posix_snippet}" "${HOME}/.profile" "# alias" append
  apply_config "${posix_snippet}" "${HOME}/.zshrc" "# alias" append
  rm -f "${posix_snippet}"

  fish_snippet="$(mktemp)"
  cat <<'EOF' > "${fish_snippet}"
if test -f "$HOME/.config/environment/aliases.fish"
  source "$HOME/.config/environment/aliases.fish"
end
EOF
  apply_config "${fish_snippet}" "${HOME}/.config/fish/config.fish" "# alias" append
  rm -f "${fish_snippet}"

  ALIASES_CONFIGURED=true
}

generate_starship_config() {
  if [[ -z "${PROMPT_EXAMPLE}" ]]; then
    initialize_prompt_context
    set_prompt_values
  fi

  local temp_file template_path
  temp_file="$(mktemp)"
  template_path="${REPO_ROOT}/home/.config/starship.toml"

  if [[ ! -f "${template_path}" ]]; then
    echo "Starship template not found at ${template_path}." >&2
    rm -f "${temp_file}"
    return 1
  fi

  if ! cp "${template_path}" "${temp_file}"; then
    echo "Failed to copy Starship template." >&2
    rm -f "${temp_file}"
    return 1
  fi

  PROMPT_STARSHIP_FORMAT_VALUE="${PROMPT_STARSHIP_FORMAT}" \
  PROMPT_STARSHIP_DIRECTORY_PREFIX="${PROMPT_STARSHIP_DIRECTORY_PREFIX}" \
  PROMPT_STARSHIP_TRUNCATION="${PROMPT_STARSHIP_TRUNCATION}" \
  PROMPT_STARSHIP_INCLUDE_USERNAME="${PROMPT_STARSHIP_INCLUDE_USERNAME}" \
  PROMPT_STARSHIP_INCLUDE_HOSTNAME="${PROMPT_STARSHIP_INCLUDE_HOSTNAME}" \
  python3 - "$temp_file" <<'PY' || {
import os
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

def replace_once(pattern: str, repl: str, *, flags=0) -> str:
    new_text, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count == 0:
        raise SystemExit(f"Failed to apply pattern: {pattern}")
    return new_text

format_value = os.environ.get("PROMPT_STARSHIP_FORMAT_VALUE", "")
directory_prefix = os.environ.get("PROMPT_STARSHIP_DIRECTORY_PREFIX", "")
truncation = os.environ.get("PROMPT_STARSHIP_TRUNCATION", "1")
username_enabled = os.environ.get("PROMPT_STARSHIP_INCLUDE_USERNAME", "false").lower() == "true"
hostname_enabled = os.environ.get("PROMPT_STARSHIP_INCLUDE_HOSTNAME", "false").lower() == "true"

text = replace_once(r'format = """\n.*?\n"""', f'format = """\n{format_value}\n"""', flags=re.S)

directory_format = f"{directory_prefix}$path "
escaped_directory_format = directory_format.replace('\\', '\\\\').replace('"', '\\"')
text = replace_once(r'(\[directory\][^\[]*?format = )".*?"', rf'\g<1>"{escaped_directory_format}"', flags=re.S)
text = replace_once(r'(\[directory\][^\[]*?truncation_length = )\d+', rf'\g<1>{truncation}', flags=re.S)

username_value = "false" if username_enabled else "true"
text = replace_once(r'(\[username\][^\[]*?disabled = )(true|false)', rf'\g<1>{username_value}', flags=re.S)

hostname_value = "false" if hostname_enabled else "true"
text = replace_once(r'(\[hostname\][^\[]*?disabled = )(true|false)', rf'\g<1>{hostname_value}', flags=re.S)

path.write_text(text)
PY
    rm -f "${temp_file}"
    return 1
  }

  echo "${temp_file}"
}

install_starship_prompt() {
  step "Install Starship prompt"

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping Starship prompt setup (packages-only mode)."
    STARSHIP_SKIPPED=true
    return
  fi

  if [[ "${INSTALL_STARSHIP}" != true ]]; then
    echo "Starship prompt setup skipped."
    STARSHIP_SKIPPED=true
    local fish_starship_config="${HOME}/.config/fish/conf.d/starship.fish"
    if [[ -e "${fish_starship_config}" ]]; then
      rm -f "${fish_starship_config}"
      echo "Removed ${fish_starship_config} to prevent Starship initialization."
    fi
    return
  fi

  if command -v starship >/dev/null 2>&1; then
    echo "Starship prompt already installed."
  else
    if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
      echo "Installed Starship prompt using the official installer."
    else
      echo "Failed to install Starship prompt." >&2
      exit 1
    fi
  fi

  local starship_config
  starship_config="$(generate_starship_config)"
  apply_config "${starship_config}" "${HOME}/.config/starship.toml" "#"
  rm -f "${starship_config}"
  apply_config "${REPO_ROOT}/home/.config/fish/conf.d/starship.fish" "${HOME}/.config/fish/conf.d/starship.fish" "#"

  echo "Aligned Starship prompt with style ${PROMPT_CHOICE}: ${PROMPT_EXAMPLE}."
  STARSHIP_CONFIGURED=true
  STARSHIP_SKIPPED=false
}

ensure_jetbrainsmono_nerd_font() {
  step "Ensure JetBrainsMono Nerd Font"

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping JetBrainsMono Nerd Font installation (packages-only mode)."
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
    echo "JetBrainsMono Nerd Font already present at ${font_file}."
    JETBRAINS_FONT_INSTALLED=true
    return
  fi

  mkdir -p "${fonts_dir}"

  temp_dir="$(mktemp -d)"
  if [[ -z "${temp_dir}" || ! -d "${temp_dir}" ]]; then
    echo "Failed to create temporary directory for JetBrainsMono Nerd Font installation." >&2
    exit 1
  fi

  archive="${temp_dir}/JetBrainsMono.zip"
  if ! curl -fsSL "${font_url}" -o "${archive}"; then
    echo "Failed to download JetBrainsMono Nerd Font from ${font_url}." >&2
    rm -rf "${temp_dir}"
    exit 1
  fi

  extract_dir="${temp_dir}/fonts"
  mkdir -p "${extract_dir}"

  if command -v unzip >/dev/null 2>&1; then
    if ! unzip -oq "${archive}" -d "${extract_dir}"; then
      echo "Failed to extract JetBrainsMono Nerd Font archive with unzip." >&2
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
      echo "Failed to extract JetBrainsMono Nerd Font archive with python3." >&2
      rm -rf "${temp_dir}"
      exit 1
    fi
  else
    echo "Neither unzip nor python3 is available to extract the JetBrainsMono Nerd Font archive." >&2
    rm -rf "${temp_dir}"
    exit 1
  fi

  copied=false

  if command -v python3 >/dev/null 2>&1; then
    while IFS= read -r -d '' font_path; do
      if install -m 0644 "${font_path}" "${fonts_dir}/"; then
        copied=true
      else
        echo "Failed to install font file ${font_path}." >&2
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
        echo "Failed to install font file ${font_path}." >&2
        rm -rf "${temp_dir}"
        exit 1
      fi
    done < <(find "${extract_dir}" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
  fi

  if [[ "${copied}" == false ]]; then
    echo "No font files were found in the JetBrainsMono Nerd Font archive." >&2
    rm -rf "${temp_dir}"
    exit 1
  fi

  if command -v fc-cache >/dev/null 2>&1; then
    if fc-cache -f "${fonts_dir}" >/dev/null 2>&1; then
      echo "Refreshed font cache via fc-cache."
    else
      echo "Warning: failed to refresh font cache with fc-cache." >&2
    fi
  fi

  rm -rf "${temp_dir}"

  echo "Installed JetBrainsMono Nerd Font to ${fonts_dir}."
  JETBRAINS_FONT_INSTALLED=true
}

ensure_tmux_plugin_manager() {
  step "Ensure tmux plugin manager"

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping tmux plugin manager setup (packages-only mode)."
    return
  fi

  local tpm_dir="${HOME}/.tmux/plugins/tpm"

  if [[ -d "${tpm_dir}" ]]; then
    echo "tmux plugin manager already installed at ${tpm_dir}."
    TPM_INSTALLED=true
    return
  fi

  mkdir -p "${HOME}/.tmux/plugins"
  if git clone https://github.com/tmux-plugins/tpm "${tpm_dir}"; then
    echo "Installed tmux plugin manager to ${tpm_dir}."
    TPM_INSTALLED=true
  else
    echo "Failed to install tmux plugin manager." >&2
    exit 1
  fi
}

install_tmux_plugins() {
  step "Install tmux plugins"

  if [[ "${MODE}" == "packages" ]]; then
    echo "Skipping tmux plugin installation (packages-only mode)."
    return
  fi

  local install_script="${HOME}/.tmux/plugins/tpm/scripts/install_plugins.sh"

  if [[ ! -f "${install_script}" ]]; then
    echo "tmux plugin installer not found at ${install_script}." >&2
    exit 1
  fi

  if bash "${install_script}"; then
    echo "Installed tmux plugins via TPM."
    TMUX_PLUGINS_INSTALLED=true
  else
    echo "Failed to install tmux plugins via TPM." >&2
    exit 1
  fi
}

summarize() {
  step "Summary"

  if [[ "${PACKAGES_SKIPPED}" == true ]]; then
    echo "Package installation was skipped."
  elif ((${#ENSURED_PACKAGES[@]} > 0)); then
    echo "Packages ensured:"
    for pkg in "${ENSURED_PACKAGES[@]}"; do
      echo "  - ${pkg}"
    done
  else
    echo "No packages were installed by this run."
  fi

  if [[ "${CONFIG_APPLIED}" == true ]]; then
    echo "Configuration files managed:"
    echo "  - ~/.bashrc"
    echo "  - ~/.vimrc"
    echo "  - ~/.tmux.conf"
    echo "  - ~/.config/nvim/init.vim"
    echo "  - ~/.config/environment/prompt.sh"
  else
    echo "Configuration files were not updated."
  fi

  if [[ "${ALIASES_CONFIGURED}" == true ]]; then
    echo "Shell aliases configured for:"
    echo "  - bash"
    echo "  - sh"
    echo "  - zsh"
    echo "  - fish"
  else
    echo "Shell aliases were not configured."
  fi

  if [[ "${MODE}" != "packages" ]]; then
    if [[ "${STARSHIP_CONFIGURED}" == true ]]; then
      echo "Starship prompt installed and matched to the selected style."
    elif [[ "${STARSHIP_SKIPPED}" == true ]]; then
      echo "Starship prompt customization was skipped."
    else
      echo "Starship prompt was not changed."
    fi
  fi

  if [[ "${TPM_INSTALLED}" == true ]]; then
    echo "tmux plugin manager ensured."
  else
    echo "tmux plugin manager was not changed."
  fi

  if [[ "${TMUX_PLUGINS_INSTALLED}" == true ]]; then
    echo "tmux plugins installed via TPM."
  else
    echo "tmux plugins were not installed."
  fi

  if [[ "${JETBRAINS_FONT_INSTALLED}" == true ]]; then
    echo "JetBrainsMono Nerd Font ensured."
  else
    echo "JetBrainsMono Nerd Font was not changed."
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
  prompt_for_shell_prompt
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
