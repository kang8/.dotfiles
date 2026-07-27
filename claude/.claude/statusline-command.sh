#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
session_name=$(echo "$input" | jq -r '.session_name // empty')
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
context_used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
context_total_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
context_used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
# Reasoning effort: absent when the model does not support the effort parameter
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Get git branch if in a git repo (skip optional locks for performance)
git_branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build status line components
components=()

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

# Current directory (fish-style: truncate parent dirs to 1 char)
short_cwd=$(echo "$cwd" | sed -E "s|$HOME|~|" | sed -E 's|/([^/])[^//]*/|\1/|g')
components+=("$short_cwd")

# Git branch
if [ -n "$git_branch" ]; then
  components+=("$git_branch")
fi

# Vim mode indicator
if [ -n "$vim_mode" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    components+=("V")
  fi
fi

# Output style (if not default)
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  components+=("[$output_style]")
fi

# Context size: show as "usedK/totalK (used%)", e.g. "50K/200K (25%)".
# Windows of 1M or more render as "M" so extended-context models don't show "1000K".
if [ -n "$context_used_tokens" ] && [ -n "$context_total_tokens" ] && [ -n "$context_used_pct" ]; then
  used_k=$((context_used_tokens / 1000))
  if [ "$context_total_tokens" -ge 1000000 ]; then
    total_fmt="$((context_total_tokens / 1000000))M"
  else
    total_fmt="$((context_total_tokens / 1000))K"
  fi
  components+=("$(printf "%dK/%s (%.0f%%)" "$used_k" "$total_fmt" "$context_used_pct")")
fi

# Session cost so far (USD), from .cost.total_cost_usd
if [ -n "$cost_usd" ]; then
  components+=("$(printf '$%.2f' "$cost_usd")")
fi

# Model name (shortened), with reasoning effort if the model supports it
model_short=$(echo "$model" | sed 's/Claude //' | sed 's/ (.*)//')
if [ -n "$effort" ]; then
  components+=("$model_short $effort")
else
  components+=("$model_short")
fi

# Current session id (.session_id)
if [ -n "$session_id" ]; then
  components+=("$session_id")
fi

# Join components with space separator
result=""
for component in "${components[@]}"; do
  if [ -z "$result" ]; then
    result="$component"
  else
    result="$result $component"
  fi
done

echo "$result"
