# zsh-autosuggestions config
bindkey '^ ' autosuggest-accept # control + space 填充历史命令
bindkey '^f' forward-char
bindkey '^b' backward-char
bindkey -s '^o' 'ranger^M'
bindkey -s '^k' 'fork^M'

bindkey '\C-x\C-e' edit-command-line
bindkey -M vicmd 'm' edit-command-line
