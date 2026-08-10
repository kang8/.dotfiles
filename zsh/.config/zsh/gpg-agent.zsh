# Inlined oh-my-zsh `gpg-agent` plugin: its `gpgconf --list-options` probe costs ~380ms
export GPG_TTY=$TTY

function _gpg-agent_update-tty_preexec {
  gpg-connect-agent updatestartuptty /bye &>/dev/null
}
autoload -U add-zsh-hook
add-zsh-hook preexec _gpg-agent_update-tty_preexec

# If enable-ssh-support is set, gpg-agent replaces ssh-agent.
() {
  local conf=${GNUPGHOME:-$HOME/.gnupg}/gpg-agent.conf line
  [[ -r $conf ]] || return 0
  while read -r line; do
    [[ $line == enable-ssh-support* ]] || continue
    unset SSH_AGENT_PID
    if [[ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]]; then
      export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
    fi
    return 0
  done < $conf
}
