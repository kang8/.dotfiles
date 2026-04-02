#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
session_name=$(echo "$input" | jq -r '.session_name // empty')
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')

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

# Context remaining
if [ -n "$context_remaining" ]; then
  components+=("$(printf "%.0f%%" "$context_remaining")")
fi

# Model name (shortened)
model_short=$(echo "$model" | sed 's/Claude //' | sed 's/ (.*)//')
components+=("$model_short")

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
