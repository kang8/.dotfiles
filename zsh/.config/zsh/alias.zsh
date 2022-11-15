# ls
if command -v exa &> /dev/null; then
    alias ls='exa --icons --git --group-directories-first'
    alias l='ls --all'
    alias ll='ls --all --long --group'
else
    alias l='ls -a'
    alias ll='ls -alGh'
fi

# vim
command -v nvim &> /dev/null && alias vim='nvim'

# grep
command -v rg &> /dev/null && alias grep='rg'
alias rga='rg --no-ignore --hidden'

# neofetch
type s > /dev/null || alias s='neofetch'

# lazygit set custom config file
type lg > /dev/null || alias lg='lazygit --use-config-file=${HOME}/.config/lazygit/config.yml'

# git
if command -v git &> /dev/null; then
    alias ga='git add -A'
    alias gs='git status -s'
    alias gl="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph"
    alias gla="gl --all"
    alias gd='git diff'
    alias gda='git diff --cached'
    alias gcod='git checkout --detach'
    alias gct='git checkout -b temp' # create temp branch
    alias gcmessage='git show -s --pretty=%B' # just show commit message
fi

# custom
alias ct="cd `mktemp -d /tmp/artin-XXXXXX`"
alias vt="ct && vim temp"

# php
alias la="laravel-artisan.sh"
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'

function phpstan {
    if [[ -f ./vendor/bin/phpstan ]] {
        ./vendor/bin/phpstan $@
    } else {
        /opt/homebrew/bin/phpstan $@
    }
}
