#!/bin/sh
# Types a printf-escaped byte sequence into the focused pane, as kitty's
# `send_text all` did. A bound key would reach the pane re-encoded by herdr: a
# plain shell gets ctrl+shift+f as ^F, and panes without the kitty keyboard
# protocol lose cmd chords.
set -u

pane=$(herdr pane current | jq -r '.result.pane.pane_id') || exit 1
# shellcheck disable=SC2059
exec herdr pane send-text "$pane" "$(printf "$1")"
