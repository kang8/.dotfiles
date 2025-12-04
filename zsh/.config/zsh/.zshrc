. $ZDOTDIR/env.zsh
. $ZDOTDIR/distribution/setup.zsh
. $ZDOTDIR/proxy.zsh

plugins=(
    brew
    vi-mode
    git
    git-auto-fetch
    zsh-syntax-highlighting
    F-Sy-H
    zsh-autosuggestions
    fzf
    systemd
    docker
    docker-compose
    sudo
    composer
    gpg-agent
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
    starship
    jira
    jq
)

# zsh-completions setup
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/vim-mode.zsh
. $ZDOTDIR/vim-switch.zsh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh
. $ZDOTDIR/local-zshrc.zsh

# TODO: send a PR to oh-my-zsh for support atuin
# atuin setup
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"

# https://github.com/hchbaw/zce.zsh
. $ZDOTDIR/zce.zsh
zstyle ':zce:*' search-case smartcase

# TODO: send a PR to oh-my-zsh for support navi
# navi setup
eval "$(navi widget zsh)"
