#!/bin/sh
# Bound to alt+h/j/k/l in config.toml. Inside nvim the key goes on to
# smart-splits; otherwise it moves between herdr panes, and at the edge of the
# layout it moves between kitty windows, as alt+h/j/k/l does outside herdr.
set -u

dir=$1
case $dir in
left) key=h ;;
down) key=j ;;
up) key=k ;;
right) key=l ;;
*) exit 2 ;;
esac

# Custom commands run on the server without HERDR_PANE_ID, so this resolves to
# the focused pane.
edges=$(herdr pane edges) || exit 1
pane=$(printf '%s' "$edges" | jq -r '.result.edges.pane_id')

if herdr pane process-info --pane "$pane" | jq -e '
  .result.process_info.foreground_processes[]
  | select(.name == "nvim" or (.argv0 | test("(^|/)nvim$")))' >/dev/null; then
  exec herdr pane send-keys "$pane" "alt+$key"
fi

if [ "$(printf '%s' "$edges" | jq -r ".result.edges.$dir")" = false ]; then
  exec herdr pane focus --pane "$pane" --direction "$dir"
fi

exec "$(dirname "$0")/kitty-neighbor.sh" "$dir"
