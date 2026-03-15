# zmodload zsh/zprof
ZDOTDIR=$HOME/.config/zsh

# Initialize Homebrew (must be before env.zsh which depends on $HOMEBREW_PREFIX)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

. $ZDOTDIR/.zshrc
# zprof
