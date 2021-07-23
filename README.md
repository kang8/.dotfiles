# 我的 dotfile 文件

## ibus-daemon

修改完 `ibus-daemon` 中的文件后，使用如下命令重启 ibus

```bash
$ ibus-daemon -drx
```

## 生成 SSH 密钥

```bash
$ ssh-keygen -t ed25519 -C "1115610574@qq.com"
```

## ZSH

### Install oh-my-zsh
```bash
$ sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### ZSH 插件安装
```bash
$ git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
$ git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

### 安装 powerlevel10k for oh-my-zsh
```bash
$ git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```
