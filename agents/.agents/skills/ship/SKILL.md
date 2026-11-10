---
name: ship
description: Bring the current branch's MR up to date in one pass — one commit on a fresh target, pushed, with the commit message, MR description and draft replies rewritten for the final code.
disable-model-invocation: true
---

You are shipping the current branch's MR. Done means: the branch is one commit
on top of a freshly fetched target, the remote holds that commit, and every
piece of prose about it — commit message, MR description, review replies —
describes the code as it is now.

**Rewrite** is the leading word for all prose in this run. Write each piece
fresh from the final diff; the earlier version is a source of facts to verify,
and whatever in it you have not re-verified stays behind as sediment.

Run each git command as its own Bash call. `git add`, `git commit --amend`,
`git rebase` and `git push --force-with-lease` each match an allow rule on their
own; chained with `&&`, the whole line falls to the auto-mode classifier, which
refuses history rewrites.

## Step 1 — Locate

Resolve the MR yourself: take an MR this conversation has worked on (a `!<iid>`,
an MR URL, a `merge_requests/<iid>` API path), else omit the iid and let `glab`
resolve it from the current branch.

Run in parallel:

- `git status --short --branch`
- `glab mr view [iid] -F json | jq '{iid, web_url, target_branch, sha, source_branch}'`
  (the description stays out of context until Step 5)
- `git rev-parse HEAD`

`source_branch` must equal the current branch; a mismatch means the iid came
from some other MR in the conversation (one under review, a linked one), so drop
it and resolve from the branch. No MR either way → ask for the iid.

Then fetch the target as its own command and read `origin/<target>` only after
it exits 0: `git fetch origin <target>`.

Stop and report when the MR's `sha` differs from local `HEAD` and is not an
ancestor of it: someone else pushed, and a force-push would drop their work.

The ship set is what is staged. Nothing staged → stage the modified tracked
files (`git add <paths>`) and list them in the report; untracked files go in
only when the user names them.

## Step 2 — Fold into one commit

`N=$(git rev-list --count origin/<target>..HEAD)`:

- `N = 1` → `git commit --amend`.
- `N > 1` → `git reset --soft $(git merge-base HEAD origin/<target>)`, then one
  `git commit`.
- `N = 0` → one `git commit`.

Rewrite the message from the final diff (`git diff --staged` plus
`git diff origin/<target>...HEAD`), following the style rules in Step 4 of
`~/.agents/skills/commit/SKILL.md` and the source ranking in §3 of
`~/.agents/skills/commit/AMEND.md`. Write the message to `$TMPDIR` and pass it
with `-F`.

Let hooks run; when one fails, fix the cause and re-run the same commit.

Done when the branch is one commit and every sentence of its message is true of
`git show HEAD`.

## Step 3 — Rebase onto the target

Follow Steps 3–4 of `~/.agents/skills/rebase/SKILL.md` with `origin/<target>`.
Its sandbox probe decides where `git rebase` runs. When it flags paths and the
unsandboxed run is refused, hand the user the single command
`! git rebase origin/<target>` and wait; never start a sandboxed rebase that the
probe flagged, since it leaves a half-written tree.

Done when `git merge-base --is-ancestor origin/<target> HEAD` exits 0.

## Step 4 — Push

`git push --force-with-lease origin <branch>`.

Done when the MR's `sha` (`glab mr view <iid> -F json | jq -r .sha`) equals
`git rev-parse HEAD`.

## Step 5 — Rewrite the MR description

Follow Steps 2–5 of `~/.agents/skills/gitlab-mr-description/SKILL.md` against
the pushed commit.

## Step 6 — Draft replies

`glab api "projects/:fullpath/merge_requests/<iid>/draft_notes"` lists the
user's pending drafts.

- A draft citing a SHA that is no longer on the branch
  (`git merge-base --is-ancestor <sha> HEAD` fails) gets the new short SHA:
  `glab api -X PUT ".../draft_notes/<id>" -F note=@<file>`.
- Replies this conversation has drafted but not posted go up as new draft notes,
  per Step 5 of `~/.agents/skills/gitlab-review-followup/SKILL.md`.

Done when every draft cites a SHA on the branch and each reply's `discussion_id`
equals its thread's `id`. Publishing and resolving stay with the user and the
reviewer.

## Report

- MR link; old → new HEAD; upstream commits picked up
- The files staged in Step 1, if any
- One line on what the rewritten description and message changed
- Drafts updated and posted
- Anything handed to the user, with the exact `!` command
