#!/usr/bin/env bash
set -Eeuo pipefail

# 检查系统的版本

# 先检查程序是否安装

########
# stow
########
echo "stow beging!!!"

stow_exclude=('~/' 'ibus-rime/' 'sublime-text/' 'wakatime/')

for i in `ls -d */`; do
    printf "%s\n" "${stow_exclude[@]}" | grep -x -q "$i" ||
        echo "  stow $i" &&
        stow $i
done

source ~/.zshrc

########
# ssh key
########
is_missing_ssh=false
for i in $HOME/.ssh/id_ed25519{,.pub}; do
    if [[ ! -f $i ]]; then
        echo "$i is missing!"
        is_missing_ssh=true
    fi
done

if [[ $is_missing_ssh == "true" ]]; then
    read -rp "Can't found ssh key, Do your want to generate a new SSH key? [y|N] " is_generate
    if [[ -n $is_generate && ($is_generate == "Y" || $is_generate == 'y') ]]; then
        read -rp "Please input SSH key common: " ssh_common
        echo -ne "\n\n\n" | ssh-keygen -t ed25519 -C "$ssh_common"
    fi
fi

# TODO: test `ssh -T git@github.com` if not througt to set ssh key to github.

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

if [[ -d ${ZSH}/custom/themes/powerlevel10k  ]]; then
    echo "powerlevel10k is already installed."
else
    echo "Install zsh theme: powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH}/custom/themes/powerlevel10k
fi

########
# tmux
########
echo "tmux beging!!!"
if [[ -d ~/.tmux ]]; then
    echo "oh-my-tmux is already installed."
else
    git clone https://github.com/kang8/.tmux.git ~/.tmux
fi

if [[ -f ~/.tmux/.tmux.conf ]]; then
    echo "~/.tmux/.tmux.conf is already link."
else
    ln -sf ~/.tmux/.tmux.conf ~/
fi

if [[ -f ~/.tmux/.tmux.conf.local ]]; then
    echo "~/.tmux/.tmux.conf.local is already link."
else
    ln -sf ~/.tmux/.tmux.conf.local ~/
fi

# set oh-my-tmux remote repo
(cd ~/.tmux && 
    git remote add ohmytmux git@github.com:gpakosz/.tmux.git &> /dev/null)

########
# gpg
########
echo "gpg beging!!!"
if [[ -d ~/.config/kang-gpg ]]; then
    echo "~/.conf/kang-gpg is already installed."
else
    git clone git@github.com:kang8/gpg-key-ring.git ~/.config/kang-gpg

    # TODO: check `gpg -K` is contain? -> if
    (cd kang-gpg && gpg --import sign-sub.gpg)

    echo -ne "trust\n5\ny\nq\n" | gpg --expert --edit-key 9B18672C5BAD8159F5A76234CA67CB5DBBA86E4D
fi

########
# neovim
########
echo "neovim beging!!!"
if [[ -d ~/.config/nvim ]];then
    echo "~/.config/nvim is already installed."
else
    git clone git@github.com:kang8/.vimrc.git ~/.config/nvim
fi
