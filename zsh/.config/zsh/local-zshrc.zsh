chpwd_load_local_zshrc() {
  local file=".zsh-local"
  local dir="$PWD"

  # Search for .zsh-local from current directory up to root
  while [[ $dir != / ]]; do
    if [[ -f "$dir/$file" ]]; then
      source "$dir/$file"
      return
    fi
    dir=${dir:h}
  done

  # If .zsh-local is not found, restore global default behavior
  setopt nomatch
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd chpwd_load_local_zshrc
chpwd_load_local_zshrc
