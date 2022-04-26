rm -rf ~/.ssh/config

function set_ssh_proxy() {
    if [ -n "${proxy_socks5_port}" ];then
cat << EOF > ~/.ssh/config
Host gist.github.com github.com
    ProxyCommand nc -v -x ${proxy_ip}:${proxy_socks5_port} %h %p
EOF
    else
cat << EOF > ~/.ssh/config
Host gist.github.com github.com
    ProxyCommand nc -v -X connect -x ${proxy_ip}:${proxy_http_port} %h %p
EOF
    fi
}

function set_common_ssh_proxy() {
cat << EOF >> ~/.ssh/config
Host zhang
    HostName 47.101.197.97
    User root
EOF
}

set_common_ssh_proxy
