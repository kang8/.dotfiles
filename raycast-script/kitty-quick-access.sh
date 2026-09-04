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
exec /usr/bin/env -u NODE_ENV -u NODE_PATH kitten quick-access-terminal
