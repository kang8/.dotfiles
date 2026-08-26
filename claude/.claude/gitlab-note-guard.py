#!/usr/bin/env python3
"""PreToolUse guard: block writes that publish a GitLab note immediately.

Draft notes are reversible, published notes are not. Anything landing on an MR
goes in via POST .../draft_notes and is published by Kang's own Submit click.
See memory feedback_review_before_posting_external.
"""

import json
import re
import sys

# Endpoints that make text visible the instant they are called.
PUBLISHES = re.compile(
    r"""
      /(?:merge_requests|issues|snippets|commits)/[^/\s'"]+/notes\b   # direct note
    | /discussions/[^/\s'"]+/notes\b                                   # threaded reply
    | /draft_notes/bulk_publish\b                                      # publish the batch
    | /draft_notes/[^/\s'"]+/publish\b                                 # publish one draft
    """,
    re.VERBOSE,
)

# glab porcelain that posts a comment without ever naming an endpoint.
GLAB_PORCELAIN = re.compile(r"\bglab\s+(?:mr|issue)\s+(?:note|comment)\b")

# Signals that a `glab api` / `curl` call is a write rather than a read.
WRITES = re.compile(
    r"""
      -X\s*(?:POST|PUT|PATCH)
    | --method[=\s]+(?:POST|PUT|PATCH)
    | --input\b
    | (?:^|\s)-f\s
    | --field\b
    | (?:^|\s)-d\s
    | --data(?:-raw|-binary|-urlencode)?\b
    """,
    re.VERBOSE | re.IGNORECASE,
)

REASON = (
    "Blocked: this would publish a GitLab note immediately, and published notes "
    "cannot be unpublished.\n\n"
    "Use a draft note instead:\n"
    "  POST /projects/:id/merge_requests/:iid/draft_notes\n"
    "  (add in_reply_to_discussion_id=<id> to thread a reply)\n\n"
    "Drafts stay pending until Kang clicks Submit review. 「发送」/「post it」 means "
    "create the draft; only an explicit 「publish」/「submit」 authorises bulk_publish.\n"
    "The gitlab-mr-review skill does this correctly — ask Kang to run it."
)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # never break the session on a malformed event

    command = payload.get("tool_input", {}).get("command", "")
    if not isinstance(command, str) or not command:
        return 0

    publishes = bool(PUBLISHES.search(command))
    # Reading notes is fine; only deny when the call carries a body or method.
    blocked = GLAB_PORCELAIN.search(command) or (publishes and WRITES.search(command))
    # bulk_publish / publish are POST-only, so the endpoint alone is enough.
    blocked = blocked or re.search(r"/draft_notes/(?:bulk_publish|[^/\s'\"]+/publish)\b", command)

    if not blocked:
        return 0

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": REASON,
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
