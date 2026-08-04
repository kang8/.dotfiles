#!/bin/bash

# Wrap text in an OSC 8 hyperlink (Cmd+click in kitty/iTerm2/WezTerm).
# Uses $'...' so real control bytes land in the string — that way the final
# output still goes through a plain `echo`, and no other component risks having
# its backslashes reinterpreted the way `printf %b` would.
osc8_link() {
  local url=$1 text=$2
  if [ -n "$url" ]; then
    printf '%s' $'\033]8;;'"$url"$'\a'"$text"$'\033]8;;\a'
  else
    printf '%s' "$text"
  fi
}

# Cache location for GitLab MR lookups (see the PR/MR section below).
mr_cache_file() {
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  mkdir -p "$dir" 2>/dev/null
  printf '%s/mr-%s' "$dir" "$(printf '%s|%s' "$1" "$2" | cksum | tr -d ' ')"
}

# Background refresh mode: re-invoked detached by the render path below, never
# by Claude Code itself. Resolves the branch's open MR via `glab` (~3s) and
# writes the rendered label to the cache. An empty file means "checked, no MR".
if [ "$1" = "--refresh-mr" ]; then
  repo_dir=$2
  cache=$3
  # mkdir is atomic: it doubles as a lock so concurrent renders spawn one refresh.
  mkdir "$cache.lock" 2>/dev/null || exit 0
  trap 'rmdir "$cache.lock" 2>/dev/null' EXIT

  cd "$repo_dir" 2>/dev/null || exit 0
  mr=$(glab mr view -F json 2>/dev/null)

  label=""
  # `glab mr view` also returns merged/closed MRs for the branch, which would
  # otherwise stick in the status line forever — keep only open ones.
  url=""
  IFS=$'\t' read -r iid draft conflicts project_id url <<<"$(printf '%s' "$mr" |
    jq -r 'select(.state == "opened")
           | [.iid, (.draft // false), (.has_conflicts // false), .project_id, .web_url]
           | @tsv' 2>/dev/null)"

  if [ -n "$iid" ]; then
    # Count actual approvers rather than trusting `.approved`: GitLab reports
    # approved=true vacuously when a project requires zero approvals.
    approvers=0
    if [ -n "$project_id" ]; then
      approvers=$(glab api "projects/$project_id/merge_requests/$iid/approvals" 2>/dev/null |
        jq -r '.approved_by | length' 2>/dev/null)
      [ -n "$approvers" ] || approvers=0
    fi

    if [ "$draft" = "true" ]; then
      label="!$iid •"
    elif [ "$conflicts" = "true" ]; then
      label="!$iid ✗"
    elif [ "$approvers" -gt 0 ] 2>/dev/null; then
      label="!$iid ✓"
    else
      label="!$iid"
    fi
  fi

  # Cache as "label<TAB>url" — the render path must never call glab itself.
  # An empty file still means "checked, no open MR".
  if [ -n "$label" ]; then
    printf '%s\t%s' "$label" "$url" >"$cache.tmp"
  else
    : >"$cache.tmp"
  fi
  mv "$cache.tmp" "$cache"
  exit 0
fi

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

# Extract PR info. Claude Code fills `.pr` by shelling out to `gh pr view`, so
# it only ever populates for GitHub remotes — GitLab is handled separately below.
pr_number=$(echo "$input" | jq -r '.pr.number // empty')
pr_review_state=$(echo "$input" | jq -r '.pr.review_state // empty')
repo_host=$(echo "$input" | jq -r '.workspace.repo.host // empty')

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

# PR / MR indicator. Symbols: ✓ approved, ✗ blocked, • draft, bare = open.
# GitHub uses "#123", GitLab "!123" — each platform's own shorthand.
pr_label=""
pr_url=""
if [ -n "$pr_number" ]; then
  case "$pr_review_state" in
    approved) pr_label="#$pr_number ✓" ;;
    changes_requested) pr_label="#$pr_number ✗" ;;
    draft) pr_label="#$pr_number •" ;;
    *) pr_label="#$pr_number" ;;
  esac
  pr_url=$(echo "$input" | jq -r '.pr.url // empty')
elif [ -n "$git_branch" ] && command -v glab >/dev/null 2>&1; then
  case "$repo_host" in
    *gitlab*)
      # `glab mr view` takes ~3s — far past the render budget. Serve the cached
      # label immediately and refresh out-of-band (stale-while-revalidate).
      mr_cache=$(mr_cache_file "$cwd" "$git_branch")
      if [ -f "$mr_cache" ]; then
        IFS=$'\t' read -r pr_label pr_url <"$mr_cache"
      fi
      if [ ! -f "$mr_cache" ] || [ -n "$(find "$mr_cache" -mmin +2 2>/dev/null)" ]; then
        # Via `bash`, not a direct exec: the script ships mode 644 (settings.json
        # also invokes it as `bash ~/.claude/statusline-command.sh`).
        bash "${BASH_SOURCE[0]}" --refresh-mr "$cwd" "$mr_cache" >/dev/null 2>&1 &
      fi
      ;;
  esac
fi

if [ -n "$pr_label" ]; then
  components+=("$(osc8_link "$pr_url" "$pr_label")")
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
