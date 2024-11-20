#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title What is the plural of 'noun'
# @raycast.mode silent
# @raycast.description Search plural dictionary
#
# Optional parameters:
# @raycast.packageName dictionary
# @raycast.icon 📓
# @raycast.argument1 { "type": "text", "placeholder": "noun" }

open https://www.wordhippo.com/what-is/the-plural-of/${1}.html
