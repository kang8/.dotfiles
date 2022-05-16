# software
alias ls="exa --icons --git"
alias vim=nvim
alias ncdu="ncdu --color dark"
alias mux="tmuxinator"
alias s=neofetch
alias p=proxychains4
alias cman="man -M /usr/share/man/zh_CN"
alias lg="lazygit --use-config-file=${HOME}/.config/lazygit/config.yml"

# git
alias ga='git add -A'
alias gs='git status -s'
alias gl="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph"
alias gla="gl --all"
alias gd='git diff'
alias gda='git diff --cached'

# custom
alias ct="cd `mktemp -d /tmp/artin-XXXXXX`"
alias vt="ct && vim temp"
alias la="laravel-artisan.sh"

## language

# php
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'
alias cpc='composer phpcs'
alias cps='composer phpstan'
