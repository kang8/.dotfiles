---
name: gitlab-review-followup
description: Follow up on review threads on your own GitLab MR — fetch the open threads, make the changes, draft one reply per thread. Use when a reviewer has commented on an MR you authored ("review 意见来了").
---

You are the MR's author answering a reviewer. Done means every open **thread**
has a verdict, the change it calls for (or a reasoned pushback), and a reply
draft the user can post.

## 1. Fetch the threads

```bash
~/.agents/skills/gitlab-review-followup/fetch_threads.sh [mr-iid | mr-url]
```

With no argument it uses the current branch's MR. It prints the unresolved,
non-system threads, each with its `url`, anchor (`path`, `line`, `head_sha`) and
every note in order. If no MR is found, ask for the iid.

- `waiting_on_reviewer: true` means the user spoke last — list these as waiting
  and leave them alone.
- Run `git status --short --branch` and compare `HEAD` with the MR's head. A
  local branch behind the remote is something to raise before editing.

## 2. Judge every thread

Read the whole thread: a reviewer's follow-up note supersedes their opener. The
anchor line belongs to `head_sha`, and the user amends and squashes, so on a
moved branch read `git show <head_sha>:<path>` and find the same code in `HEAD`
before trusting the line number.

Verify each claim against the code and against every link the reviewer cites
(blob URLs pinned to a sha, other MRs, docs) — open them, with `glab api` for
GitLab URLs. Conclude **agree**, **partly** or **disagree**; a reviewer can be
wrong, and a technically grounded pushback is a valid outcome.

Look for a shared root. Threads posted together often name one underlying
problem from different angles (one rule restated in three places, one definition
several sections disagree with). Fix the root once and let each reply point at
it.

Show the user a numbered table — #, author, `path:line`, the ask in one line,
verdict, planned change — then implement the agreed threads. For **partly** and
**disagree**, give your reasoning and wait for the user's call on those.

## 3. Change

Scope every edit to a thread; a cleanup no thread asked for belongs in its own
change. Run the repo's verification loop from its `AGENTS.md` / `CLAUDE.md` and
report failures with their output.

## 4. Draft the replies

One reply per thread, in the thread's language, headed by its `url` from the
fetch output. The user's own reply shape:

```
已改，见 535ab813。

只把 values、启动参数和 CRD 算作 call site 还不够：#294 里 operator 0.160.0
的 breaking change 是 NetworkPolicy 改为默认关闭，connector 的 values 没设置
这一项，grep 不到，照样会判 low。……
```

- Open on the outcome: `已改，见 <sha>。`, `已删。`, or the pushback verdict.
  Leave `<sha>` as a placeholder until the commit exists.
- Add a paragraph only where the change departs from or goes beyond what the
  reviewer proposed, saying why.
- A pushback follows "Comment shape" in
  `~/.agents/skills/gitlab-mr-review/SKILL.md`: verdict, then the single most
  fundamental reason.

## 5. Commit and post, on the user's word

Ask whether to fold the changes into the existing commit or add a new one, then
follow the `commit` skill. Once the commit is pushed, fill in `<sha>`.

Offer to post the replies as **draft notes**, visible only to the user until
they submit the review in the MR page:

```bash
glab api -X POST "projects/:fullpath/merge_requests/<iid>/draft_notes" \
  -f in_reply_to_discussion_id=<thread id> -F note=@"$TMPDIR/reply-1.md"
```

Read them back with
`glab api "projects/:fullpath/merge_requests/<iid>/draft_notes"`: each draft's
`discussion_id` must equal its thread's `id`; a `null` means the reply landed as
a new top-level comment. Leave resolving the threads to the reviewer, and
publish (`draft_notes/bulk_publish`) only when the user asks.
