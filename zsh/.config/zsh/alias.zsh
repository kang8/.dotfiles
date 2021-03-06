# software
alias ls="exa --icons --git"
alias grep="rg"
alias vim=nvim
alias mux="tmuxinator"
alias s=neofetch
alias cman="man -M /usr/share/man/zh_CN"
alias lg="lazygit --use-config-file=${HOME}/.config/lazygit/config.yml"

# git
alias ga='git add -A'
alias gs='git status -s'
alias gl="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph"
alias gla="gl --all"
alias gd='git diff'
alias gda='git diff --cached'
alias gcod='git checkout --detach'
alias gct='git checkout -b temp' # create temp branch

# custom
alias ct="cd `mktemp -d /tmp/artin-XXXXXX`"
alias vt="ct && vim temp"
alias la="laravel-artisan.sh"

## language

# php
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'
alias cpc='composer phpcs'
alias cps='composer phpstan'
