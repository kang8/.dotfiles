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

**Every finding must be inline.** A finding with neither `new_line` nor
`old_line` becomes an MR-level draft note — never create one. See _No MR-level
summary_ below.

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
  }
]
```

### No MR-level summary

Do **not** add an overall / 总评 / "here's my summary" entry — it's not the
user's style. Every object in the array carries a `file` and a line. If a
finding feels like it needs preamble, put that preamble in the one inline note
it actually belongs to, or drop it.

Any cross-cutting context worth saying (what you skipped and why, overall
verdict) goes in your **reply in the conversation**, not on the MR.

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
glab api projects/<id>/merge_requests/<iid>/draft_notes | python3 -c "
import sys, json
for n in sorted(json.load(sys.stdin), key=lambda x: x['id']):
    p = n.get('position') or {}
    print(n['id'], str(p.get('new_line') or '-').rjust(4), p.get('new_path') or 'MR-level')
"
```

Print the path, not just the line — a draft that lost its binding shows up as
`MR-level`, which is invisible if you only look at line numbers. Since the skill
never creates MR-level notes on purpose, **any** `MR-level` row is a bug: delete
that draft and recreate it with correct line fields.

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
- **Editing an inline draft: delete and recreate — never `PUT`.** Update on a
  draft note is whole-object replacement, not a patch: a
  `PUT .../draft_notes/<id>` carrying only `note` silently drops `position`, and
  the draft degrades to an MR-level comment. (Unlike published discussion notes,
  where editing the body leaves the position alone.) So to reword an inline
  draft, `DELETE` it and re-run `post_review.py` with the new body — the script
  re-attaches a fresh `position`. Re-read the draft list afterwards to confirm;
  the `PUT` response looks successful either way.
- `diff_refs` (base/start/head SHA) come from the MR object and change on every
  push — the script always re-fetches them, so don't cache them.
