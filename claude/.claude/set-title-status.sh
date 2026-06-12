#!/bin/bash
# set-title-status.sh - Terminal title with Claude Code status
# Usage: echo '<hook_json>' | bash set-title-status.sh <status>
# Statuses: run (⏳)  alert (🔴 + bell)  done (✅)

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
    run)   title="⏳ $base" ;;
    alert) title="🔴 $base" ;;
    done)  title="✅ $base" ;;
    *)     title="● $base" ;;
esac

# Walk up the process tree to find a real controlling TTY. Hook subprocesses
# may be spawned without one, but Claude Code (or its ancestor terminal) has it.
pid=$PPID
target=""
for _ in 1 2 3 4 5 6 7 8; do
    [ -z "$pid" ] || [ "$pid" -le 1 ] && break
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' \n')
    case "$tty" in
        ""|"?"|"??") ;;
        /dev/*) target="$tty"; break ;;
        *)      target="/dev/$tty"; break ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' \n')
done

if [ -n "$target" ]; then
    printf '\033]0;%s\007' "$title" > "$target" 2>/dev/null || true
    # alert: ring the terminal bell so kitty marks the tab (bell_on_tab "🔔")
    # and bounces the Dock icon when unfocused (window_alert_on_bell)
    if [ "$STATUS" = "alert" ]; then
        printf '\a' > "$target" 2>/dev/null || true
    fi
fi
