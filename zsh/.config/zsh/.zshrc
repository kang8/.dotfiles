. $ZDOTDIR/proxy.zsh
. $ZDOTDIR/env.zsh
. $ZDOTDIR/distribution/setup.zsh
. $ZDOTDIR/ssh-proxy.zsh

ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

plugins=(
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
)

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh

# setxkbmap -option ctrl:swapcaps
