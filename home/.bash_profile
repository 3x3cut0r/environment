# Ensure interactive shells load the Bash configuration.
if [ -f "${HOME}/.bashrc" ]; then
  . "${HOME}/.bashrc"
fi
