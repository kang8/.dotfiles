---
name: rebase
description: Rebase the current branch onto a freshly fetched remote base (default its MR's target, else origin's default branch), resolve conflicts, and stop before pushing.
argument-hint: '[target ref, e.g. origin/master]'
disable-model-invocation: true
---

## Step 1: Sanity check

Run in parallel:

- `git status --short --branch`
- `ls -d "$(git rev-parse --git-path rebase-merge)" "$(git rev-parse --git-path rebase-apply)" 2>/dev/null`
  (prints a path only mid-rebase)
- `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true`

**Bail (touch nothing)** on a dirty working tree, a rebase already in progress
(ask: continue or abort?), or the **default branch** checked out
(`origin/HEAD`'s branch, else `master`/`main`).

## Step 2: Pick and fetch the target

The target is the first of:

1. The argument.
2. The target branch of the branch's open MR/PR
   (`glab mr list --source-branch <branch> -F json` → `.target_branch`, or
   `gh pr view --json baseRefName`).
3. The default branch.

A target other than the default branch makes this a **stacked** branch: read
[`stack.md`](stack.md) before Step 3.

Fetch the target as its own command, and read `<remote>/<branch>` only after it
exits 0: a failed fetch leaves the ref **stale**.

```bash
git fetch <remote> <branch>
```

## Step 3: Rebase and resolve

Record `git rev-parse HEAD` as `OLD_HEAD`, the **recovery point**.

List the files the rebase will rewrite that the sandbox write-denies. The probe
asks the sandbox directly: it opens an existing file for writing without
changing it, and for a file only the target has, it creates and removes the
first missing path component:

```bash
git diff --name-only -z HEAD <target> | xargs -0 python3 -c '
import os, sys
for p in sys.argv[1:]:
    try:
        if os.path.lexists(p):
            open(p, "rb+").close()
            continue
        q = p
        while not os.path.lexists(os.path.dirname(q) or "."):
            q = os.path.dirname(q)
        if q == p:
            os.close(os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL))
            os.remove(p)
        else:
            os.mkdir(q)
            os.rmdir(q)
    except PermissionError:
        print(p)'
```

Any output means the sandbox will deny the checkout midway
(`unable to unlink old`) and leave a half-written tree: run every `git rebase`
call of this run, `--continue` included, unsandboxed from the start.

Run `git rebase <target>`, or the command from `stack.md` for a stacked branch.
When git reports the branch is up to date, report that and stop. At each
conflict stop, list the files (`git diff --name-only --diff-filter=U`) and read
both sides' **intent**: the upstream commits on the file
(`git log --oneline OLD_HEAD..<target> -- <file>`) and the commit being replayed
(`git log -1 REBASE_HEAD`).

- **Lockfile** (`uv.lock`, `pnpm-lock.yaml`, ...): `git checkout --ours <file>`
  (mid-rebase, "ours" is upstream), then regenerate with the project's lock
  command to re-apply the branch's dependency changes.
- **Copy**: the replayed commit's subject matches a commit in
  `OLD_HEAD..<target>`, such as the old copy of a rewritten parent commit. Show
  both, and ask before `git rebase --skip`.
- **Intents compatible**: merge by hand, keeping both changes.
- **Intents clash or unclear**: stop mid-rebase, show the hunk and both commits,
  and let the user pick `--abort`, `--skip`, or a resolution.

`git add` and `git rebase --continue`. Done when every conflict is either
resolved with a one-line reason or handed to the user.

## Step 4: Verify

`git range-diff <target> OLD_HEAD HEAD`: `=` rows are unchanged, each `!` row
differs only at a resolved conflict, and each `<` row is a dropped commit
(already upstream, an old parent copy, or skipped).

## Step 5: Report

- Target and where it came from (argument, MR link, or default branch).
- Old → new HEAD, and upstream commits picked up.
- Each dropped commit and why.
- Each resolved conflict: file and reason.
- Divergence from the branch's remote (`git status -sb`); publishing needs
  `git push --force-with-lease`, which the user runs.
- Recovery: `git reset --hard <OLD_HEAD>`.
