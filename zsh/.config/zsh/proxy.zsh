function echo_proxy() {
    echo "use_proxy: $use_proxy"
    echo "http_proxy: $http_proxy"
    echo "https_proxy: $https_proxy"
}

function set_proxy() {
    export http_proxy=http://${proxy_ip}:${proxy_http_port}
    export https_proxy=$http_proxy
    export use_proxy=true
    set_ssh_proxy
    set_common_ssh_proxy
}

function unset_proxy() {
    unset use_proxy
    unset http_proxy
    unset https_proxy
    # aother way to clean file contetn
    cat /dev/null > ~/.ssh/config
    set_common_ssh_proxy
}
