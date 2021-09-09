current_dir=`dirname $0`

if [[ -n `cat /proc/version | grep -i wsl2` ]]; then
    # echo "It is WSL2"
    . $current_dir/wsl2.zsh
elif [[ -n `cat /proc/version | grep -i arch` ]]; then
    # echo "It is Arch Linux"
    . $current_dir/archlinux.zsh
else
    echo "Can't find Linux distribution!!!"
fi

# HTTP proxy setting
export http_proxy=http://${proxy_ip}:${proxy_port}
export https_proxy=http://${proxy_ip}:${proxy_port}
