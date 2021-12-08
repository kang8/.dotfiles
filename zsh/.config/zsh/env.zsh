export EDITOR=nvim
export JAVA_HOME=/usr/lib/jvm/default
export MANPAGER='nvim +Man!'
export LC_ALL=en_US.UTF-8
export ZSH=~/.config/zsh/.oh-my-zsh

# PATH
export PATH=$PATH:~/.local/bin # customize binary file and python binary file
export PATH=$PATH:~/go/bin # go binary file

# history
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
[ "$HISTSIZE" -lt 50000 ] && HISTSIZE=500000
[ "$SAVEHIST" -lt 10000 ] && SAVEHIST=100000

# Allow multiple terminal sessions to all append to one zsh command history
setopt append_history
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify            # show command with history expansion to user before running it
setopt INC_APPEND_HISTORY # append into history file
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS  ## Delete empty lines from history file
setopt HIST_NO_STORE  ## Do not add history and fc commands to the history

# customize variable
if [[ -n `grep WORK=true ~/.dotfiles/.env` ]]; then
    export is_work=true
fi
