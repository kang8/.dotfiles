# proxy
export proxy_ip=`cat /etc/resolv.conf | grep nameserver | awk '{print $2}'`
export proxy_port=10809

# WSL GPG setting
export GPG_TTY=$(tty)

# Linuxbrew
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    export FZF_BASE=/home/linuxbrew/.linuxbrew/Cellar/fzf/0.27.2/
fi
