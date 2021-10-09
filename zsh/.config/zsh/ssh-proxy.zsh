rm -rf ~/.ssh/config

if ! is_access_google;then
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
fi

cat << EOF >> ~/.ssh/config
Host kang
    HostName 121.36.19.76
    User yikang
EOF
