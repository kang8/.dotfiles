export EDITOR=nvim
export MANPAGER='nvim +Man!'
export LC_ALL=en_US.UTF-8
export ZSH=~/.config/zsh/.oh-my-zsh

# fzf
export FZF_DEFAULT_OPTS='--color "light"'

export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude ".git"'
export FZF_CTRL_T_OPTS="
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(hidden|)'"

export FZF_ALT_C_OPTS="
    --preview 'tree -C {}'
    --bind 'ctrl-/:change-preview-window(hidden|)'"

# bat
export BAT_THEME="Coldark-Cold"

# lazygit
export LG_CONFIG_FILE="${HOME}/.config/lazygit/config.yml"

# ripgrep
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/.ripgreprc

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm code completion
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

# opam configuration
[[ ! -r ~/.opam/opam-init/init.zsh ]] || source ~/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

# llvm
[[ -d /opt/homebrew/opt/llvm/bin ]] && export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
# python
[[ -d /opt/homebrew/opt/python/libexec/bin ]] && export PATH="/opt/homebrew/opt/python/libexec/bin:$PATH"
export PYTHON_AUTO_VRUN=true
export PYTHON_VENV_NAME=venv
export VIRTUAL_ENV_DISABLE_PROMPT=1

# PATH
export PATH=$PATH:~/.local/bin # customize binary file and python binary file
export PATH=$PATH:~/go/bin # go binary file
[[ -d /opt/homebrew/opt/node@18/bin ]] && export PATH=/opt/homebrew/opt/node@18/bin:$PATH # Use Node.js LTS version
[[ -d ~/.local/share/bob/nvim-bin ]] && export PATH=$PATH:~/.local/share/bob/nvim-bin # bob, a neovim version manager
[[ -d /opt/homebrew/opt/rustup/bin ]] && export PATH=$PATH:/opt/homebrew/opt/rustup/bin # rustup

# history
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000
export HISTFILESIZE=-1

export HISTORY_IGNORE="(ll|l|ls|cd|cd -|exit|* --help|z)" # Make some commands not show up in history

# man zshoptions or man zshparam
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt PUSHD_IGNORE_DUPS

setopt nocaseglob # ignore case
setopt correct # correct spelling mistakes

# customize variable
[[ -e ~/.dotfiles/.env ]] && . ~/.dotfiles/.env

# navi
export NAVI_CONFIG="$HOME/.config/navi/config.yaml"

# V2rays
export V2RAYA_ADDRESS=2017

# zsh-you-should-use
export YSU_MESSAGE_POSITION="after"
export YSU_IGNORED_ALIASES=("ll")
export YSU_MODE=ALL

# Added by OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# k9s
export K9S_CONFIG_DIR=$HOME/.config/k9s
