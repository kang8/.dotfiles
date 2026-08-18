---
name: gitlab-mr-review
description: Post code-review findings to a GitLab MR as inline draft notes, without publishing.
disable-model-invocation: true
---

You are publishing a set of code-review findings to a GitLab MR as **draft
notes** — the "add to review" flow, where comments accumulate unpublished until
the reviewer submits the whole review.

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

**Every finding is inline: it carries a `file` and at least one line number.** A
finding with neither `new_line` nor `old_line` lands as an MR-level draft note,
which is not the user's style — put the preamble that tempted you into the one
inline note it belongs to, or drop it. Cross-cutting context (what you skipped
and why, the overall verdict) goes in your **reply in the conversation**.

GitLab binds an inline note to a position. Get the line _type_ right or the note
silently degrades to a general comment:

- **Added line** (`+` in the diff) → `new_line` only. This is the common case
  for reviewing new code.
- **Removed line** (`-`) → `old_line` only.
- **Context line** (unchanged, shown for context) → **both** `new_line` and
  `old_line`.

Line numbers are 1-based and refer to the file _as it appears in the diff_
(new-file numbering for added/context lines; old-file numbering for removed).
When in doubt for a touched file, `git diff master...HEAD -- <file>` and read
the hunk headers to confirm which side a line lives on.

## Step 3 — Write the findings JSON

Build a JSON array, mirroring the language of the existing MR description and
threads.

```json
[
  { "file": "transform/models/.../x.sql", "new_line": 11, "body": "..." },
  { "file": "transform/models/.../x.sql", "new_line": 87, "body": "..." }
]
```

Write it to `"$TMPDIR/mr_findings.json"` — easier than escaping a long heredoc.

### Comment shape

**Verdict first, as its own one-line paragraph. Then one paragraph giving the
single most fundamental reason. Then stop.** Shape of a real comment the user
wrote after cutting an AI draft to a third of its length:

```
These two lines are unnecessary.

"TagPills is real" answers the last review round; it is not written for a
reader of the docs. Someone reading this for the first time in six months
does not care whether the example exists elsewhere — they care whether
copying it works.
```

Note what that does: it names _who the text is for_ — one criterion the author
can reuse on the next comment like it — and nothing else. Hold that shape:

- Open on the plain verdict, no bold tag prefix (`**[bug]**`, `**[nit]**`) — the
  user strips them.
- Assert it flatly: "these two lines are unnecessary", not "I'd suggest",
  "perhaps", "it might be worth".
- Give one reason, the most fundamental. Extra evidence proves you did the
  homework; it does not change what the author does next.
- Trust the author as a competent colleague: name what is wrong, and leave the
  downstream consequences unsaid.
- Attribute to the process, not the person: "this answers the last review round"
  lands better than "you wrote this to satisfy a reviewer".
- For prose, leave the rewording to the author unless the fix is genuinely
  non-obvious.

Add, but only when it earns its place:

- a `>` blockquote of evidence — only when the claim rests on a fact the reader
  cannot confirm by re-reading the commented line (a cross-file interaction, a
  constant defined elsewhere, framework behaviour). Never for a judgement call
  about the line itself.
- a fenced code block introduced by a softening lead-in — only when proposing
  concrete replacement code. In Chinese threads the user's own lead-in is
  `仅供参考：`.

Length check before posting: prefer the shortest version that still gives the
author a reusable criterion. A comment longer than the hunk it annotates is
almost always padded.

## Step 4 — Create the drafts

```bash
python3 ~/.claude/skills/gitlab-mr-review/post_review.py "$TMPDIR/mr_findings.json"
```

The script: resolves project from `git remote` + MR from the branch, fetches the
MR's `diff_refs`, POSTs each finding as a draft note with a proper JSON
`position`, then **reads each draft back** and prints a table with an `OK` /
`NOT-BOUND` status per note.

Optional flags: `--mr <iid>` to target a specific MR, `--project <path|id>` to
override the project.

## Step 5 — Verify and report

Done means: every draft shows a line number _and_ a file path. Read the script's
status table, then confirm independently:

```bash
glab api projects/<id>/merge_requests/<iid>/draft_notes | python3 -c "
import sys, json
for n in sorted(json.load(sys.stdin), key=lambda x: x['id']):
    p = n.get('position') or {}
    print(n['id'], str(p.get('new_line') or '-').rjust(4), p.get('new_path') or 'MR-level')
"
```

Print the path, not just the line — a draft that lost its binding shows up as
`MR-level`, which is invisible if you only look at line numbers. Any `NOT-BOUND`
or `MR-level` row is a bug, almost always a wrong line type (e.g. `new_line`
alone for a context line that needs both).

**To fix or reword an inline draft: delete and recreate — never `PUT`.** Update
on a draft note is whole-object replacement, not a patch: a
`PUT .../draft_notes/<id>` carrying only `note` silently drops `position` and
degrades the draft to MR-level, while returning a successful-looking response.
(Published discussion notes differ — editing the body there leaves the position
alone.) So:

```bash
glab api -X DELETE projects/<id>/merge_requests/<iid>/draft_notes/<draft_id>
```

then re-run `post_review.py` with just that finding — the script attaches a
fresh `position` — and re-read the draft list to confirm.

Then tell the user:

- The MR (`!<iid>` + url) and how many drafts were created, with the line each
  landed on.
- That they are **drafts** — visible only to the user until submitted.
- How to publish: Submit review in the MR UI, **or** ask you to re-run with
  `--publish` (which calls the `draft_notes/bulk_publish` endpoint).

Clean up the temp findings file. Pass `--publish` only when the user explicitly
asks to publish or submit the review now.
