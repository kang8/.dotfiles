---
name: commit
description: Commit staged changes using the project's conventions, branching first when its workflow calls for it. Pass "amend" to fold them into the previous commit instead.
disable-model-invocation: true
argument-hint: '[amend [intent]]'
context: fork
agent: general-purpose
---

> Runs in a forked subagent (background) on the skill body alone — the live
> conversation is not inherited. Everything you need comes from git, the active
> CLAUDE.md files, or `$ARGUMENTS`. When a ticket id or branching hint isn't
> discoverable there, say so in the final report rather than asking.

You are creating a git commit from currently staged changes, following the
active project's conventions.

## Step 0 — Route on the argument

- **Empty** → carry on with Step 1.
- **Starts with `amend`** → read `AMEND.md` in this skill's directory and follow
  it instead; it replaces every step below. Any words after `amend` are the
  user's intent for the rewrite.
- **Anything else** → report the argument as unrecognised, name the two accepted
  forms, and stop.

## Step 1 — Sanity check staged changes

Run in parallel:

- `git status`
- `git diff --staged`
- `git log --oneline -10`
- `git rev-parse --abbrev-ref HEAD`

Commit exactly what is already staged — the user decides what goes in. If
`git diff --staged` comes back empty, report that nothing is staged and stop.

## Step 2 — Decide if a branch must be created

Two workflows, and the recent history on the default branch tells you which one
this repo runs:

- **PR workflow** — dominated by merge commits like
  `Merge branch 'feature/...' into 'master'`. Branch before committing.
- **Trunk-based** — a stream of direct commits with no merge-from-feature
  pattern. Commit straight to it.

Two overrides beat the history:

1. An active CLAUDE.md that forbids direct commits to `main`/`master`, or
   mandates a `feature/`/`bugfix/` prefix.
2. Already on a non-default branch → commit there, without branching again.

When the history reads ambiguously, treat the repo as PR workflow — branching is
the recoverable mistake.

## Step 3 — If branching: choose name and create

- **Prefix**: `bugfix/` for a clear bug fix, `feature/` otherwise. Reach for
  another prefix only when the active CLAUDE.md names it.
- **Ticket**: use a ticket id you actually find (Jira-style — uppercase letters,
  a dash, digits, e.g. `PROJ-123`) in the current branch name, the recent
  `git log`, or `$ARGUMENTS`. Found none → omit the segment and say so in the
  report.
- **Slug**: 3-7 lowercase kebab-case words naming what the change _does_.
- **Full format**: `<prefix>/<TICKET>-<slug>`
  - `feature/PROJ-123-add-dark-mode-toggle` — verb-first, describes the action
  - `feature/PROJ-123-userservice-changes` — names a file, not the change
  - `feature/PROJ-123-misc-cleanup` — vague, carries no information

Create with `git checkout -b <branch>`, and leave existing branches intact.

## Step 4 — Draft the commit message

- Match the wording, capitalization, and verb tense of the last ~10 commits on
  this repo, down to whether they end with a period.
- Lead with **what changed and why** — `git show` already lists the files.
- 1-2 sentences for the subject. For a non-trivial change, add a blank line and
  a body covering the _why_ and any non-obvious tradeoffs.
- Describe only what is staged.
- Write it as the user would: no mention of agents, AI, or Claude, and no
  `Co-Authored-By` line unless they ask for one.

## Step 5 — Commit

Pass the message via HEREDOC so multi-line formatting survives:

```bash
git commit -m "$(cat <<'EOF'
<message here>
EOF
)"
```

Let the hooks and the signing run: `--no-verify`, `--amend`, `--no-gpg-sign`,
and `-c commit.gpgsign=false` are the user's call, not yours. When a pre-commit
hook fails, investigate it and put the fix in a **new** commit.

## Step 6 — Verify and report

Run `git status` to confirm the commit landed and to read the working tree
state.

Return a concise final report — this is the subagent's result, surfaced back to
the main conversation:

- Short SHA, and the branch name if you created one
- Any ticket id you could not determine, or a branch/no-branch judgement call
  worth confirming
- That the commit is **unpushed** — the push is the user's call

Leave pull and merge requests to an explicit request.
