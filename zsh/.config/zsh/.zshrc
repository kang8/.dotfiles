. $ZDOTDIR/env.zsh

plugins=(
    brew
    vi-mode
    git
    fast-syntax-highlighting
    zsh-autosuggestions
    docker
    docker-compose
    sudo
    fzf-tab
    rust
    gh
    npm
    z.lua
    macos
    deno
    zsh-autopair
    ssh-agent
    python
    command-not-found
    terraform
    you-should-use
    kubectl
    direnv
)

# zsh-completions setup
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
# sentry, and anything else dropping a completion into the XDG data dir
fpath+=$HOME/.local/share/zsh/site-functions

. $ZDOTDIR/omz-speedups.zsh
. $ZSH/oh-my-zsh.sh

# Dropped from `plugins` above so their init can be cached: for fzf >= 0.48 the
# plugin is just `eval "$(fzf --zsh)"`, and starship's is `starship init zsh`.
_evalcache fzf --zsh
enable-fzf-tab # fzf --zsh binds TAB; in the plugin list fzf-tab took it back

unset ZSH_THEME # starship replaces the oh-my-zsh theme
_evalcache starship init zsh

. $ZDOTDIR/gpg-agent.zsh
. $ZDOTDIR/vim-mode.zsh
. $ZDOTDIR/vim-switch.zsh
. $ZDOTDIR/widgets.zsh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh
. $ZDOTDIR/local-zshrc.zsh

# TODO: send a PR to oh-my-zsh for support atuin
# atuin setup
export ATUIN_NOBIND="true"
_evalcache atuin init zsh

# https://github.com/hchbaw/zce.zsh
. $ZDOTDIR/zce.zsh
zstyle ':zce:*' search-case smartcase

# TODO: send a PR to oh-my-zsh for support navi
# navi setup
_evalcache navi widget zsh

# wt https://github.com/max-sixty/worktrunk
_evalcache wt config shell init zsh
