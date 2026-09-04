# zmodload zsh/zprof
ZDOTDIR=$HOME/.config/zsh
. $ZDOTDIR/evalcache.zsh

# Initialize Homebrew (must be before env.zsh which depends on $HOMEBREW_PREFIX)
if [[ -x /opt/homebrew/bin/brew ]]; then
  _evalcache /opt/homebrew/bin/brew shellenv
elif [[ -x /usr/local/bin/brew ]]; then
  _evalcache /usr/local/bin/brew shellenv
fi

. $ZDOTDIR/.zshrc
# zprof
