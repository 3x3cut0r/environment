if status is-interactive
  if test "$ENVIRONMENT_STARSHIP_ENABLED" = "false"
    return
  end

  if type -q starship
    starship init fish | source
  end
end
