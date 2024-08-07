# export custom variable
export is_mac=true

export proxy_ip=127.0.0.1
export proxy_http_port=20171

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

# use GUN software
# Add the `g` prefix when search manual: use `man ggrep` instand of `man grep`

# brew install grep
[[ -d /opt/homebrew/opt/grep/libexec/gnubin ]] && export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"

# brew install findutils, will install `find`, `xargs`, `locate`
[[ -d /opt/homebrew/opt/findutils/libexec/gnubin ]] && export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"

# brew install coreutils, will install `dd`, `ls`, 'mv' and so on...
[[ -d /opt/homebrew/opt/coreutils/libexec/gnubin ]] && export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

# brew install coreutils, will install `sed`
[[ -d /opt/homebrew/opt/gnu-sed/libexec/gnubin ]] && export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"

# brew install diffutils, will install `diff`
[[ -d /opt/homebrew/opt/diffutils/bin ]] && export PATH="/opt/homebrew/opt/diffutils/bin:$PATH"

# brew install gnu-tar, will install `tar`
[[ -d /opt/homebrew/opt/gnu-tar/libexec/gnubin ]] && export PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"
