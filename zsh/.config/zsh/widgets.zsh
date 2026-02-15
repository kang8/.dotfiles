# Custom ZLE widgets


# Custom backward-kill-word:
# - Deletes alphanumeric characters continuously, stops at symbols
# - Symbols can also be deleted (won't skip symbols to delete the word before them)
#
# Examples (| = cursor):
#
#   1. Delete alphanumeric word:
#      hello world|  -->  hello |
#            ^^^^^
#
#   2. Delete symbols only (stops at alphanumeric):
#      foo---bar|  -->  foo---|
#            ^^^
#
#   3. Delete symbols:
#      foo---|  -->  foo|
#         ^^^
#
#   4. Skip trailing spaces first:
#      hello   |  -->  |
#      ^^^^^^^^
#
#   5. Mixed path example:
#      /usr/local/bin|  -->  /usr/local/|  -->  /usr/local|  -->  /usr/|
#                 ^^^                  ^              ^^^^
backward-kill-word-smart() {
    # Skip trailing spaces
    while [[ -n $LBUFFER && $LBUFFER[-1] == ' ' ]]; do
        LBUFFER=${LBUFFER[1,-2]}
    done
    # Check character type before cursor and delete same type
    if [[ $LBUFFER[-1] == [[:alnum:]] ]]; then
        # Delete alphanumeric until non-alphanumeric
        while [[ -n $LBUFFER && $LBUFFER[-1] == [[:alnum:]] ]]; do
            LBUFFER=${LBUFFER[1,-2]}
        done
    else
        # Delete non-alphanumeric non-space until space or alphanumeric
        while [[ -n $LBUFFER && $LBUFFER[-1] != ' ' && $LBUFFER[-1] != [[:alnum:]] ]]; do
            LBUFFER=${LBUFFER[1,-2]}
        done
    fi
}
zle -N backward-kill-word-smart
