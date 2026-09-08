---
name: gitlab-mr-description
description: Write or tighten a GitLab MR description from the branch's actual diff, then push it with glab.
disable-model-invocation: true
---

You are writing the description of an existing GitLab MR. The reviewer reads the
diff too — the description earns its space only by carrying what the diff
cannot.

Use the `glab` CLI for every GitLab call, never raw `curl`.

## Step 1 — Locate the MR

Run in parallel:

- `git rev-parse --abbrev-ref HEAD`
- `glab mr view [iid] 2>&1 | head -80` — omit the iid to resolve from the
  branch; a pasted MR URL ends in the iid

`glab mr view` prints the current description below the `--` line. Read it: you
are usually editing a draft, not starting blank. No MR for the branch → ask for
the iid rather than guessing.

## Step 2 — Read the diff, not the prose

`git show --stat <sha>` for a single-commit branch, `git diff master...HEAD`
otherwise, then read the hunks of every changed file.

The existing description is a _claim_ about the diff. Verify each number, each
file reference, and especially each "unchanged" claim against what you just
read. Rewriting from the prose alone produces a description that reads better
and says the same wrong things.

Done when every changed file is accounted for in your model of the change.

## Step 3 — Keep and cut

Terse is the bar. Keep what the reviewer cannot derive from the diff:

- measured numbers, and the sample they came from
- the **composed artifact** the source does not show literally — a generated CEL
  expression, the final SQL, the rendered payload — as a before/after
- **silent-failure traps**: what breaks with no error if someone changes it back
- what is deliberately unchanged, and why

Cut:

- background framing the opening sentence already carries
- multi-paragraph justification of a design choice; one sentence for the road
  not taken
- rationale that already lives in a code comment
- numbered rollout checklists — one line if it matters

Write in the language of the existing description; these are often Chinese.

## Step 4 — Visuals

Invoke the `show-me` skill to choose the form: its "smallest view that makes the
point" heuristic is exactly the bar here, and its pseudocode / call-tree /
file-tree / `diff` sketches all paste straight into a description.

Two of its options are dead in this destination — **`gitlab.rightcapital.io`
(self-hosted) renders neither `` ```mermaid `` nor a standalone HTML artifact**;
mermaid prints as raw source. Where `show-me` would reach for a mermaid graph,
translate it into plain text:

- a `` ```text `` block with `█` bars for a funnel or any single-metric
  breakdown; scale the bars to a fixed width (24 chars = 100%) so the shrink is
  visible, and put the survivor count on the last row
- a `` ```diff `` block for the before/after of a composed string or config
  shape
- a table when two dimensions are **orthogonal** — a 2×2 grid shows that the
  levers multiply, where a 4-row list reads as four competing alternatives

Mermaid loses nothing worth having: its node size cannot encode a value, so a
scaled ASCII bar carries more of a funnel than a flowchart does.

Keep every line under 80 columns: the description pane narrows when a diff is
open beside it.

A dense visual is a cut, not an addition — it replaces the paragraph that would
otherwise describe it.

## Step 5 — Push

Heredoc the body to a file first; passing markdown inline mangles backticks and
`$`:

```bash
cat > "$TMPDIR/mr<iid>.md" <<'MDEOF'
...
MDEOF
glab mr update <iid> --description "$(cat "$TMPDIR/mr<iid>.md")"
```

Keep the file for the rest of the session — follow-up rounds are then `Edit`
calls against it plus a re-push, not a full retype.
