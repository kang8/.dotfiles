# Kang's dotfiles

## 1. clone this repo

```bash
git clone --recurse-submodules --depth=1 https://github.com/kang8/.dotfiles.git
```

## 2. Run init.sh, follow the prompts to complete the setup.

```bash
./init.sh
```
It will setup:

* [git](https://github.com/kang8/.dotfiles/blob/master/git/.gitconfig)
* [zsh](https://github.com/kang8/.dotfiles/blob/master/zsh/.config/zsh/.zshrc)
* [tmux](https://github.com/kang8/.dotfiles/blob/master/init.sh#L84-L108)
* [neovim](https://github.com/kang8/.dotfiles/blob/master/init.sh#L110-L118)
* [gpg](gpg)
* [ssh](https://github.com/kang8/.dotfiles/blob/master/zsh/.config/zsh/ssh-proxy.zsh)
* [IDEAVIM](https://github.com/kang8/.dotfiles/blob/master/IDEA/.ideavimrc)
* [alacritty](tmuxinator)
* [ranger](https://github.com/kang8/.dotfiles/tree/master/ranger/.config/ranger)
* [tmuxinator](https://github.com/kang8/.dotfiles/tree/master/tmux/.config/tmuxinator)

It will install:
* https://github.com/ohmyzsh/ohmyzsh
* https://github.com/zsh-users/zsh-syntax-highlighting
* https://github.com/zsh-users/zsh-autosuggestions
* https://github.com/Aloxaf/fzf-tab
* https://github.com/romkatv/powerlevel10k

Need manual setup:

```bash
stow ibus-rime
stow sublime-text
stow wakatime
stow gnupg
```
