---
name: sync-master
description: Fast-forward local master to origin/master in every primary checkout under ~/Projects, leaving branches, worktrees, and uncommitted work as found.
argument-hint: '[--dry-run] [repo ...]'
disable-model-invocation: true
---

[`scripts/sync_master.py`](scripts/sync_master.py) holds every safety rule: it
only fast-forwards, and it skips a repo whenever moving `master` could touch
local work. Run it, handle what it skips for the sandbox, and report.

## Step 1: Run the script

Pass the skill's arguments through (`--dry-run`, repo names):

```bash
python3 -I ~/.claude/skills/sync-master/scripts/sync_master.py [args]
```

It fetches `origin master` in each primary checkout (a directory whose `.git` is
a directory) and prints one row per repo:

| status                   | meaning                                                                                               |
| ------------------------ | ----------------------------------------------------------------------------------------------------- |
| `ref-updated`            | `master` not checked out anywhere; only the ref moved                                                 |
| `ff-merged`              | the worktree holding `master` fast-forwarded; `kept N local change(s)` and `new-untracked` may follow |
| `up-to-date`             | nothing to do                                                                                         |
| `skip-diverged`          | local `master` has commits origin lacks; lists them                                                   |
| `skip-overlap`           | uncommitted paths collide with incoming changes                                                       |
| `skip-busy`              | a rebase, merge, or cherry-pick is in progress                                                        |
| `skip-sandbox`           | the sandbox would deny writing the listed paths mid-checkout                                          |
| `fetch-failed`, `failed` | error text in the detail column                                                                       |

## Step 2: Retry sandbox skips

For `skip-sandbox` rows, show the denied paths and ask whether to rerun those
repos unsandboxed. On a yes, run Step 1 again with just those repo names and the
sandbox disabled. The script's own probe then passes and it fast-forwards.

## Step 3: Report

Group rows by outcome, with repo names in each group. Spell out:

- **`new-untracked`**: usually files the old tree ignored that survived an
  upstream move or deletion (`node_modules`, `.next`). Name the upstream commit
  (`git log --oneline -1 <old>..<new> -- <path>`), and leave deletion to the
  user.
- **`skip-diverged`**: the local-only commits with dates. Syncing needs a reset
  or a merge commit; offer a backup branch plus reset per repo.
- **`skip-overlap`**: the colliding paths.
- **`fetch-failed`**: the likely cause (missing access, an HTTPS remote with no
  credentials).

Done when every row is in the report. Every skipped repo stays untouched until
the user decides, so the report ends with the options for each.
