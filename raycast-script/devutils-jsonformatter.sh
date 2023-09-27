#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.icon https://devutils.com/84.png
# @raycast.title JSON Format/Validate
# @raycast.mode silent
# @raycast.packageName DevUtils.app

# Documentation:
# @raycast.description Format the JSON string currently in your clipboard (if it’s a valid JSON)
# @raycast.author DevUtils.app
# @raycast.authorURL https://devutils.app

open devutils://jsonformatter?clipboard
