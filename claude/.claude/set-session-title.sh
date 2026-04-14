#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

[ -z "$session_id" ] && exit 0

index="$(dirname "$transcript_path")/sessions-index.json"
title=""

# Try session summary from index
if [ -f "$index" ]; then
    title=$(jq -r --arg id "$session_id" \
        '.entries[] | select(.sessionId == $id) | .summary // empty' "$index")
fi

# Fallback: first user prompt (truncated)
if [ -z "$title" ] && [ -f "$transcript_path" ]; then
    title=$(head -10 "$transcript_path" | \
        jq -r 'select(.type == "user") | .message.content // empty' 2>/dev/null | \
        head -1 | cut -c1-60)
fi

prefix=$(basename "$PWD")
[ -n "$title" ] && title="[$prefix] $title" || title="$prefix"
printf '\033]0;%s\007' "$title" > /dev/tty
