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

GNU coreutils, findutils, grep, sed and tar are on `PATH` only under a `g`
prefix (`gsed`, `gdate`, `gtimeout`), so a bare `sed` or `date` is the BSD one
in an interactive shell and under cron alike. GNU `diff` is the exception:
diffutils links unprefixed into `$HOMEBREW_PREFIX/bin` and shadows
`/usr/bin/diff` wherever brew is on `PATH`.
