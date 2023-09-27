#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Next Display by kang
# @raycast.mode silent
# @raycast.description Force to Next Display
#
# Optional parameters:
# @raycast.icon 🪟
# @raycast.packageName Window Management
#
# Credits
# @raycast.author kang
# @raycast.authorURL https://github.com/kang8

#####################################################################################

is_full_screen=$(osascript -e 'tell application "System Events"' \
 -e 'tell (process 1 where it is frontmost) to get value of attribute "AXFullScreen" of window 1' \
 -e 'end tell')

if $is_full_screen; then
    open -g raycast://extensions/raycast/window-management/toggle-fullscreen
    osascript -e 'delay 0.45'
    open -g raycast://extensions/raycast/window-management/next-display
    osascript -e 'delay 0.45'
    open -g raycast://extensions/raycast/window-management/toggle-fullscreen
else
    open -g raycast://extensions/raycast/window-management/next-display
    open -g raycast://extensions/raycast/window-management/almost-maximize
fi
