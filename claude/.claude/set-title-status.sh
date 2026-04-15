#!/bin/bash
# set-title-status.sh - Terminal title with Claude Code status
# Usage: echo '<hook_json>' | bash set-title-status.sh <status>
# Statuses: run (⏳)  alert (👀)  done (✅)

STATUS="${1:-done}"
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

[ -z "$session_id" ] && exit 0

# Resolve session topic from index or first user message
index="$(dirname "$transcript_path")/sessions-index.json"
topic=""
if [ -f "$index" ]; then
    topic=$(jq -r --arg id "$session_id" \
        '.entries[] | select(.sessionId == $id) | .summary // empty' "$index")
fi
if [ -z "$topic" ] && [ -f "$transcript_path" ]; then
    topic=$(head -10 "$transcript_path" | \
        jq -r 'select(.type == "user") | .message.content // empty' 2>/dev/null | \
        head -1 | cut -c1-60)
fi

dir=$(basename "$PWD")
[ -n "$topic" ] && base="$dir: $topic" || base="$dir"

case "$STATUS" in
    run)   icon="⏳" ;;
    alert) icon="👀" ;;
    done)  icon="✅" ;;
    *)     icon="●"  ;;
esac

printf '\033]0;%s %s\007' "$icon" "$base" > /dev/tty
