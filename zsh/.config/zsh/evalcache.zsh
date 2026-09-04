# Cache `eval "$(tool init …)"` blocks, whose output only changes when the tool
# is upgraded — so key the cache on the binary and regenerate when it is newer.
#
#   eval "$(atuin init zsh)"   ->   _evalcache atuin init zsh
#
# `evalcache-clear` throws everything away if a cache goes stale anyway.

typeset -g ZSH_EVALCACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/evalcache

_evalcache() {
  # Absolute paths (brew) aren't in $commands
  local bin=${commands[$1]:-$1}
  [[ -x $bin ]] || return 0

  local key=${${(j:-:)@}//[^A-Za-z0-9_-]/_}
  local cache=$ZSH_EVALCACHE_DIR/$key.zsh

  if [[ ! -s $cache || $bin -nt $cache ]]; then
    [[ -d $ZSH_EVALCACHE_DIR ]] || command mkdir -p $ZSH_EVALCACHE_DIR 2>/dev/null
    # Write via a temp file: a half-written cache would break every later shell
    if ! "$@" >| $cache.$$ 2>/dev/null || [[ ! -s $cache.$$ ]]; then
      command rm -f $cache.$$
      eval "$("$@")"
      return
    fi
    command mv -f $cache.$$ $cache
    zcompile -R -- $cache 2>/dev/null
  fi

  source $cache
}

evalcache-clear() {
  command rm -rf -- $ZSH_EVALCACHE_DIR
  print -r -- "evalcache: cleared $ZSH_EVALCACHE_DIR"
}
