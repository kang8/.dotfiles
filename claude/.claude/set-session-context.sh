#!/bin/bash
# set-session-context.sh - Publish "dir: topic" of a Claude Code session to kitty
#
# Usage: echo '<hook_json>' | bash set-session-context.sh <action>
#
# Actions:
#   set      publish the context  (SessionStart, UserPromptSubmit)
#   release  clear the context    (SessionEnd)
#
# The context goes into the kitty user variable `claude_context`
# (OSC 1337 SetUserVar), which kitty/.config/kitty/tab_bar.py shows as the tab
# title. The window title stays with Claude Code, and the working/blocked/done
# status comes from Claude Code itself over OSC 7501. Both need
# CLAUDE_CODE_DISABLE_TERMINAL_TITLE unset.

set -eu

ACTION="${1:-set}"
input=$(cat)

state_dir="${TMPDIR:-/tmp}/claude-context"

# ---------------------------------------------------------------------------
# Parse payload (single jq pass)
# ---------------------------------------------------------------------------

# Strip every control character, not just \n\r\t. A prompt containing a raw
# ESC or BEL would otherwise terminate or inject into the OSC string below.
# [[:cntrl:]] is Unicode Cc under Oniguruma, so it covers C0, DEL *and* C1
# (0x9b is CSI). Do not use "\\u0000-\\u001f" here: jq's regex engine does not
# understand \u escapes and silently mangles ordinary text instead.
# Slicing is by Unicode codepoint, so CJK titles never get cut mid-character.
read -r -d '' jq_clean <<'JQ' || true
def clean:
  (. // "")
  | gsub("[[:cntrl:]]"; " ")
  | gsub(" {2,}"; " ")
  | sub("^ +"; "") | sub(" +$"; "")
  | .[0:60];
JQ

fields=$(printf '%s' "$input" | jq -r "$jq_clean"'
    [ (.session_id // ""),
      (.agent_id // ""),
      (.hook_event_name // ""),
      (.cwd // ""),
      (.transcript_path // ""),
      (.prompt | clean)
    ] | join("\u001f")' 2>/dev/null) || fields=""

# Unit separator, not tab: tab is an IFS *whitespace* character, so bash would
# collapse runs of empty fields and shift every value left. Payload strings are
# run through `clean` (or are UUIDs/paths), so US can never appear in content.
IFS=$'\037' read -r session_id agent_id hook_event cwd transcript_path payload_prompt \
    <<< "${fields:-}" || true

[ -n "${session_id:-}" ] || exit 0
[ -z "${agent_id:-}" ] || exit 0

# ---------------------------------------------------------------------------
# Load cached session state
# ---------------------------------------------------------------------------

state_file="$state_dir/$session_id"
c_tty="" c_dir="" c_topic=""
if [ -r "$state_file" ]; then
    {
        IFS= read -r c_tty
        IFS= read -r c_dir
        IFS= read -r c_topic
    } < "$state_file" 2>/dev/null || true
fi

if [ "$ACTION" = "release" ]; then
    rm -f "$state_file" 2>/dev/null || true
    # SetUserVar without "=value" deletes the variable
    [ -n "$c_tty" ] && [ -w "$c_tty" ] && \
        printf '\033]1337;SetUserVar=claude_context\007' > "$c_tty" 2>/dev/null || true
    exit 0
fi

# ---------------------------------------------------------------------------
# Resolve topic (only when it can actually have changed)
# ---------------------------------------------------------------------------

topic="$c_topic"
if [ "$hook_event" = "UserPromptSubmit" ] || [ -z "$topic" ]; then
    # UserPromptSubmit carries the prompt inline. Prefer it: transcript_path is
    # written asynchronously and lags, so reading it here can yield the
    # *previous* turn's question.
    topic="${payload_prompt:-}"

    if [ -z "$topic" ] && [ -f "$transcript_path" ]; then
        topic=$(jq -r "$jq_clean"'select(.type == "last-prompt") | (.lastPrompt | clean)' \
            "$transcript_path" 2>/dev/null | tail -1) || topic=""
    fi
    # Fallbacks for resumed sessions whose transcript has no last-prompt entry.
    if [ -z "$topic" ] && [ -n "$transcript_path" ]; then
        index="$(dirname "$transcript_path")/sessions-index.json"
        if [ -f "$index" ]; then
            topic=$(jq -r --arg id "$session_id" "$jq_clean"'
                .entries[] | select(.sessionId == $id) | (.summary | clean)' \
                "$index" 2>/dev/null | head -1) || topic=""
        fi
    fi
    if [ -z "$topic" ] && [ -f "$transcript_path" ]; then
        topic=$(head -10 "$transcript_path" | \
            jq -r "$jq_clean"'select(.type == "user") | (.message.content | clean)' \
            2>/dev/null | head -1) || topic=""
    fi
fi

# Payload cwd is authoritative; fall back to the cached value before $PWD so
# the context stays stable across events that omit cwd.
if [ -n "${cwd:-}" ]; then
    dir=$(basename "$cwd")
else
    dir="${c_dir:-$(basename "$PWD")}"
fi

# ---------------------------------------------------------------------------
# Resolve target tty (cached; a session never moves between terminals)
# ---------------------------------------------------------------------------

target="$c_tty"
if [ -z "$target" ]; then
    # Walk up the process tree to find a real controlling TTY. Hook subprocesses
    # may be spawned without one, but Claude Code (or its ancestor terminal)
    # has it.
    pid=$PPID
    for _ in 1 2 3 4 5 6 7 8; do
        { [ -z "$pid" ] || [ "$pid" -le 1 ]; } && break
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' \n')
        case "$tty" in
            ""|"?"|"??") ;;
            /dev/*) target="$tty"; break ;;
            *)      target="/dev/$tty"; break ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' \n')
    done
fi

# ---------------------------------------------------------------------------
# Persist, then publish
# ---------------------------------------------------------------------------

mkdir -p "$state_dir" 2>/dev/null || true
tmp="$state_file.$$"
if printf '%s\n%s\n%s\n' "$target" "$dir" "$topic" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
fi

# Sweep sessions that ended without a SessionEnd hook (crash, SIGKILL).
[ "$hook_event" = "SessionStart" ] && \
    find "$state_dir" -type f -mtime +7 -delete 2>/dev/null || true

[ -n "$topic" ] && context="$dir: $topic" || context="$dir"

# GNU base64 wraps at 76 columns and may shadow the BSD one on PATH
encoded=$(printf '%s' "$context" | base64 | tr -d '\n')

if [ -n "$target" ] && [ -w "$target" ]; then
    printf '\033]1337;SetUserVar=claude_context=%s\007' "$encoded" > "$target" 2>/dev/null || true
fi
