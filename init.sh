#!/usr/bin/env bash

echo "hello world"

# 检查系统的版本

# 先检查程序是否安装

# TODO: stow exclude
# stow
echo "stow beging!!!"
for i in `ls -d */`; do
    echo "stow $i"
    stow $i
done

# check ssh key

# ZSH
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

if [[ -d${ZSH}/custom/themes/powerlevel10k  ]]; then
    echo "powerlevel10k is already installed."
else
    echo "Install zsh theme: powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH}/custom/themes/powerlevel10k
fi
