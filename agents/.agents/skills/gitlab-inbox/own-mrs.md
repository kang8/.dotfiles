# Own MRs

Handling for the `mine/*` buckets of `triage.json`. Each item carries `url`,
`head`, `merge_status`, `pipeline`, and `waiting` (open threads whose last note
is someone else's).

## awaiting_reply

Hand each MR to the `gitlab-review-followup` skill. List the MRs with their
waiting authors first and run the follow-up only on the ones the user picks:
replies go out under the user's name.

## conflict

Rebase in a **scratch clone**: the branch's own worktree may host a live agent
(`herdr pane list` → `foreground_cwd`), and the sandbox write-denies some repo
paths, so an in-place rebase can die half checked out. Conflict judgement
follows Step 3 of `~/.agents/skills/rebase/SKILL.md` (read both sides' intent,
lockfile rule, ask when intents clash).

```bash
export GIT_LFS_SKIP_SMUDGE=1                     # the sandbox cannot download LFS blobs
B=<branch>; S=$TMPDIR/rebase-<iid>; R=~/Projects/<repo>
git clone -q --no-checkout "$R" "$S" && cd "$S"
git remote set-url origin "$(git -C "$R" remote get-url origin)"
git config user.email "$(git -C "$R" config user.email)"   # the push is rejected without the work email
git fetch -q "$R" "refs/remotes/origin/master:refs/remotes/origin/master" "refs/remotes/origin/${B}:refs/remotes/origin/${B}"
git switch -q -c "${B}" "origin/${B}"; OLD=$(git rev-parse HEAD)
git rebase origin/master
```

Fetch the remote first in `$R` (`git -C "$R" fetch origin master "${B}"`) so the
copied refs are fresh.

After the textual conflicts, hunt **semantic** ones: a branch that renames or
deletes identifiers can merge cleanly against upstream code that still uses the
old names. Collect the names the branch removes
(`git diff --name-status -M <merge-base> origin/${B}` renames, removed columns
and functions) and grep the rebased tree for them in files upstream changed
(`git diff --name-only <merge-base> origin/master`).

Verify with the repo's own checks. Per-repo commands live in
[`local.md`](local.md) beside this file when it exists; otherwise take them from
the repo's `AGENTS.md` / `CLAUDE.md`.

Compare `git range-diff origin/master $OLD HEAD`: every `!` row should differ
only at a resolved conflict. Push with an explicit lease on the old head:

```bash
git push --force-with-lease="${B}:${OLD}" origin "${B}"
```

When the permission layer denies it, give the user the same command prefixed
with `!`. After the push, any worktree of that branch is behind: tell the user
`git reset --hard origin/<branch>` there rather than running it, since an agent
may be working in it.

## pipeline_failed

Find the failed jobs (`glab api projects/<p>/pipelines/<id>/jobs?per_page=100`,
`status=="failed"`), read the error from the job trace, and compare with the
pipeline before the latest push
(`glab api "projects/<p>/pipelines?ref=<branch>&per_page=5"`). The same job
failing with the same error before the push means the failure predates it;
report the cause either way, with the pipeline link.

## quiet

Nothing to do; `triage.json` keeps the list.
