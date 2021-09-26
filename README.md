# My dotfiles

## Font, JetBrainMono Medium

intall for [this](https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/JetBrainsMono/Ligatures/Medium/complete/JetBrains%20Mono%20Medium%20Nerd%20Font%20Complete%20Mono.ttf).

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
$ sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### install zsh plug
```bash
$ git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
$ git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

### install powerlevel10k for oh-my-zsh
```bash
$ git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```
