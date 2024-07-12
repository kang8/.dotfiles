# ls
if command -v eza &> /dev/null; then
    alias ls='eza --icons --git --group-directories-first --sort=oldest'
    alias l='ls --all'
    alias ll='ls --all --long --group --time-style=iso'
    alias lt='ls --tree'
    alias lta='ls --all --tree'
else
    alias l='ls -a'
    alias ll='ls -alGh'
fi

# bash
alias bash 'bash --norc'

# vim
command -v nvim &> /dev/null && alias vim='nvim'

# kitty ssh
command -v kitty &> /dev/null && alias ssh='kitty +kitten ssh'

# rg
alias rga='rg --no-ignore --hidden'

# neofetch
type s > /dev/null || alias s='neofetch'

# lazygit set custom config file
type lg > /dev/null || alias lg='lazygit'

# git
if command -v git &> /dev/null; then
    alias ga='git add -A'
    alias gs='git status -s'
    alias gl="git log --pretty=\"%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset\" --graph"
    alias gla="gl --all"
    alias gd='GIT_EXTERNAL_DIFF=difft git diff'
    alias gds='GIT_EXTERNAL_DIFF=difft DFT_DISPLAY=inline git diff'
    alias gda='GIT_EXTERNAL_DIFF=difft git diff --cached'
    alias gdas='GIT_EXTERNAL_DIFF=difft DFT_DISPLAY=inline git diff --cached'
    alias gcod='git checkout --detach'
    alias gct='git checkout -b temp' # create temp branch
    alias gcmessage='git show -s --pretty=%B' # just show commit message
    alias reset-git-hook-path='git config core.hooksPath .git/hooks'

    unalias gco
    function gco() {
        if [ $# -eq 0 ]; then # if not set parameter
            git branch --sort=-committerdate | fzf --cycle | xargs git checkout
        else
            git checkout "$@"
        fi
    }

    _dedup() {
        # dedup unordered inputs, preserving order
        # whereas uniq expects the input to be sorted for deduping
        # eg:
        # ❯ echo "b\na\nb\na" | uniq | sort | paste -s -d, -
        # a,a,b,b
        # ❯ echo "b\na\nb\na" | _dedup | paste -s -d, -
        # b,a
        #
        # see https://unix.stackexchange.com/a/194790/2680
        cat -n | sort -k2 -k1n  | uniq -f1 | sort -nk1,1 | cut -f2-
    }

    function gcoa() {
        if [ $# -eq 0 ]; then # if not set parameter
            local current_branch=$(git rev-parse --abbrev-ref HEAD)
            git branch --all --sort=-committerdate | grep -Ev "remotes/origin/(HEAD|$current_branch)" |  _dedup | fzf --cycle | sed 's|remotes/origin/||' | xargs git checkout
        else
            git checkout "$@"
        fi
    }
fi

# tig
if command -v tig &> /dev/null; then
    alias tiga='tig --all'
fi

# awrit
if command -v awrit &> /dev/null; then
    alias web='awrit'
fi

# custom
alias ct="cd `mktemp -d /tmp/artin-XXXXXX`"
alias vt="ct && vim temp"

# tldr fuzzy find and preview, learning for https://www.youtube.com/watch?v=4EE7qlTaO7c
alias tldrf='tldr --list | fzf --preview "tldr {1} --color=always" --preview-window=right,70% | xargs tldr'

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
