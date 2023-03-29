function echo_proxy() {
    echo "use_proxy: $use_proxy"
    echo "http_proxy: $http_proxy"
    echo "https_proxy: $https_proxy"
}

function set_proxy() {
    export http_proxy=http://${proxy_ip}:${proxy_http_port}
    export https_proxy=$http_proxy
    export use_proxy=true
}

function unset_proxy() {
    unset use_proxy
    unset http_proxy
    unset https_proxy
}
