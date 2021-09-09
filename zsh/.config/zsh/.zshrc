export ZSH=~/.oh-my-zsh

ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    fzf
    systemd
    docker
    mvn
    gh
    sudo
)

. $ZSH/oh-my-zsh.sh
. $ZDOTDIR/key-bindings.zsh
. $ZDOTDIR/alias.zsh
. $ZDOTDIR/env.zsh
. $ZDOTDIR/distribution/setup.zsh

# setxkbmap -option ctrl:swapcaps
