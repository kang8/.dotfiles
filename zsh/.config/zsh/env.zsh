export EDITOR=nvim
export JAVA_HOME=/usr/lib/jvm/default
export MANPAGER='nvim +Man!'

# PATH
export PATH=$PATH:/home/kang/.local/share/gem/ruby/2.7.0/bin
export PATH=$PATH:/home/kang/go/bin
export PATH=$PATH:/home/kang/.local/bin # python pip install library

# history
HISTFILE=~/.zsh_history
HISTIGNORE='pwd:exit:top:clear:history:ls:l:ll'
HISTSIZE=100000
SAVEHIST=100000

# Allow multiple terminal sessions to all append to one zsh command history
setopt append_history
setopt hist_ignore_dups
setopt hist_ignore_space
