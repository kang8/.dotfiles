# Kang's dotfiles

## 1. Generating a new SSH key and adding it to the ssh-agent

```bash
ssh-keygen -a 256 -t ed25519 -C "comment"

/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

## 2. clone this repo

```bash
git clone --recurse-submodules --depth=1 https://github.com/kang8/.dotfiles.git
```

## 3. Install Homebrew first, and use `brew bundle` to install all dependencies from the [Brewfile](./Brewfile)

```bash
# From: https://brew.sh/
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Setup brew
eval "$(/opt/homebrew/bin/brew shellenv)"

brew bundle
```

## 4. Run init.sh, follow the prompts to complete the setup.

```bash
./init.sh
```

It will setup:

- [git](https://github.com/kang8/.dotfiles/blob/master/git/.gitconfig)
- [zsh](https://github.com/kang8/.dotfiles/blob/master/zsh/.config/zsh/.zshrc)
- [neovim](https://github.com/kang8/.dotfiles/blob/master/init.sh#L110-L118)
- [gpg](gpg)
- [ssh](https://github.com/kang8/.dotfiles/blob/master/zsh/.config/zsh/ssh-proxy.zsh)
- [IDEAVIM](https://github.com/kang8/.dotfiles/blob/master/IDEA/.ideavimrc)
- [ranger](https://github.com/kang8/.dotfiles/tree/master/ranger/.config/ranger)

It will install:

- https://github.com/ohmyzsh/ohmyzsh
- https://github.com/zsh-users/zsh-syntax-highlighting
- https://github.com/zsh-users/zsh-autosuggestions
- https://github.com/Aloxaf/fzf-tab

Need manual setup:

```bash
stow ibus-rime
stow sublime-text
stow wakatime
stow gnupg
```

## 4. Cron job

```bash
# Manual set crontab path:
crontab ~/.dotfiles/crontab
# Check setup
crontab -l
```
