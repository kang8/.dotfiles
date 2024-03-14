. $ZDOTDIR/env.zsh
. $ZDOTDIR/distribution/setup.zsh
. $ZDOTDIR/proxy.zsh

plugins=(
    vi-mode
    git
    git-auto-fetch
    zsh-syntax-highlighting
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
    ripgrep
    npm
    z.lua
    macos
    deno
    zsh-autopair
    ssh-agent
    python
)

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/vim-mode.zsh
. $ZDOTDIR/vim-switch.zsh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh

eval "$(starship init zsh)"
# setxkbmap -option ctrl:swapcaps
