# Linuxbrew
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    export FZF_BASE=/home/linuxbrew/.linuxbrew/Cellar/fzf/0.27.2/
fi

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

source $ZSH/oh-my-zsh.sh
. $ZDOTDIR/alias.zsh

# zsh-autosuggestions config
bindkey '^ ' autosuggest-accept # contrl + space 填充历史命令

export PATH=$PATH:/home/kang/.local/share/gem/ruby/2.7.0/bin
export PATH=$PATH:/home/kang/go/bin
export PATH=$PATH:/home/kang/.local/bin # python pip install library
export EDITOR=nvim

export JAVA_HOME=/usr/lib/jvm/default

# setxkbmap -option ctrl:swapcaps

# distribution setting
# WSL2
if [[ -n `cat /proc/version | grep -i wsl2` ]]; then
    echo "It is WSL2"
    export proxy_ip=`cat /etc/resolv.conf | grep nameserver | awk '{print $2}'`
    export proxy_port=10809

    # WSL GPG setting
    export GPG_TTY=$(tty)
# Arch Linux
elif [[ -n `cat /proc/version | grep -i arch` ]]; then
    echo "It is Arch Linux"
    export proxy_ip=127.0.0.1
    export proxy_port=8889
    source /usr/share/nvm/init-nvm.sh
else
    echo "Can't find Linux distribution!!!"
fi

# history
HISTFILE=~/.zsh_history
export HISTIGNORE='pwd:exit:top:clear:history:ls:l:ll'
export HISTSIZE=10000
export SAVEHIST=100000

export http_proxy=http://${proxy_ip}:${proxy_port}
export https_proxy=http://${proxy_ip}:${proxy_port}
