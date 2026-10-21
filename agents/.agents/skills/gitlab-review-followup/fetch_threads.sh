#!/usr/bin/env bash
# Print the open review threads of a GitLab MR as a JSON array.
# Usage: fetch_threads.sh [mr-iid | mr-url]   (default: the current branch's MR)
set -euo pipefail

mr="$(glab mr view ${1:+"$1"} -F json)"
iid="$(jq -r .iid <<<"$mr")"
web_url="$(jq -r .web_url <<<"$mr")"
me="$(glab api user | jq -r .username)"

glab api --paginate "projects/:fullpath/merge_requests/${iid}/discussions?per_page=100" |
  jq -s --arg me "$me" --arg web_url "$web_url" '
    [ .[][]
      | select(.notes[0].system | not)
      | select(.notes[0].resolved != true)
      | {
          id,
          url: "\($web_url)#note_\(.notes[0].id)",
          waiting_on_reviewer: (.notes[-1].author.username == $me),
          path: .notes[0].position.new_path,
          line: .notes[0].position.new_line,
          head_sha: .notes[0].position.head_sha,
          notes: [.notes[] | {author: .author.username, created_at, body}]
        }
    ]'
