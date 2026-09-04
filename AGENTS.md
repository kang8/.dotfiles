# AGENTS.md

`CLAUDE.md` is a git-ignored one-line import of this file, so project
instructions belong here.

## Layout

Every top-level directory is a GNU Stow package laid out as
`<package>/<path under $HOME>` — `zsh/.config/zsh/.zshrc` stows to
`~/.config/zsh/.zshrc`. The live config in `~` is a symlink into this repo, so
editing the file here changes the running setup immediately.

## Formatting

`make format` runs as a pre-commit hook and reformats the whole repo, including
the order of `Brewfile`, `agents/.agents/Skillfile`, and
`claude/.claude/settings.json`. Leave the ordering to it.

## Read before you edit

- Anything cron or launchd starts, or a script reaching a brew-installed binary
  — [`docs/agents/homebrew-paths.md`](docs/agents/homebrew-paths.md): bare
  `PATH`, `$HOMEBREW_PREFIX`, and the GNU-versus-BSD coreutils trap.
- zsh startup: the `plugins=()` list, `.zshrc` ordering, init caching —
  [`docs/agents/zsh-startup.md`](docs/agents/zsh-startup.md): how to measure it,
  which keybindings to re-check, which slowdowns are expected.
