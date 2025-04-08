#!/usr/bin/env bash
set -Eeuo pipefail

# setup
mkdir -p ~/.config/lazygit || true
mkdir -p ~/.local/bin || true
cp .env.example .env

########
# stow
########
echo "stow begging!!!"

stow_exclude=('~/' 'ibus-rime/' 'sublime-text/' 'wakatime/' 'gnupg/' 'raycast-script/' 'tampermonkey-scripts')

for i in `ls -d */`; do
    printf "%s\n" "${stow_exclude[@]}" | grep -x -q "$i" ||
        ( echo "  stow $i" && stow $i )
done

zsh ~/.zshrc

########
# ZSH
########
ZSH="${HOME}/.config/zsh/.oh-my-zsh"

if [[ -d ${ZSH} ]]; then
    echo "oh-my-zsh is already installed."
else
    echo "Install oh-my-zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ${ZSH}
fi

if [[ -d "${ZSH}/custom/plugins/zsh-syntax-highlighting"  ]]; then
    echo "zsh-syntax-highlighting is already installed."
else
    echo "Install zsh plug: zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH}/custom/plugins/zsh-syntax-highlighting
fi

if [[ -d ${ZSH}/custom/plugins/zsh-autosuggestions ]] ; then
    echo "zsh-autosuggestions is already installed."
else
    echo "Install zsh plug: zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH}/custom/plugins/zsh-autosuggestions
fi

if [[ -d ${ZSH}/custom/plugins/fzf-tab ]] ; then
    echo "fzf-tab is already installed."
else
    echo "Install zsh plug: fzf-tab..."
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab.git ${ZSH}/custom/plugins/fzf-tab
fi

if [[ -d ${ZSH}/custom/plugins/z.lua ]] ; then
    echo "z.lua is already installed."
else
    echo "Install zsh plug: z.lua..."
    git clone --depth=1 https://github.com/skywind3000/z.lua.git ${ZSH}/custom/plugins/z.lua
fi

if [[ -d ${ZSH}/custom/plugins/zsh-autopair ]] ; then
    echo "zsh-autopair is already installed."
else
    echo "Install zsh plug: zsh-autopair..."
    git clone --depth=1 https://github.com/hlissner/zsh-autopair ${ZSH}/custom/plugins/zsh-autopair
fi

if [[ -d ${ZSH}/custom/plugins/you-should-use ]] ; then
    echo "you-should-use is already installed."
else
    echo "Install zsh plug: you-should-use..."
    git clone --depth=1 https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
fi

if [[ -d ${ZSH}/custom/plugins/F-Sy-H ]] ; then
    echo "F-Sy-H is already installed."
else
    echo "Install zsh plug: F-Sy-H..."
    git clone --depth=1 https://github.com/z-shell/F-Sy-H.git $ZSH_CUSTOM/plugins/F-Sy-H
fi

if [[ -d ${ZSH}/custom/plugins/zsh-completions ]] ; then
    echo "zsh-completions is already installed."
else
    echo "Install zsh plug: zsh-completions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-completions.git $ZSH_CUSTOM/plugins/zsh-completions
fi

######## neovim ######## echo "\n"
echo "neovim begging!!!"
echo "\n"
if [[ -d ~/.config/nvim ]];then
    echo "~/.config/nvim is already installed."
else
    git clone --depth=1 git@github.com:kang8/.vimrc.git ~/.config/nvim
fi

########
# gpg
########
echo "\n"
echo "gpg begging!!!"
echo "\n"

# create ~/.gnupg/
gpg -k

if [[ -d ~/kang/gpg-key-ring ]]; then
    echo "~/kang/gpg-key-ring is already installed."
else
    git clone --depth=1 git@github.com:kang8/gpg-key-ring.git ~/kang/gpg-key-ring
fi

stow gnupg
