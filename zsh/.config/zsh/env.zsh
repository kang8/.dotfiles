export EDITOR=nvim
export MANPAGER='nvim +Man!'
export LC_ALL=en_US.UTF-8
export ZSH=~/.config/zsh/.oh-my-zsh

# fzf
export FZF_DEFAULT_OPTS='--color "light"'


# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm code completion
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

# PATH
export PATH=$PATH:~/.local/bin # customize binary file and python binary file
export PATH=$PATH:~/go/bin # go binary file

# history
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000000000
export HISTFILESIZE=1000000000

# man zshoptions or man zshparam
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

# customize variable
if [[ -n `grep WORK=true ~/.dotfiles/.env` ]]; then
    export is_work=true
fi
