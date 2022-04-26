current_dir=`dirname $0`

if [[ -n `type sw_vers &> /dev/null && exec sw_vers` ]]; then
    . $current_dir/macos.zsh
elif [[ -n `cat /proc/version | grep -i wsl2` ]]; then
    . $current_dir/wsl2.zsh
elif [[ -n `cat /proc/version | grep -i arch` ]]; then
    . $current_dir/archlinux.zsh
else
    echo "Can't find Linux distribution!!!"
fi
