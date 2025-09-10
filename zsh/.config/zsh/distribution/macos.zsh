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
[[ -d $HOMEBREW_PREFIX/opt/grep/libexec/gnubin ]] && export PATH="$HOMEBREW_PREFIX/opt/grep/libexec/gnubin:$PATH"

# brew install findutils, will install `find`, `xargs`, `locate`
[[ -d $HOMEBREW_PREFIX/opt/findutils/libexec/gnubin ]] && export PATH="$HOMEBREW_PREFIX/opt/findutils/libexec/gnubin:$PATH"

# brew install coreutils, will install `dd`, `ls`, 'mv' and so on...
[[ -d $HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin ]] && export PATH="$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin:$PATH"

# brew install coreutils, will install `sed`
[[ -d $HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin ]] && export PATH="$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin:$PATH"

# brew install diffutils, will install `diff`
[[ -d $HOMEBREW_PREFIX/opt/diffutils/bin ]] && export PATH="$HOMEBREW_PREFIX/opt/diffutils/bin:$PATH"

# brew install gnu-tar, will install `tar`
[[ -d $HOMEBREW_PREFIX/opt/gnu-tar/libexec/gnubin ]] && export PATH="$HOMEBREW_PREFIX/opt/gnu-tar/libexec/gnubin:$PATH"
