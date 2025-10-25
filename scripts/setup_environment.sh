#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PACKAGES=(
  curl
  wget
  exa
  ranger
  tmux
  ncdu
  git
  bash-completion
  neovim
  vim
  mtr
  ripgrep
  sshpass
  rsync
  unzip
  lshw
  zoxide
  watch
  dog
  tcpdump
  wormhole
  lazydocker
  unp
  jq
  termshark
)
ENSURED_PACKAGES=()
STEP_COUNTER=0

step() {
  STEP_COUNTER=$((STEP_COUNTER + 1))
  echo ""
  echo "Step ${STEP_COUNTER}: $1"
  echo "------------------------------"
}

confirm_execution() {
  step "Confirm start"
  read -rp "This script will install packages and update configuration files. Continue? [y/N] " reply
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

detect_environment() {
  step "Detect operating system"
  local uname_out
  uname_out="$(uname -s)"
  if [[ "${uname_out}" == "Darwin" ]]; then
    ENVIRONMENT="mac"
    if command -v brew >/dev/null 2>&1; then
      PKG_MANAGER="brew"
    else
      PKG_MANAGER=""
    fi
    echo "Detected macOS."
    return 0
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
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

  echo "Environment: ${ENVIRONMENT} (package manager: ${PKG_MANAGER})"
}

install_packages() {
  step "Install required packages"
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
    echo "Homebrew not detected. Attempting installation."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    PKG_MANAGER="brew"
    install_packages
    return
  fi

  if [[ "${PKG_MANAGER}" == "apt-get" ]]; then
    ${sudo_cmd} apt-get update
  elif [[ "${PKG_MANAGER}" == "brew" ]]; then
    brew update
  fi

  local resolved_packages=()
  ENSURED_PACKAGES=()
  for pkg in "${PACKAGES[@]}"; do
    local resolved
    resolved="$(resolve_package_name "${pkg}")"
    if [[ -z "${resolved}" ]]; then
      echo "Skipping ${pkg} (not supported on ${ENVIRONMENT})."
      continue
    fi
    if is_package_available "${resolved}"; then
      resolved_packages+=("${resolved}")
      ENSURED_PACKAGES+=("${pkg}")
    else
      echo "Package ${resolved} (requested as ${pkg}) not available via ${PKG_MANAGER}; skipping."
    fi
  done

  if ((${#resolved_packages[@]} == 0)); then
    echo "No packages available to install for ${PKG_MANAGER}."
    return
  fi

  echo "Installing packages via ${PKG_MANAGER}: ${resolved_packages[*]}"

  case "${PKG_MANAGER}" in
    pacman)
      ${sudo_cmd} pacman -Syu --noconfirm --needed "${resolved_packages[@]}"
      ;;
    apt-get)
      ${sudo_cmd} apt-get install -y "${resolved_packages[@]}"
      ;;
    dnf)
      ${sudo_cmd} dnf install -y "${resolved_packages[@]}"
      ;;
    yum)
      ${sudo_cmd} yum install -y "${resolved_packages[@]}"
      ;;
    brew)
      brew install "${resolved_packages[@]}"
      ;;
    *)
      echo "Package manager ${PKG_MANAGER} is not supported by this script."
      exit 1
      ;;
  esac
}

resolve_package_name() {
  local pkg="$1"
  case "${pkg}" in
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
  case "${PKG_MANAGER}" in
    pacman)
      pacman -Si "${pkg}" >/dev/null 2>&1
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
  local comment_prefix="$3"
  local start_marker end_marker

  start_marker="${comment_prefix} >>> environment repo config >>>"
  end_marker="${comment_prefix} <<< environment repo config <<<"

  mkdir -p "$(dirname "${target_file}")"

  if [[ -e "${target_file}" ]]; then
    if grep -Fq "${start_marker}" "${target_file}"; then
      echo "Config snippet already present in ${target_file}."
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
}

configure_environment() {
  step "Apply configuration files"
  apply_config "${REPO_ROOT}/home/.bashrc.append" "${HOME}/.bashrc" "#"
  apply_config "${REPO_ROOT}/home/.vimrc" "${HOME}/.vimrc" "\""
  apply_config "${REPO_ROOT}/home/.tmux.conf" "${HOME}/.tmux.conf" "#"
  apply_config "${REPO_ROOT}/home/.config/nvim/init.vim" "${HOME}/.config/nvim/init.vim" "\""
}

summarize() {
  step "Summary"
  if ((${#ENSURED_PACKAGES[@]} > 0)); then
    echo "Packages ensured: ${ENSURED_PACKAGES[*]}"
  else
    echo "No packages were installed by this run."
  fi
  echo "Configuration files updated: ~/.bashrc, ~/.vimrc, ~/.tmux.conf, ~/.config/nvim/init.vim"
}

main() {
  confirm_execution
  detect_environment
  if [[ "${ENVIRONMENT}" == "mac" && -z "${PKG_MANAGER}" ]]; then
    step "Install Homebrew"
    install_packages
  else
    install_packages
  fi
  configure_environment
  summarize
}

main "$@"
