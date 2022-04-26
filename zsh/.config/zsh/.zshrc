. $ZDOTDIR/env.zsh
. $ZDOTDIR/distribution/setup.zsh
. $ZDOTDIR/ssh-proxy.zsh
. $ZDOTDIR/proxy.zsh

ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

plugins=(
    vi-mode
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    fzf
    systemd
    docker
    docker-compose
    sudo
    laravel
    composer
    gpg-agent
    fzf-tab
)

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/vim_mode.zsh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh
eval "$(thefuck --alias)"

# setxkbmap -option ctrl:swapcaps
