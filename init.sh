#!/usr/bin/env bash
set -Eeuo pipefail

# setup
mkdir -p ~/.config/lazygit || true
mkdir -p ~/.local/bin || true
cp .env.example .env

########
# stow
########
echo "stow beginning!!!"

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

install_zsh_plugin() {
    local name=$1 repo=$2
    local dest="${ZSH}/custom/plugins/${name}"
    if [[ -d "$dest" ]]; then
        echo "${name} is already installed."
    else
        echo "Install zsh plug: ${name}..."
        git clone --depth=1 "$repo" "$dest"
    fi
}

install_zsh_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
install_zsh_plugin fzf-tab https://github.com/Aloxaf/fzf-tab.git
install_zsh_plugin z.lua https://github.com/skywind3000/z.lua.git
install_zsh_plugin zsh-autopair https://github.com/hlissner/zsh-autopair
install_zsh_plugin you-should-use https://github.com/MichaelAquilina/zsh-you-should-use.git
install_zsh_plugin fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting.git
install_zsh_plugin zsh-completions https://github.com/zsh-users/zsh-completions.git
install_zsh_plugin jq https://github.com/reegnz/jq-zsh-plugin.git

######## neovim ########
echo "\n"
echo "neovim beginning!!!"
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
echo "gpg beginning!!!"
echo "\n"

# create ~/.gnupg/
gpg -k

if [[ -d ~/kang/gpg-key-ring ]]; then
    echo "~/kang/gpg-key-ring is already installed."
else
    git clone --depth=1 git@github.com:kang8/gpg-key-ring.git ~/kang/gpg-key-ring
fi

stow gnupg

# Create symlink for pinentry-mac to support both Apple Silicon and Intel
ln -sf "$(brew --prefix pinentry-mac)/bin/pinentry-mac" ~/.local/bin/pinentry-mac

########
# MacOS setting
########
# Disable the .DS file creation
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show the path bar in the Finder
defaults write com.apple.finder "ShowPathbar" -bool "true" && killall Finder

# Show hidden files in the Finder
defaults write com.apple.finder "AppleShowAllFiles" -bool "true" && killall Finder

########
# Miscellaneous items
########

# Make these files immutable to prevent external programs from modifying them
chflags uimmutable ~/.zprofile
chflags -h uimmutable ~/.zshrc # Use `-h` flag for symbolic links to change the link's flags rather than the target file
# `chflags nouimmutable ~/.zprofile` If you want to modify them
