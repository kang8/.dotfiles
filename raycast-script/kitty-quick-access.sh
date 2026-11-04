#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kitty Quick Access
# @raycast.mode silent
#
# Optional parameters:
# @raycast.packageName Kitty
# @raycast.icon 🐱
#
# Documentation:
# @raycast.description Toggle kitty quick-access-terminal
#
# Credits
# @raycast.author kang
# @raycast.authorURL https://github.com/kang8

#####################################################################################

# Raycast runs scripts with cwd=/, and the quick-access panel daemon inherits
# that as the default cwd for every new tab. Start from $HOME so new tabs open
# in ~ instead of / (matching the native kitty.app behaviour).
cd "$HOME" || exit 1

# launchd starts Raycast with a bare PATH that has no Homebrew on it.
eval "$("$HOME/.local/bin/brew-shellenv")"

# Raycast leaks its Node runtime env (NODE_ENV=production, NODE_PATH) into
# launched apps (github.com/raycast/extensions/issues/229). Strip them so
# shells inside the panel don't run dev tooling in production mode.
# A running panel is toggled by quick_access_toggle.py over this fixed socket,
# which focuses the panel when it is visible behind another app. kitty binds the
# socket without unlinking first, so a stale file left by a crash is removed
# before starting a new panel.
socket=/tmp/quick-access
kitten @ --to "unix:$socket" kitten quick_access_toggle.py > /dev/null 2>&1 && exit
rm -f "$socket"
exec /usr/bin/env -u NODE_ENV -u NODE_PATH kitten quick-access-terminal --listen-on="unix:$socket"
