#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="3x3cut0r"
REPO_NAME="environment"
BRANCH="${ENVIRONMENT_BRANCH:-main}"

TMP_DIR=""

cleanup() {
  local exit_code=${1:-$?}

  trap - EXIT ERR INT TERM HUP QUIT

  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
    TMP_DIR=""
  fi

  exit "${exit_code}"
}

trap 'cleanup $?' EXIT
trap 'cleanup $?' ERR
trap 'cleanup 130' INT
trap 'cleanup 143' TERM
trap 'cleanup 129' HUP
trap 'cleanup 131' QUIT

for tool in curl tar; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "${tool} is required to bootstrap the environment setup." >&2
    exit 1
  fi
done

TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${BRANCH}"
TMP_DIR="$(mktemp -d)"

if [[ -z "${TMP_DIR}" || ! -d "${TMP_DIR}" ]]; then
  echo "Failed to create temporary directory." >&2
  exit 1
fi

if ! curl -fsSL "${TARBALL_URL}" | tar -xz -C "${TMP_DIR}" --strip-components=1; then
  echo "Failed to download or extract repository archive from ${TARBALL_URL}." >&2
  exit 1
fi

SCRIPT_PATH="${TMP_DIR}/scripts/setup_environment.sh"
if [[ ! -x "${SCRIPT_PATH}" ]]; then
  if [[ -f "${SCRIPT_PATH}" ]]; then
    chmod +x "${SCRIPT_PATH}"
  else
    echo "Expected setup script not found in repository archive." >&2
    exit 1
  fi
fi

"${SCRIPT_PATH}" "$@"
