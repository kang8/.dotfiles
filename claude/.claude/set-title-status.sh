#!/bin/bash
# set-title-status.sh - Terminal title with Claude Code status
#
# Usage: echo '<hook_json>' | bash set-title-status.sh <action>
#
# Actions:
#   session  ● ready      (SessionStart)
#   run      ⏳ working    (UserPromptSubmit, PostToolUse*, PermissionDenied)
#   alert    🔴 + bell     (Notification: permission_prompt|elicitation_dialog)
#   done     ✅ finished   (Stop, StopFailure)
#   release  clear title  (SessionEnd)
#
# Design notes:
#   State and rendering are separated. Per-session state lives in a cache file
#   ($tty, $seq, $status, $dir, $topic); hooks only mutate status, and a single
#   render step composes the title. That keeps the hot path (PostToolUse fires
#   on every tool call and *blocks* Claude) down to one jq + one file read.

set -eu

STATUS="${1:-done}"
input=$(cat)

state_dir="${TMPDIR:-/tmp}/claude-title"

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
    ] | join("")' 2>/dev/null) || fields=""

# Unit separator, not tab: tab is an IFS *whitespace* character, so bash would
# collapse runs of empty fields and shift every value left. Payload strings are
# run through `clean` (or are UUIDs/paths), so US can never appear in content.
IFS=$'\037' read -r session_id agent_id hook_event cwd transcript_path payload_prompt \
    <<< "${fields:-}" || true

[ -n "${session_id:-}" ] || exit 0

# Subagent hooks carry agent_id and describe the subagent's lifecycle, not the
# main turn's. SubagentStop in particular is a *completion* event that can fire
# after the main turn already stopped - never let it revive a finished session.
[ -z "${agent_id:-}" ] || exit 0
[ "${hook_event:-}" != "SubagentStop" ] || exit 0

# ---------------------------------------------------------------------------
# Load cached session state
# ---------------------------------------------------------------------------

state_file="$state_dir/$session_id"
c_tty="" c_seq="0" c_status="" c_dir="" c_topic=""
if [ -r "$state_file" ]; then
    {
        IFS= read -r c_tty
        IFS= read -r c_seq
        IFS= read -r c_status
        IFS= read -r c_dir
        IFS= read -r c_topic
    } < "$state_file" 2>/dev/null || true
fi
case "${c_seq:-}" in ''|*[!0-9]*) c_seq=0 ;; esac

if [ "$STATUS" = "release" ]; then
    rm -f "$state_file" 2>/dev/null || true
    [ -n "$c_tty" ] && [ -w "$c_tty" ] && printf '\033]0;\007' > "$c_tty" 2>/dev/null || true
    exit 0
fi

# ---------------------------------------------------------------------------
# Ordering guard
# ---------------------------------------------------------------------------

# Hooks are independent processes and can overlap; a slow `run` must not
# overwrite a `done` that was emitted after it. EPOCHREALTIME is bash>=5 and
# needs no fork. The decimal separator is locale-dependent, hence [.,].
now=""
if [ -n "${EPOCHREALTIME:-}" ]; then
    now="${EPOCHREALTIME/[.,]/}"
    case "$now" in
        ''|*[!0-9]*) now="" ;;
        *) [ "$now" -ge "$c_seq" ] || exit 0 ;;
    esac
fi
[ -n "$now" ] || now=$(( c_seq + 1 ))

# Hot path: PostToolUse fires per tool call and almost always finds us already
# in `run`. Nothing to render, so stop before touching the tty.
if [ "$STATUS" = "$c_status" ] && [ "$hook_event" != "UserPromptSubmit" ]; then
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

# Payload cwd is authoritative (it tracks CwdChanged); fall back to the cached
# value before $PWD so the title stays stable across events that omit cwd.
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
# Persist, then render
# ---------------------------------------------------------------------------

mkdir -p "$state_dir" 2>/dev/null || true
tmp="$state_file.$$"
if printf '%s\n%s\n%s\n%s\n%s\n' "$target" "$now" "$STATUS" "$dir" "$topic" \
        > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
fi

# Sweep sessions that ended without a SessionEnd hook (crash, SIGKILL).
[ "$hook_event" = "SessionStart" ] && \
    find "$state_dir" -type f -mtime +7 -delete 2>/dev/null || true

[ -n "$topic" ] && base="$dir: $topic" || base="$dir"

case "$STATUS" in
    run)     title="⏳ $base" ;;
    alert)   title="🔴 $base" ;;
    done)    title="✅ $base" ;;
    session) title="● $base" ;;
    *)       title="● $base" ;;
esac

if [ -n "$target" ] && [ -w "$target" ]; then
    printf '\033]0;%s\007' "$title" > "$target" 2>/dev/null || true
    # alert: ring the terminal bell so kitty marks the tab (bell_on_tab "🔔")
    # and bounces the Dock icon when unfocused (window_alert_on_bell)
    if [ "$STATUS" = "alert" ]; then
        printf '\a' > "$target" 2>/dev/null || true
    fi
fi
