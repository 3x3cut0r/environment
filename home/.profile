# Source the Bash configuration when entering a login shell.
if [ -n "${BASH_VERSION-}" ] && [ -f "${HOME}/.bashrc" ]; then
  . "${HOME}/.bashrc"
fi
