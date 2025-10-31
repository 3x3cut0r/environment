# Environment setup for Bash
export EDITOR="nvim"
export VISUAL="nvim"

# Initialize Starship when available, otherwise fall back to the configured PS1.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  # >>> PS1.bash >>>
  # Placeholder replaced by setup.sh with the contents of home/PS1.bash.
  # <<< PS1.bash <<<
fi
