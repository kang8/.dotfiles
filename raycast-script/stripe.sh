#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Stripe dashboard, and search **_id
# @raycast.mode silent
# @raycast.description Open Stripe dashboard page
#
# Optional parameters:
# @raycast.packageName Customized
# @raycast.icon https://b.stripecdn.com/manage-statics-srv/assets/public/favicon.ico
# @raycast.argument1 { "type": "text", "placeholder": "ID", "optional": true }
#
# Credits
# @raycast.author kang8

if [[ -z ${1} ]] # if do not input any word
then
    open https://dashboard.stripe.com
else
    open https://dashboard.stripe.com/search?query=${1}
fi

