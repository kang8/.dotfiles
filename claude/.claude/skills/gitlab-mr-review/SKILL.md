---
name: gitlab-mr-review
description: Post code-review findings to a GitLab merge request as inline DRAFT notes ("add to review"), not immediately-published comments. Resolves the MR from the current branch, attaches each finding to the right diff line, and stops without publishing unless asked. Use when the user says "comment these on the MR", "add to review", "put my review on GitLab", "/gitlab-mr-review", or similar after a code review.
disable-model-invocation: true
---

You are publishing a set of code-review findings to a GitLab MR as **draft
notes** — the "add to review" flow, where comments accumulate unpublished until
the reviewer submits the whole review. You do **not** post immediate ("Add
comment now") notes, and you do **not** publish the review unless the user
explicitly asks.

Per the user's global rules, always use the `glab` CLI for GitLab — never raw
`curl`. The helper script in this skill wraps `glab api`.

## Step 0 — Have findings ready

This skill posts findings that already exist — usually from a code review you
just produced in this conversation, or a list the user pasted. If there are no
findings yet, run the review first (e.g. the `/code-review` flow) and confirm
the list with the user before posting. Each finding needs: a file path
(repo-relative), a line, and a comment body.

## Step 1 — Identify the MR

Run in parallel:

- `git rev-parse --abbrev-ref HEAD` — current branch
- `glab mr view 2>/dev/null | head -20` — shows `number`, `url`, `reviewers` for
  the branch's open MR

If no MR is found for the branch, ask the user for the MR iid — do not guess.
The helper script auto-resolves the MR from the current branch, so you normally
only need `--mr` when overriding.

## Step 2 — Map each finding to a diff line (critical)

GitLab binds an inline note to a position. Get the line _type_ right or the note
silently degrades to a general (non-inline) comment:

- **Added line** (`+` in the diff) → `new_line` only. This is the common case
  for reviewing new code.
- **Removed line** (`-`) → `old_line` only.
- **Context line** (unchanged, shown for context) → **both** `new_line` and
  `old_line`.
- **Overall / non-line note** → omit both; it becomes an MR-level draft note.

Line numbers are 1-based and refer to the file _as it appears in the diff_
(new-file numbering for added/context lines; old-file numbering for removed).
When in doubt for a touched file, `git diff master...HEAD -- <file>` and read
the hunk headers to confirm which side a line lives on.

## Step 3 — Write the findings JSON

Build a JSON array. Keep each `body` concise and actionable; lead with a short
bold tag (e.g. `**[bug]**`, `**[需确认]**`) so the MR thread scans well. Match
the language the user/MR is using (mirror the language of the existing MR
description and threads).

```json
[
  {
    "file": "transform/models/.../x.sql",
    "new_line": 11,
    "body": "**[bug]** ..."
  },
  {
    "file": "transform/models/.../x.sql",
    "new_line": 87,
    "body": "**[需确认]** ..."
  },
  { "body": "**总评** ... (MR-level, no line)" }
]
```

Write it to a temp file (e.g. `/tmp/mr_findings.json`) — easier than escaping a
long heredoc.

## Step 4 — Create the drafts (do not publish)

```bash
python3 ~/.claude/skills/gitlab-mr-review/post_review.py /tmp/mr_findings.json
```

The script: resolves project from `git remote` + MR from the branch, fetches the
MR's `diff_refs`, POSTs each finding as a draft note with a proper JSON
`position`, then **reads each draft back** and prints a table with an `OK` /
`NOT-BOUND` status per note. It does not publish.

Optional flags: `--mr <iid>` to target a specific MR, `--project <path|id>` to
override the project.

## Step 5 — Verify and report

Read the script's status table. For any row marked `NOT-BOUND`, the line type
was likely wrong (e.g. you gave `new_line` for a context line that needs both) —
fix that finding's line fields and re-run just that one. Optionally confirm
cleanly:

```bash
glab api projects/<id>/merge_requests/<iid>/draft_notes \
  | python3 -c "import sys,json;[print(n['id'],(n.get('position') or {}).get('new_line')) for n in json.load(sys.stdin)]"
```

Then tell the user:

- The MR (`!<iid>` + url) and how many drafts were created, with the line each
  landed on.
- That they are **drafts** — visible only to the user until submitted.
- How to publish: Submit review in the MR UI, **or** ask you to re-run with
  `--publish` (which calls the `draft_notes/bulk_publish` endpoint).

Clean up the temp findings file. **Never** pass `--publish` unless the user
explicitly asks to publish/submit the review now.

## Notes / gotchas

- `glab api -f "position[key]=..."` does **not** work for nested positions (only
  `position_type` survives; SHAs come back null). The script avoids this by
  sending a JSON body via `--input`. Don't "simplify" back to `-f` form fields.
- To delete a stray draft:
  `glab api -X DELETE projects/<id>/merge_requests/<iid>/draft_notes/<draft_id>`.
- `diff_refs` (base/start/head SHA) come from the MR object and change on every
  push — the script always re-fetches them, so don't cache them.
