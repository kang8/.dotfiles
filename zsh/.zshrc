# Linuxbrew
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    export FZF_BASE=/home/linuxbrew/.linuxbrew/Cellar/fzf/0.27.2/
fi

export ZSH="/home/kang/.oh-my-zsh"

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
)

source $ZSH/oh-my-zsh.sh
source /usr/share/nvm/init-nvm.sh

# zsh-autosuggestions config
bindkey '^ ' autosuggest-accept # contrl + space 填充历史命令

alias ls="exa --icons --git"
alias vim=nvim
alias ra="ranger"
alias ncdu="ncdu --color dark"
alias mux="tmuxinator"
alias s=neofetch
alias p=proxychains4
alias cman="man -M /usr/share/man/zh_CN"

# git
alias ga='git add -A'
alias gs='git status -s'
alias gl="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph"
alias gla="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph --all"
alias gd='git diff'
alias gda='git diff --cached'

alias cg="curl google.com"

export PATH=$PATH:/home/kang/.local/share/gem/ruby/2.7.0/bin
export PATH=$PATH:/home/kang/go/bin
export PATH=$PATH:/home/kang/.local/bin # python pip install library
export EDITOR=nvim

export JAVA_HOME=/usr/lib/jvm/default

# setxkbmap -option ctrl:swapcaps

# history
export HISTIGNORE='pwd:exit:top:clear:history:ls:l:ll'
export HISTSIZE=10000
export SAVEHIST=100000
# proxy
export http_proxy=http://10.0.3.2:10809
export https_proxy=http://10.0.3.2:10809
