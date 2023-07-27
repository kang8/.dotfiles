#!/usr/bin/env bash
set -Eeuo pipefail

# setup
mkdir -p ~/.config/lazygit || true
mkdir -p ~/.local/bin || true
cp .env.example .env

########
# stow
########
echo "stow beging!!!"

stow_exclude=('~/' 'ibus-rime/' 'sublime-text/' 'wakatime/' 'gnupg/')

for i in `ls -d */`; do
    printf "%s\n" "${stow_exclude[@]}" | grep -x -q "$i" ||
        ( echo "  stow $i" && stow $i )
done

zsh ~/.zshrc

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

########
# neovim
########
echo "neovim beging!!!"
if [[ -d ~/.config/nvim ]];then
    echo "~/.config/nvim is already installed."
else
    git clone --depth=1 git@github.com:kang8/.vimrc.git ~/.config/nvim
fi

########
# gpg
########
echo "gpg beging!!!"

# create ~/.gnupg/
gpg -k

if [[ -d ~/.config/kang-gpg ]]; then
    echo "~/.config/kang-gpg is already installed."
else
    git clone --depth=1 git@github.com:kang8/gpg-key-ring.git ~/.config/kang-gpg
fi

stow gnupg

if [[ -z `gpg -K` ]]; then
    (cd ~/.config/kang-gpg && gpg --import sign-sub.gpg)

    expect <(printf "\
    spawn gpg --expert --edit-key 9B18672C5BAD8159F5A76234CA67CB5DBBA86E4D
    send \"trust\r5\ry\rq\r\"
    interact
    ")
fi

# setdown

( cd ~/.dotfiles && git remote set-url origin git@github.com:kang8/.dotfiles.git )
