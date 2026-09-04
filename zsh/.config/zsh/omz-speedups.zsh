# Trim oh-my-zsh's fixed startup cost, from outside $ZSH (see ~/.agents/AGENTS.md).
# Everything here must run before oh-my-zsh.sh; delete the file and its source
# line in .zshrc for stock behaviour.

# Skip compinit's security audit: 50-95ms, and `compaudit` finds nothing here.
export ZSH_DISABLE_COMPFIX=true

# `-u` still audits — only `-C` skips it. oh-my-zsh already drops the dump when
# $fpath changes, so the 24h window only delays picking up a new completion.
compinit() {
  unfunction compinit
  autoload -Uz compinit

  local -a fresh=( ${ZSH_COMPDUMP}(N.mh-24) )
  if (( $#fresh )); then
    compinit -C -d "$ZSH_COMPDUMP"
  else
    compinit "$@"
  fi
}

# Load ssh identities on first use instead of at startup (~13ms).
zstyle :omz:plugins:ssh-agent lazy yes

# The update check spawns git on every startup (~5ms) to decide it has nothing
# to do. Run `omz update` by hand instead.
zstyle ':omz:update' mode disabled

# $SHORT_HOST costs a `scutil` call (~7ms) per startup and now only names the
# ssh-agent env cache, so a day-old answer will do. Caching rather than taking
# oh-my-zsh's ${HOST/.*/} fallback: the two disagree here (kangs-MacBook-M4-Pro
# vs kang), and the ssh-agent filename would move.
scutil() {
  if [[ $1 != --get || $2 != LocalHostName ]]; then
    command scutil "$@"
    return
  fi

  local cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/localhostname
  local -a fresh=( $cache(N.mh-24) )
  if (( ! $#fresh )); then
    [[ -d ${cache:h} ]] || command mkdir -p ${cache:h} 2>/dev/null
    command scutil --get LocalHostName >| $cache 2>/dev/null
  fi

  [[ -s $cache ]] && print -r -- "$(<$cache)" || command scutil --get LocalHostName
}

# oh-my-zsh calls the shim in a subshell, so it cannot unfunction itself.
_omz_speedups_cleanup() {
  unfunction scutil 2>/dev/null
  add-zsh-hook -d precmd _omz_speedups_cleanup
  unfunction _omz_speedups_cleanup
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _omz_speedups_cleanup
