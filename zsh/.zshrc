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
)

source $ZSH/oh-my-zsh.sh
source /usr/share/nvm/init-nvm.sh

alias vim=nvim
alias ls=colorls
alias ll=colorls -l
alias cg="curl google.com"
alias ga='git add -A'
alias gs='git status -s'
alias gc='git checkout'
alias gr='git reset'
alias gl="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph"
alias gla="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph --all"
alias gd='git diff'
alias gda='git diff --cached'
alias ra="ranger"
alias ncdu="ncdu --color dark"
alias mux="tmuxinator"

bindkey '^ ' autosuggest-accept # contrl + space 填充历史命令

export PATH=$PATH:/home/kang/.local/share/gem/ruby/2.7.0/bin
export PATH=$PATH:/home/kang/go/bin
export PATH=$PATH:/home/kang/.local/bin # python pip install library
export EDITOR=nvim
