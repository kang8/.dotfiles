---
name: upstream-pr
description: Contribute a change to a GitHub repo we do not own — working in a clone under ~/github/<repo> and stopping at a local commit, so the user publishes it themselves. Use when the user wants to send a fix upstream to an open-source project, or hits a bug in a dependency of one of their own projects.
---

You are preparing a contribution to a repository **we do not own**.

**The clone is the boundary.** Your work lands inside `~/github/<repo>`;
everything that lands on GitHub — the fork included — belongs to the user, and
Step 7 hands it over.

## Step 0 — Confirm the repo is not the user's

If the change belongs in a repo the user owns, this skill does not apply.

When the fix surfaced while working in one of their projects — a bug in a
dependency, a wrong type, a missing option — the two tracks stay separate: the
upstream change goes here, and any workaround they need meanwhile goes in their
own source, never in vendored or installed dependency code.

## Step 1 — Locate or create the clone

Look for an existing clone first — the user often has one, sometimes under a
directory name that differs from the repo name:

```bash
ls -d ~/github/<repo> 2>/dev/null
ls -d ~/github/*<partial-name>* 2>/dev/null
```

If nothing turns up, clone it. A plain clone: a fork would create a public repo
under the user's account, which is theirs to create.

```bash
gh repo clone <owner>/<repo> ~/github/<repo>
```

### Reusing an existing clone

An existing clone carries state. Inspect it before touching anything:

```bash
git -C <clone> remote -v
git -C <clone> status --short --branch
git -C <clone> log --oneline -5
```

- **Uncommitted changes, or an unfamiliar branch** → stop and ask. It may be the
  user's own work-in-progress on this very fix; leave it exactly as found.
- **Which remote holds the upstream repo** → `upstream` if they have contributed
  before, `origin` in a plain clone. Later steps write `<upstream-remote>` for
  whichever it is. A clone with no fork is fine — the fork belongs to the push.

Then refresh:

```bash
git -C <clone> fetch --all --prune
git -C <clone> remote set-head origin --auto   # refresh origin/HEAD if stale
```

Done when you can name the clone path and the upstream remote, and the worktree
is clean.

## Step 2 — Learn the house style

The project's conventions govern Steps 3, 4, and 6. Gather them before writing
any code.

Read whichever exist: `CONTRIBUTING.md`, `.github/CONTRIBUTING.md`,
`.github/PULL_REQUEST_TEMPLATE.md`, `AGENTS.md`, `CLAUDE.md`, and the README's
development section. Run `git log --oneline -20` for the commit-message style.

Done when you can state in one line each: the commit-message format, how the
tests run, and whether a CLA, DCO sign-off, linked issue, or changeset file is
required. Surface those last ones to the user — they need the user's action, not
yours.

## Step 3 — Branch

Every commit lands on a fresh branch cut from the upstream default:

```bash
BASE=$(git -C <clone> symbolic-ref --short refs/remotes/<upstream-remote>/HEAD)
git -C <clone> switch --create <branch> "$BASE"
```

Name it in the house style if the history shows one; otherwise kebab-case
describing the fix.

## Step 4 — Make the change, surgically

A **surgical** diff is one a maintainer merges in a single read: every line in
it traces to the fix. Incidental reformatting, unrelated lint fixes, and
dependency bumps are the most common reason a small PR stalls.

Write in the house style, even where it differs from the user's own preferences.
Where the project has a test suite, the change arrives with a test.

Done when `git diff` holds no line you could not justify to the maintainer.

## Step 5 — Verify locally

Run the project's own checks, inferred from its manifest and CI config
(`package.json` scripts, `Makefile`, `justfile`, `.github/workflows/`) —
typically some combination of build, test, lint, and typecheck.

Check any failure against the unmodified base commit before reporting it: a
pre-existing failure is worth naming, but is not yours to fix.

Done when every check has run and its real output is reported — nothing skipped,
nothing called passing without the output to show.

## Step 6 — Commit

The house style governs the message, not the user's own repo conventions. Write
it as the maintainer would read it: what changed and why. Keep agents, AI, and
Claude out of it, and add `Co-Authored-By` only if the user asks. Add a DCO
`Signed-off-by` only where Step 2 found the project requires one.

## Step 7 — Hand off

Your work ends at the commit. The fork, the push, and the PR are the user's, and
they have not asked to be prompted about them — the hand-off is a report, not a
question.

Report:

- Clone path, branch name, commit SHA and subject, diff stat.
- The Step 5 output.
- Whatever Step 2 turned up that needs them: CLA, linked issue, changeset.
- Any workaround still sitting in one of their own projects, to revert once the
  upstream fix ships.

Then the commands, filled in with the real names:

```bash
cd <clone>
gh repo fork --remote        # only if no fork yet; renames origin -> upstream
git push --set-upstream origin <branch>
gh pr create --repo <owner>/<repo> --web
```

Draft the PR title and body too — following the project's template where it has
one — and include them in the report as text the user can paste.
