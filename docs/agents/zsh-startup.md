# zsh startup

`zsh/.config/zsh/.oh-my-zsh` is gitignored and reinstalled by `init.sh`, so an
edit inside it is gone on the next machine, and the updater can overwrite it
before that. Keep changes in a tracked file and override oh-my-zsh from outside
— `zsh/.config/zsh/omz-speedups.zsh` shows three ways to do it.

A warm `zsh -i -c exit` takes ~150ms. Measure either side of a change: the
`zprof` lines sit commented at the top of `zsh/.zshrc`, and wall clock comes
from `for i in {1..5}; do /usr/bin/time zsh -i -c exit; done`. zprof accounts
only for functions, so time the top-level `eval "$(tool init …)"` subprocesses
separately; they are invisible to it. Machine load skews these numbers, so check
`uptime` before believing a slow result.

Pulling an init out of `plugins=()` changes when it binds keys: `fzf --zsh`
takes TAB from fzf-tab, which is why `.zshrc` calls `enable-fzf-tab` afterwards.
After reordering plugins, confirm `^I` is `fzf-tab-complete`, `^R` is
`_atuin_search_widget`, `^T` is `fzf-file-widget`, and `^[c` is `fzf-cd-widget`.

Two slowdowns are expected rather than regressions. Removing a plugin changes
`$fpath`, so oh-my-zsh discards the zcompdump and the next startup rebuilds it.
A shell that cannot write `~/.cache/zsh` falls back to running each init command
for real. Init output is cached there and keyed on the binary's mtime; run
`evalcache-clear` if a tool behaves like an older version.
