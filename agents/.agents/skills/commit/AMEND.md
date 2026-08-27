# Amend mode

Reached from Step 0 of `SKILL.md` when the argument starts with `amend`. Fold
the staged changes into `HEAD` and rewrite its message. No branch is created.

## 1 — Read the commit you are rewriting

Run Step 1's commands, plus:

- `git log -1 --format=%B` — the message you are replacing
- `git show --stat --format= HEAD` — what the commit already carries

An empty staged diff is fine here, unlike in Step 1: it means a reword.

`amend` names a destination — the change lands in `HEAD` — and no state of
`HEAD` overrides it. A merge commit amends as cleanly as any other, and the
reflog keeps the commit you replaced.

Never offer a separate follow-up commit as the safer alternative to rewriting.
The user picked the destination; a second commit is a different history than the
one they asked for.

## 2 — Name the shape

Git's rebase verbs already name the three ways an amend lands. Pick one: it
decides how much of the old message survives, and you report it by name.

| Shape      | Staged change                | Message                                                                                         |
| ---------- | ---------------------------- | ----------------------------------------------------------------------------------------------- |
| **fixup**  | corrects the previous commit | subject stands; the commit reads as if the bug was never there                                  |
| **squash** | broadens the commit's scope  | subject widens to cover both, or the shared purpose moves up and the specifics drop to the body |
| **reword** | nothing staged               | wording, scope, or accuracy only — no new facts                                                 |

The shape names your report, not the commit message.

## 3 — Write the message

Apply Step 4's style rules, then write the amended commit as one coherent change
rather than two events stitched together.

Rank your sources: the staged diff and `git show --stat HEAD` are ground truth
for what the commit will contain; the old message supplies the parts still
accurate; any words after `amend` carry the user's intent, which a forked run
has no other way to see.

The message describes the final state of the change, as if it had been written
that way the first time.

## 4 — Amend

```bash
git commit --amend -m "$(cat <<'EOF'
<rewritten message here>
EOF
)"
```

Let the hooks and the signing run. When a pre-commit hook fails, fix it and
re-run the same `git commit --amend`, keeping the history one commit deep.

## 5 — Report

- The shape — **fixup**, **squash**, or **reword** — and old → new short SHA
- The rewritten message, and one line on how it differs from the old one

If a permission rule blocks `git commit --amend`, say that plainly and let the
user run it themselves.
