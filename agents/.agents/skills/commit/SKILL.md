---
name: commit
description: Commit currently staged changes following the project's conventions. Decides automatically whether a feature/bugfix branch is needed based on the project's commit workflow inferred from CLAUDE.md instructions and recent git history. Use when the user says "commit", "/commit", or asks to commit + (optionally) branch.
disable-model-invocation: true
context: fork
agent: general-purpose
---

> Runs in a forked subagent (background). The subagent receives this skill
> content as its prompt but **not** the live conversation, so it cannot rely on
> chat history. If a ticket id or branching hint isn't discoverable from git or
> CLAUDE.md, surface that in the final report instead of blocking on a question.

You are creating a git commit from currently staged changes, following the
active project's conventions.

## Step 1 — Sanity check staged changes

Run in parallel:

- `git status`
- `git diff --staged`
- `git log --oneline -10`
- `git rev-parse --abbrev-ref HEAD`

If `git diff --staged` is empty → tell the user there is nothing staged and
stop. **Do not stage anything yourself.** The user controls what goes into the
commit.

## Step 2 — Decide if a branch must be created

A branch is required if **any** of these is true:

1. The active CLAUDE.md files (loaded into the session) explicitly forbid direct
   commits to `main`/`master` or mandate a `feature/`/`bugfix/` prefix.
2. The current branch is `main` or `master` AND the recent `git log` on that
   branch is dominated by merge commits like
   `Merge branch 'feature/...' into 'master'` (i.e. PR/MR workflow).

A branch is NOT required if:

- You are already on a non-default branch (just commit there, do not branch off
  again).
- The project clearly commits directly to `main`/`master` — recent history on
  the default branch is a stream of direct commits with no merge-from-feature
  pattern, AND no CLAUDE.md rule forbids it.

When in doubt, lean toward creating a branch — it is the safer default.

## Step 3 — If branching: choose name and create

Branch naming:

- **Prefix**: `bugfix/` only if the change is clearly a bug fix; otherwise
  `feature/`. Other prefixes (`chore/`, `refactor/`, `hotfix/`, etc.) are **not
  allowed** unless the active CLAUDE.md explicitly permits them.
- **Ticket**: look for a ticket id (Jira-style format: uppercase letters, a
  dash, then digits, e.g. `PROJ-123`) in the current branch name, the recent
  `git log`, or any ticket id passed in as an argument. Do not guess and do not
  invent one. If none can be found, omit the ticket segment and note in the
  final report that a ticket id could not be determined — do not block waiting
  for an answer (this skill runs in a forked subagent and cannot ask mid-run).
- **Slug**: a short kebab-case description derived from the staged diff (3-7
  words, lowercase, dashes between words, no punctuation). Aim for what the
  change _does_, not what file it touches.
- **Full format**: `<prefix>/<TICKET>-<slug>`
  - Good:
    - `feature/PROJ-123-add-dark-mode-toggle` (verb-first, describes action)
    - `bugfix/PROJ-124-fix-login-redirect-loop` (verb-first, describes fix)
  - Avoid:
    - `feature/PROJ-123-userservice-changes` (names a file, not the change)
    - `feature/PROJ-123-misc-cleanup` (vague, no information)
    - `chore/PROJ-123-...` (prefix not in `feature`/`bugfix`)

Create with `git checkout -b <branch>`. Never `git branch -D` or otherwise
destroy existing branches.

## Step 4 — Draft the commit message

- Match the wording, capitalization, and verb tense of the last ~10 commits on
  this repo. If they end with a period, end yours with a period; if they don't,
  don't.
- Lead with **what changed and why**, not what files were touched (`git show`
  already lists files).
- 1-2 sentences for the subject. If the change is non-trivial, add a blank line
  and a short body explaining the _why_ and any non-obvious tradeoffs.
- Do **not** mention agents, AI, or Claude. Do **not** add `Co-Authored-By`
  lines unless the user asks.
- Do **not** reference unstaged changes — only describe what is actually staged.

## Step 5 — Commit

Always pass the message via HEREDOC for correct multi-line formatting:

```bash
git commit -m "$(cat <<'EOF'
<message here>
EOF
)"
```

Never use `--no-verify`, `--amend`, `--no-gpg-sign`, or
`-c commit.gpgsign=false` unless the user explicitly asks. If a pre-commit hook
fails, investigate the failure and create a **new** commit with the fix — never
amend.

## Step 6 — Verify and report

Run `git status` to confirm the commit succeeded and the working tree state.

Return a concise final report (this is the subagent's result, surfaced back to
the main conversation) covering:

- The new branch name (if created) and short SHA of the commit
- Any ticket id that could not be determined, or any branch/no-branch judgement
  call worth confirming
- A note that the commit has **not** been pushed — never auto-push, and never
  block waiting to ask; leave the push decision to the user in the main
  conversation

Do **not** create a pull/merge request unless explicitly asked.
