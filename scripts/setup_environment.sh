#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/packages.list"
ALIASES_FILE="${SCRIPT_DIR}/aliases.list"

MODE="all"
PACKAGES=()
ENSURED_PACKAGES=()
STEP_COUNTER=0
CONFIG_APPLIED=false
TPM_INSTALLED=false
ALIASES_CONFIGURED=false

display_environment_info() {
  step "Environment information"

  local uname_s uname_r arch shell_name workdir

  if uname_s=$(uname -s 2>/dev/null); then
    :
  else
    uname_s="unknown"
  fi

  if uname_r=$(uname -r 2>/dev/null); then
    :
  else
    uname_r="unknown"
  fi

  if arch=$(uname -m 2>/dev/null); then
    :
  else
    arch="unknown"
  fi

  shell_name="${SHELL:-unknown}"
  workdir="${PWD:-unknown}"

  echo "User: $(whoami 2>/dev/null || echo unknown)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  echo "Operating system: ${uname_s} ${uname_r}"
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
Usage: setup_environment.sh [OPTIONS]

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

step() {
  STEP_COUNTER=$((STEP_COUNTER + 1))
  echo ""
  echo "Step ${STEP_COUNTER}: $1"
  echo "------------------------------"
}

confirm_execution() {
  local message="This script will install packages and update configuration files."
  if [[ "${MODE}" == "packages" ]]; then
    message="This script will install packages only."
  fi

  step "Confirm start"

  if [[ "${ENVIRONMENT_AUTO_CONFIRM:-}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    reply="yes"
  else
    if [[ -t 0 ]]; then
      if ! read -rp "${message} Continue? [y/N] " reply; then
        echo "Aborted by user (no input)."
        exit 0
      fi
    elif [[ -r /dev/tty ]]; then
      if ! read -rp "${message} Continue? [y/N] " reply < /dev/tty; then
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
  CONFIG_APPLIED=true
}

configure_aliases() {
  step "Configure shell aliases"

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
pattern = re.compile(r"^alias\s+([^=\s]+)\s*=\s*(.+)$")

for raw in source_path.read_text().splitlines():
    stripped = raw.strip()
    if not stripped or stripped.startswith("#"):
        continue
    match = pattern.match(stripped)
    if not match:
        lines.append(f"# Skipped unsupported alias line: {stripped}")
        continue
    name, value = match.groups()
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    lines.append(f'alias {name} "{escaped}"')

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
  apply_config "${posix_snippet}" "${HOME}/.bashrc" "# alias"
  apply_config "${posix_snippet}" "${HOME}/.profile" "# alias"
  apply_config "${posix_snippet}" "${HOME}/.zshrc" "# alias"
  rm -f "${posix_snippet}"

  fish_snippet="$(mktemp)"
  cat <<'EOF' > "${fish_snippet}"
if test -f "$HOME/.config/environment/aliases.fish"
  source "$HOME/.config/environment/aliases.fish"
end
EOF
  apply_config "${fish_snippet}" "${HOME}/.config/fish/config.fish" "# alias"
  rm -f "${fish_snippet}"

  ALIASES_CONFIGURED=true
}

ensure_tmux_plugin_manager() {
  step "Ensure tmux plugin manager"
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

summarize() {
  step "Summary"
  if ((${#ENSURED_PACKAGES[@]} > 0)); then
    echo "Packages ensured: ${ENSURED_PACKAGES[*]}"
  else
    echo "No packages were installed by this run."
  fi
  if [[ "${CONFIG_APPLIED}" == true ]]; then
    echo "Configuration files managed: ~/.bashrc, ~/.vimrc, ~/.tmux.conf, ~/.config/nvim/init.vim"
  else
    echo "Configuration files were not updated."
  fi
  if [[ "${ALIASES_CONFIGURED}" == true ]]; then
    echo "Shell aliases configured for bash, sh, zsh, and fish."
  else
    echo "Shell aliases were not configured."
  fi
  if [[ "${TPM_INSTALLED}" == true ]]; then
    echo "tmux plugin manager ensured."
  else
    echo "tmux plugin manager was not changed."
  fi
}

main() {
  parse_args "$@"
  load_packages
  display_environment_info
  confirm_execution
  detect_environment
  if [[ "${ENVIRONMENT}" == "mac" && -z "${PKG_MANAGER}" ]]; then
    step "Install Homebrew"
    install_packages
  else
    install_packages
  fi
  if [[ "${MODE}" != "packages" ]]; then
    configure_environment
    configure_aliases
    ensure_tmux_plugin_manager
  fi
  summarize
}

main "$@"
