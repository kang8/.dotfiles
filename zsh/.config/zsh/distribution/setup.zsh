current_dir=`dirname $0`

if [[ -n `type sw_vers &> /dev/null && exec sw_vers` ]]; then
    # echo "It is macOS"
    . $current_dir/macos.zsh
elif [[ -n `cat /proc/version | grep -i wsl2` ]]; then
    # echo "It is WSL2"
    . $current_dir/wsl2.zsh
elif [[ -n `cat /proc/version | grep -i arch` ]]; then
    # echo "It is Arch Linux"
    . $current_dir/archlinux.zsh
else
    echo "Can't find Linux distribution!!!"
fi

# If computer used to work, do not to set proxy
if [ $is_work ]; then
    return
fi

# HTTP proxy setting
if is_access_google; then
    unset http_proxy
    unset https_proxy
else
    set_proxy
fi
