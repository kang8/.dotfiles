export EDITOR=nvim
export JAVA_HOME=/usr/lib/jvm/default
export MANPAGER='nvim +Man!'
export LC_ALL=en_US.UTF-8
export ZSH=~/.config/zsh/.oh-my-zsh

# PATH
export PATH=$PATH:~/.local/bin # customize binary file and python binary file
export PATH=$PATH:~/go/bin # go binary file

# history
HISTFILE=~/.zsh_history
HISTIGNORE='pwd:exit:top:clear:history:ls:l:ll'
HISTSIZE=100000
SAVEHIST=100000

# Allow multiple terminal sessions to all append to one zsh command history
setopt append_history
setopt hist_ignore_dups
setopt hist_ignore_space
