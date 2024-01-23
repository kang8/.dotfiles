#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Search SQLFluff rule code and name
# @raycast.mode silent
#
# Optional parameters:
# @raycast.packageName Customized
# @raycast.icon https://docs.sqlfluff.com/en/stable/_static/favicon-fluff.png
# @raycast.argument1 { "type": "text", "placeholder": "code", "optional": true }
#
# Credits
# @raycast.author kang8

if [[ -z ${1} ]] # if do not input any word
then
    open https://docs.sqlfluff.com
else
    open https://docs.sqlfluff.com/en/stable/rules.html#rule-${1}
fi

