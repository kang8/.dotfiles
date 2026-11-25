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
  # Claude Code passes globs like `--include=*.ts` unquoted; nomatch aborts the command.
  if [[ -n $CLAUDECODE ]]; then
    setopt nonomatch
  else
    setopt nomatch
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd chpwd_load_local_zshrc
chpwd_load_local_zshrc

# Agents expect stock commands; aliases like `s`, `g`, `grep`, `ls` break their scripts.
[[ -n $CLAUDECODE ]] && unalias -m '*'
