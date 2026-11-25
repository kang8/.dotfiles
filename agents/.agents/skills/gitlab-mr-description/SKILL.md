---
name: gitlab-mr-description
description: Write or tighten a GitLab MR description from the branch's actual diff, then push it with glab.
disable-model-invocation: true
---

You are writing the description of a GitLab MR; Step 1 opens it if the branch
has none. The reviewer reads the diff too — the description earns its space only
by carrying what the diff cannot.

Use the `glab` CLI for every GitLab call, never raw `curl`.

## Step 1 — Locate the MR

Run in parallel:

- `git rev-parse --abbrev-ref HEAD`
- `glab mr view [iid] -F json | jq '{iid, web_url, target_branch, sha}'` — omit
  the iid to resolve from the branch; a pasted MR URL ends in the iid

This keeps the current description out of context until Step 3, so the diff, not
the old structure, shapes what you write.

No MR for the branch → open one. The branch must be on the remote
(`git ls-remote --exit-code origin <branch>`); if it is not, ask before pushing.

```bash
glab mr create --target-branch "$(glab api projects/:fullpath | jq -r .default_branch)" \
  --title "$(git log -1 --format=%s)" \
  --assignee "$(glab api user | jq -r .username)" --remove-source-branch --yes
```

Target the default branch unless the user named another. "Another open merge
request already exists" means one appeared meanwhile: use the iid in that error.

## Step 2 — Read the diff

`git show --stat <sha>` for a single-commit branch, `git diff master...HEAD`
otherwise, then read the hunks of every changed file.

Done when every changed file is accounted for in your model of the change.

## Step 3 — Write fresh, then harvest

Write the whole description from your model of the change alone, as if the MR
had none.

Then, if the MR already had a description, read it (`glab mr view <iid>`, below
the `--` line) as a **fact source**; an MR opened in Step 1 has none, so skip
the harvest. A measured number, a verification result, a link or a decision the
diff cannot show earns a place in your draft once you have checked it against
the code. Everything else in it is **sediment** and stays behind, however much
of the old wording that drops.

Terse is the bar. Put every section through one sentence said aloud: _the
reviewer cannot get this from the diff, because ___._ No ending to that sentence
is a cut.

Keep what survives it:

- measured numbers, and the sample they came from
- the **composed artifact** the source does not show literally — a generated CEL
  expression, the final SQL, the rendered payload — as a before/after
- **silent-failure traps**: what breaks with no error if someone changes it back
- deliberately unchanged, where the reviewer would otherwise expect a change
- verification you ran this session, as command → observed result; a check
  nobody ran is left out, or listed as not verified with the reason

Cut:

- background framing the opening sentence already carries
- multi-paragraph justification of a design choice; one sentence for the road
  not taken
- rationale that already lives in a code comment
- numbered rollout checklists — one line if it matters
- a visual plus the paragraph it was supposed to replace
- a section whose _because_ is a rewording of one already spoken

Write in the language of the existing description; these are often Chinese. With
no existing description, write in English.

Done when every surviving section has said its _because_, and the body fits a
screen — 50 lines. Past that, say what the extra lines carry that the diff does
not.

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

The MR exists after Step 1, so this is always an update. Heredoc the body to a
file first; passing markdown inline mangles backticks and `$`:

```bash
cat > "$TMPDIR/mr<iid>.md" <<'MDEOF'
...
MDEOF
glab mr update <iid> --description "$(cat "$TMPDIR/mr<iid>.md")"
```

Keep the file for the rest of the session — follow-up rounds are then `Edit`
calls against it plus a re-push, not a full retype.
