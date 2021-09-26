. $ZDOTDIR/env.zsh
. $ZDOTDIR/distribution/setup.zsh

export ZSH=~/.oh-my-zsh
export LC_ALL=en_US.UTF-8

ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    fzf
    systemd
    docker
    docker-compose
    mvn
    gh
    sudo
    laravel
    composer
)

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh

# setxkbmap -option ctrl:swapcaps
