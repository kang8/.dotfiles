rm -rf ~/.ssh/config

if ! is_access_google;then
cat << EOF > ~/.ssh/config
Host gist.github.com github.com
    ProxyCommand nc -v -X connect -x ${proxy_ip}:${proxy_port} %h %p
EOF
fi

cat << EOF >> ~/.ssh/config
Host kang
    HostName 121.36.19.76
    User yikang
EOF
