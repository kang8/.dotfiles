#!/bin/sh
# Moves to the neighboring kitty window. Called at the edge of the herdr layout
# by navigate.sh, and by smart-splits' at_edge in nvim.
set -u

# kitty appends its pid to listen_on, and the herdr server outlives kitty
# restarts, so look the socket up instead of trusting an inherited one.
for sock in /tmp/mykitty-*; do
  kill -0 "${sock##*-}" 2>/dev/null &&
    exec kitty @ --to "unix:$sock" action neighboring_window "$1"
done
