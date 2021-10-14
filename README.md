# My dotfiles

## clone repo

```bahs
$ git clone --recurse-submodules https://github.com/kang8/.dotfiles.git
```

## Font, JetBrainMono Medium

install for [this link](https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/JetBrainsMono/Ligatures/Medium/complete/JetBrains%20Mono%20Medium%20Nerd%20Font%20Complete%20Mono.ttf).

## ibus-daemon

refresh ibus-daemon

```bash
$ ibus-daemon -drx
```

## generate SSH Key

```bash
$ ssh-keygen -t ed25519 -C "comment"
```

## ZSH

### Install oh-my-zsh
```bash
$ git clone --depth=1 git@github.com:ohmyzsh/ohmyzsh.git ~/.config/zsh/.oh-my-zsh
```

### install zsh plug
```bash
$ git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH}/custom/plugins/zsh-syntax-highlighting
$ git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH}/custom/plugins/zsh-autosuggestions
```

### install powerlevel10k for oh-my-zsh
```bash
$ git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH}/custom/themes/powerlevel10k
```
