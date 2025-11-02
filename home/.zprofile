# Source the Zsh configuration when entering a login shell.
if [ -n "${ZSH_VERSION-}" ] && [ -f "${HOME}/.zshrc" ]; then
  . "${HOME}/.zshrc"
fi
