#!/bin/sh
# The overlay pane. Lets the hints kitten pick a link, or shows
# LINK_HINTS_MESSAGE until a key press or 1.5 s, since herdr's notifications
# go to the outer terminal, which stays quiet while it has focus.
set -u

if [ -n "${LINK_HINTS_MESSAGE:-}" ]; then
  printf '\n  %s' "$LINK_HINTS_MESSAGE"
  stty -icanon -echo min 0 time 15
  dd bs=1 count=1 >/dev/null 2>&1
  exit 0
fi

d=$LINK_HINTS_DIR
# The kitten prints its JSON result on stdout and draws on the tty.
# link_hints.py waits for `result`, so it appears only once the kitten exits.
# Home row first, then the top and bottom rows; numbering starts at the
# bottom, so the newest link gets f.
#
# The kitten draws the rest of the screen at full strength and strips any
# SGR from its input, so the links carry their own background instead. "auto"
# text color falls back to bright-gray outside kitty, which is lighter than
# the surrounding text on a light theme.
kitten hints --type hyperlink \
  --alphabet fjdkslaghrueiwovmcn --hints-offset 0 --prefix-free \
  --hints-foreground-color '#ffffff' --hints-background-color '#d20f39' \
  --hints-text-color '#1e1e2e' --hints-text-background-color '#f9e2af' \
  <"$d/input" >"$d/out"
mv "$d/out" "$d/result"
