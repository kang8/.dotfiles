# proxy
export proxy_ip=127.0.0.1
export proxy_http_port=1087
export proxy_socks5_port=1080

# export custom variable
export is_mac=true

function manp {
    local page
    if (( $# > 0 )); then
        for page in "$@"; do
            man -t "$page" | open -f -a Preview
        done
    else
        print 'What manual page do you want?' >&2
    fi
}
