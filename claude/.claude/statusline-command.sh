#!/bin/bash
# shellcheck disable=SC2154 # the eval below assigns the JSON fields

# Parse every field in one jq call; @sh quotes each value so eval is safe even
# when a field is empty or contains spaces
eval "$(jq -r '@sh "
session_name=\(.session_name // "")
model_short=\(.model.display_name // "" | sub("^Claude "; "") | sub(" \\(.*\\)$"; ""))
cwd=\(.workspace.current_dir // "")
output_style=\(.output_style.name // "")
context_used_tokens=\(.context_window.total_input_tokens // "")
context_total_tokens=\(.context_window.context_window_size // "")
vim_mode=\(.vim.mode // "")
agent_name=\(.agent.name // "")
worktree_name=\(.worktree.name // "")
session_id=\(.session_id // "")
cost_usd=\(.cost.total_cost_usd // "")
effort=\(.effort.level // "")
"')"
# effort is empty when the model does not support the effort parameter

# SendMessage address of this session: absent from the status line JSON, so read
# it from the per-process registry Claude Code keeps in ~/.claude/sessions
msg_name=""
if [ -n "$session_id" ]; then
  msg_name=$(jq -r --arg id "$session_id" 'select(.sessionId == $id) | .name // empty' "$HOME"/.claude/sessions/*.json 2>/dev/null | head -1)
fi

# Empty outside a git repo; detached HEAD falls back to the short hash
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

# PR/MR is deliberately absent here: since v2.1.234 Claude Code renders its own
# footer badge for both GitHub PRs and GitLab MRs (`prStatusFooterEnabled`, on by
# default), so repeating `.pr` in the status line would just double it up.

# Build status line components
components=()

# Context size: show as "usedK/totalK", e.g. "50K/200K".
# Windows of 1M or more render as "M" so extended-context models don't show "1000K".
if [ -n "$context_used_tokens" ] && [ -n "$context_total_tokens" ]; then
  used_k=$((context_used_tokens / 1000))
  if [ "$context_total_tokens" -ge 1000000 ]; then
    total_fmt="$((context_total_tokens / 1000000))M"
  else
    total_fmt="$((context_total_tokens / 1000))K"
  fi
  components+=("${used_k}K/$total_fmt")
fi

# Message name (skipped when /rename already made it the session name)
if [ -n "$msg_name" ] && [ "$msg_name" != "$session_name" ]; then
  components+=("$msg_name")
fi

# Current session id (.session_id)
if [ -n "$session_id" ]; then
  components+=("$session_id")
fi

# Session name (if set via /rename)
if [ -n "$session_name" ]; then
  components+=("$session_name")
fi

# Agent indicator
if [ -n "$agent_name" ]; then
  components+=("[agent:$agent_name]")
fi

# Worktree indicator
if [ -n "$worktree_name" ]; then
  components+=("[wt:$worktree_name]")
fi

# Current directory, fish-style: every segment but the last shortened to one
# character (two for dot-directories), e.g. ~/.dotfiles/claude/.claude -> ~/.d/c/.claude
short_cwd=$cwd
case $cwd in
  "$HOME" | "$HOME"/*) short_cwd="~${cwd#"$HOME"}" ;;
esac
IFS=/ read -ra parts <<<"$short_cwd"
last=$((${#parts[@]} - 1))
for i in "${!parts[@]}"; do
  part=${parts[i]}
  if [ "$i" -lt "$last" ] && [ "$part" != "~" ]; then
    if [ "${part:0:1}" = "." ]; then
      parts[i]=${part:0:2}
    else
      parts[i]=${part:0:1}
    fi
  fi
done
short_cwd=$(IFS=/ && echo "${parts[*]}")
components+=("${short_cwd:-/}")

# Git branch
if [ -n "$git_branch" ]; then
  components+=("$git_branch")
fi

# Vim mode indicator
if [ "$vim_mode" = "NORMAL" ]; then
  components+=("V")
fi

# Output style (if not default)
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  components+=("[$output_style]")
fi

# Session cost so far (USD), from .cost.total_cost_usd
if [ -n "$cost_usd" ]; then
  components+=("$(printf '$%.2f' "$cost_usd")")
fi

# Model name (shortened), with reasoning effort if the model supports it
components+=("$model_short${effort:+ $effort}")

IFS=' '
echo "${components[*]}"
