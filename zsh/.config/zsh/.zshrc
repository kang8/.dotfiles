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
    poetry-env
    poetry
    you-should-use
    kubectl
    direnv
    starship
    jira
)

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/vim-mode.zsh
. $ZDOTDIR/vim-switch.zsh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh

# TODO: send a PR to support  atuin
# atuin setup
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"

# https://github.com/hchbaw/zce.zsh
. $ZDOTDIR/zce.zsh
zstyle ':zce:*' search-case smartcase
