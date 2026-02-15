bindkey '^ ' autosuggest-accept # control + space
bindkey '^f' forward-char
bindkey '^[f' forward-word # <alt-f>
bindkey '^b' backward-char
bindkey '^[b' backward-word
bindkey '^u' backward-kill-line
bindkey '^y' yank
bindkey '^r' _atuin_search_widget
bindkey -s '^o' 'ranger^M'
bindkey -s '^k' 'fork^M'
bindkey -s '^[[102;6u' 'fzf_rg^M' # <C-S-f>
bindkey -s '^[[109;6u' 'fzf_man^M'  # <C-S-m>
bindkey '^s' _navi_widget
bindkey -s '^[[98;9u' '$(git branch --show-current)^I' # <cmd-b>
bindkey "^[[105;6u" zce # <C-S-i>
bindkey '^[[106;6u' jq-complete # <C-S-j>

bindkey '\C-x\C-e' edit-command-line
bindkey -M vicmd 'm' edit-command-line

bindkey '^w' backward-kill-word-smart
