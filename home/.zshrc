# Environment setup for Zsh
export EDITOR="nvim"
export VISUAL="nvim"

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  # >>> PS1.zsh >>>
  # Placeholder replaced by setup.sh with the contents of home/PS1.zsh.
  # <<< PS1.zsh <<<
fi
