#!/usr/bin/env bash

SAVE_DIR="$HOME/kang8/screenshots"

if [ ! -d "$SAVE_DIR" ]; then
    mkdir --parents "$SAVE_DIR"
fi

DISPLAY_COUNT=$(/usr/sbin/system_profiler SPDisplaysDataType -json | /usr/bin/jq '.SPDisplaysDataType[].spdisplays_ndrvs | length')

for ((i=1; i<=DISPLAY_COUNT; i++)); do
    if [ $i -eq 1 ]; then
        DISPLAY_NAME="main"
    else
        DISPLAY_NAME="secondary_$((i-1))"
    fi

    FILENAME="$(date '+%Y%m%d')_${DISPLAY_NAME}_screen.png"

    /usr/sbin/screencapture -D $i -xC "$SAVE_DIR/$FILENAME"

    echo "Screenshot saved to $SAVE_DIR/$FILENAME"
done
