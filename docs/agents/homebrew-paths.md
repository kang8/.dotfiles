# Homebrew paths

Homebrew's prefix is `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel.
The repo is written for both, so never hardcode either one — reach a
brew-installed program through `$HOMEBREW_PREFIX` or a bare command name on
`PATH`. Run `brew --prefix` to learn what the machine in front of you has, every
time; an earlier note goes stale the moment the repo lands on another machine.

launchd (GUI apps, agents) and cron start programs with a bare `PATH` —
launchd's is `/usr/bin:/bin:/usr/sbin:/sbin` — and none of zsh's exports, so
those configs put the prefix on `PATH` themselves by sourcing
`bin/.local/bin/brew-shellenv`, which probes both. `zsh/.zshrc` probes inline
because it runs before anything is on `PATH`; it is also unreachable from cron,
since zsh reads `.zshrc` only when interactive.

A brew-installed GNU coreutils shadows the BSD tools in an interactive shell, so
GNU-only syntax (`mkdir --parents`, `date -d`) works when you test it by hand
and fails under cron or launchd, where only `/bin` and `/usr/bin` are visible.
Stick to the portable flags in anything those start.
