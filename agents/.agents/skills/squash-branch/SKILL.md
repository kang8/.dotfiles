---
name: squash-branch
description: Squash every commit on the current branch into one, synthesizing a fresh commit message from the combined diff and the original commit messages. Stops after the local squash so the user can force-push themselves. Use when the user says "squash this branch", "fixup these commits", "/squash-branch", or similar.
disable-model-invocation: true
---

You are collapsing every commit on the current branch into a single commit.
After the local squash you stop — the user pushes themselves.

## Step 1 — Sanity check

Run in parallel:

- `git status --short`
- `git rev-parse --abbrev-ref HEAD`
- `git rev-parse --abbrev-ref @{upstream} 2>/dev/null || true`
- `git log --oneline -10`

**Bail (touch nothing) if any of these is true:**

- `git status --short` is non-empty → tell the user to commit or stash first.
- Current branch is `master` or `main` → there is nothing to squash to.

## Step 2 — Determine the squash base

Pick the first option that resolves:

1. `@{upstream}` exists → `BASE=$(git merge-base HEAD @{upstream})`
2. Local `master` exists → `BASE=$(git merge-base HEAD master)`
3. Local `main` exists → `BASE=$(git merge-base HEAD main)`
4. Otherwise → ask the user which branch to squash against. Do not guess.

Then check `git rev-list --count "$BASE"..HEAD`:

- `0` → already on base, nothing to squash, stop.
- `1` → only one commit on this branch, nothing to squash, stop.

## Step 3 — Read context for the message

Run in parallel:

- `git diff --stat "$BASE"..HEAD`
- `git diff "$BASE"..HEAD`
- `git log "$BASE"..HEAD --format='%h %s%n%n%b%n---'`
- `git log --oneline -10 "$BASE"` — to learn the project's commit-message style
  (conventional-commits prefix? trailing period? capitalization?)

## Step 4 — Draft the squashed commit message

- Describe the **final state** the combined diff produces, not the chronology of
  the individual commits. Reviewers care what the branch _adds_, not the path it
  took.
- Use the original commit messages as input — especially the first commit's
  framing of the feature — but do not concatenate them. Carry forward only the
  parts still true of the final diff.
- Match the wording, capitalization, and trailing-period (or not) of the last
  ~10 commits on the base branch.
- 1–2 sentences for the subject. Add a body paragraph or two only when the
  change is non-trivial and the _why_ is non-obvious.
- Do **not** mention agents, AI, or Claude. Do **not** add `Co-Authored-By`
  lines unless the user asks.

## Step 5 — Squash and commit

```bash
git reset --soft "$BASE"
git commit -m "$(cat <<'EOF'
<message here>
EOF
)"
```

Never use `--no-verify`, `--no-gpg-sign`, `--amend`, or
`-c commit.gpgsign=false`. If a pre-commit hook fails, investigate and fix the
underlying issue, then try the commit again — do not bypass the hook.

## Step 6 — Handle the gpg-in-sandbox failure

If the commit fails with output like `gpg: ... Operation not permitted` on paths
under `~/.gnupg/`:

- This is the Claude Code sandbox blocking gpg from reaching its keyring, not a
  real gpg failure. Briefly tell the user, mention that they can use `/sandbox`
  to manage restrictions, and retry the exact same `git commit` command **once**
  with the Bash tool's `dangerouslyDisableSandbox: true` parameter.
- Any other gpg failure (no signing key configured, expired key, wrong key id,
  etc.) → surface the error to the user. Do not silently disable signing.

## Step 7 — Report and stop

Run `git log --oneline "$BASE"..HEAD` and `git status -sb` to confirm.

Tell the user:

- The new commit SHA and one-line subject.
- The combined diff stat.
- How far local now diverges from the remote (e.g. `1 ahead, 4 behind` of
  `origin/<branch>`).
- A one-line reminder that publishing requires `git push --force-with-lease`
  when they are ready.

Do **not** push. Do **not** ask about pushing — the user has chosen to publish
themselves.
