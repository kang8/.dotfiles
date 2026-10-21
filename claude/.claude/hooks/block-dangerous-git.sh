#!/usr/bin/env bash
# PreToolUse(Bash): refuse destructive git commands, including prefixed forms
# like `git -C dir …`, `git -c k=v …`, `cd x && git …`, `sh -c "git …"`.
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
dir=$(jq -r '.cwd // empty' <<<"$input")

# git, optionally followed by global options, then whitespace before the subcommand.
git='(^|[^[:alnum:]_./-])git([[:space:]]+(-C|-c|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[[:alnum:]-]+(=[^[:space:]]+)?)*[[:space:]]+'
# Arguments of the same command: stop at shell separators.
args='([[:space:]]+[^;&|]*)?'
end='([[:space:]]|$|[\"'\'';&|)])'

block() {
  echo "BLOCKED: this destructive git command (push, reset --hard, clean -f, branch -D, checkout ., restore .) is disabled for Claude Code.$1 The user has prevented you from doing this; stop and tell them what you wanted to run." >&2
  exit 2
}

patterns=(
  "push$end"
  "reset$args[[:space:]]--hard$end"
  "clean$args[[:space:]](-[[:alnum:]]*f[[:alnum:]]*|--force)$end"
  "branch$args[[:space:]]-[[:alnum:]]*D[[:alnum:]]*$end"
)

for p in "${patterns[@]}"; do
  printf '%s' "$cmd" | grep -Eq "$git$p" && block
done

# Absolute path for $1 relative to $dir; fails when it can't be known statically.
resolve() {
  local p=${1//[\"\']/}
  case $p in
    '' | - | *'$'* | *'`'*) return 1 ;;
    '~' | '~/'*) p=$HOME${p#\~} ;;
    /*) ;;
    *) [ -n "$dir" ] || return 1; p=$dir/$p ;;
  esac
  printf '%s' "$p"
}

# No staged, unstaged, or untracked changes, so overwriting the tree loses nothing.
clean() {
  [ -n "$1" ] && [ -z "$(GIT_OPTIONAL_LOCKS=0 git -C "$1" status --porcelain -unormal 2>/dev/null || echo dirty)" ]
}

# `checkout .`/`restore .` is allowed for conflict resolution (--ours/--theirs,
# --staged without --worktree), or when the target worktree is clean.
# Checked per command so `git restore --theirs . && git checkout .` still blocks.
has() { printf '%s' "$seg" | grep -Eq -- "$1"; }
while IFS= read -r seg; do
  # Follow plain `cd DIR`; any other cd (subshell, sh -c, pushd) loses track.
  if has '^[[:space:]]*cd[[:space:]]+[^[:space:]]+[[:space:]]*$'; then
    dir=$(resolve "$(awk '{print $2}' <<<"$seg")") || dir=
    continue
  fi
  has '(^|[^[:alnum:]_.-])(cd|pushd|popd)([[:space:]]|$)' && dir=

  has "$git(checkout|restore)$args[[:space:]]\.$end" || continue
  has '[[:space:]]--(ours|theirs)([[:space:]]|$)' && continue
  has '[[:space:]](--staged|-S)([[:space:]]|$)' &&
    ! has '[[:space:]](--worktree|-[[:alnum:]]*W[[:alnum:]]*)([[:space:]]|$)' && continue

  repo=$dir
  if has '[[:space:]](--git-dir|--work-tree)'; then
    repo=
  elif has '[[:space:]]-C[[:space:]]'; then
    c=$(grep -Eo -- '[[:space:]]-C[[:space:]]+[^[:space:]]+' <<<"$seg")
    [ "$(wc -l <<<"$c")" -eq 1 ] && repo=$(resolve "$(awk '{print $2}' <<<"$c")") || repo=
  fi
  clean "$repo" && continue
  block " checkout/restore . is allowed only in a worktree with no uncommitted or untracked changes."
done < <(printf '%s\n' "$cmd" | tr ';&|' '\n')
exit 0
