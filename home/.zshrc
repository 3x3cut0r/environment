# Environment setup for Zsh
export EDITOR="nvim"
export VISUAL="nvim"

# >>> PS1.zsh >>>
# Placeholder replaced by setup.sh with the contents of home/PS1.zsh.
# <<< PS1.zsh <<<

# >>> Starship.zsh >>>
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
# <<< Starship.zsh <<<

if [[ $- == *i* ]]; then
  bindkey -e
  bindkey '^R' history-incremental-search-backward
  bindkey '^S' history-incremental-search-forward
fi
