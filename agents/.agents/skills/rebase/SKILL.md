---
name: rebase
description: Rebase the current branch onto a freshly fetched remote base (default origin's default branch), resolve conflicts, and stop before pushing.
argument-hint: '[target ref, e.g. origin/master]'
disable-model-invocation: true
---

You are replaying the current branch onto a freshly fetched base, then handing
it back unpushed.

## Step 1: Sanity check

Run in parallel:

- `git status --short --branch`
- `ls -d "$(git rev-parse --git-path rebase-merge)" "$(git rev-parse --git-path rebase-apply)" 2>/dev/null`
  (prints a path only mid-rebase)
- `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true`

**Bail (touch nothing)** on a dirty working tree, a rebase already in progress
(ask: continue or abort?), or `master`/`main` checked out.

## Step 2: Fetch the target

The target is the argument, else `origin/HEAD`'s branch, else `origin/master`,
else `origin/main`. Fetch that one ref as a standalone command:

```bash
git fetch <remote> <branch>
```

A failed fetch leaves `<remote>/<branch>` **stale**, so nothing reads it until
the fetch exits 0. `Connection to UNKNOWN port 65535: Broken pipe` is the
sandbox blocking SSH with no violation report: retry once unsandboxed.

## Step 3: Snapshot

- `git rev-parse HEAD` → `OLD_HEAD`, the **recovery point**
- `git rev-list --count HEAD..<target>` → upstream commits to pick up; `0` means
  already current: report and stop
- `git log --oneline <target>..HEAD` → the branch's own commits

## Step 4: Rebase and resolve

Run `git rebase <target>`. At each conflict stop, list the files
(`git diff --name-only --diff-filter=U`) and read both sides' **intent**: the
upstream commits on the file (`git log --oneline OLD_HEAD..<target> -- <file>`)
and the commit being replayed (`git log -1 REBASE_HEAD`).

- **Lockfile** (`uv.lock`, `pnpm-lock.yaml`, ...): `git checkout --ours <file>`
  (mid-rebase, "ours" is upstream), then regenerate with the project's lock
  command to re-apply the branch's dependency changes.
- **Intents compatible**: merge by hand, keeping both changes.
- **Intents clash or unclear**: stop mid-rebase, show the hunk and both commits,
  and let the user pick `--abort`, `--skip`, or a resolution.

`git add` and `git rebase --continue`. Done when every conflict is either
resolved with a one-line reason or handed to the user.

## Step 5: Verify

- `git rev-list --count <target>..HEAD` matches the Step 3 branch commit count;
  name any commit that went missing (dropped as empty, or skipped).
- After any resolution, `git range-diff <target> OLD_HEAD HEAD`: `=` rows are
  unchanged, and each `!` row differs only at a resolved conflict.

## Step 6: Report

- Old → new HEAD, and upstream commits picked up.
- Each resolved conflict: file and reason.
- Divergence from the branch's remote (`git status -sb`); publishing needs
  `git push --force-with-lease`, which the user runs.
- Recovery: `git reset --hard <OLD_HEAD>`.
