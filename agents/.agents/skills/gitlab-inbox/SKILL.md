---
name: gitlab-inbox
description: Morning GitLab inbox — triage review requests and my MRs, fan reviews out to herdr panes, decide per finding in a local web console, then draft, approve and merge.
argument-hint: '[optional focus, e.g. "only <repo>"]'
disable-model-invocation: true
---

Work the user's GitLab inbox in one pass. Scripts live in
`~/.agents/skills/gitlab-inbox/scripts/`; the day's **session** directory is
`~/Projects/.gitlab-inbox/<YYYY-MM-DD>/` and `state.json` beside it remembers,
per MR, the head the user last decided on. Reply to the user in Chinese, times
as `HH:MM (UTC+8)`, and link every MR.

The user's judgement is the scarce resource: spend it only on findings, tone and
merges. Everything mechanical (fetching, anchoring, re-checking, executing) is
yours.

## 1. Triage

```bash
python3 ~/.agents/skills/gitlab-inbox/scripts/triage.py
```

It writes `<session>/triage.json` and prints the actionable buckets:

| bucket                 | meaning                                           | route                   |
| ---------------------- | ------------------------------------------------- | ----------------------- |
| `review/new`           | never decided, active in the last 7 days          | review set              |
| `review/updated`       | code changed since my decision (patch-id differs) | review set              |
| `review/updated_notes` | same code, new notes from others                  | review set              |
| `review/rebased`       | rebased only, same patch                          | console as approve-only |
| `mine/*`               | my MRs                                            | step 5                  |
| `mentions`             | @-mentions on MRs outside the buckets             | list for the user       |

Counts-only buckets (`draft`, `stale`, `backlog`, `approved`, `reviewed`,
`mine/quiet`) stay in the JSON. Show the user a short table of the actionable
buckets, then go on. Ask which MRs to take only when the review set exceeds 12,
or when the user's argument narrows the scope.

Done when every actionable item has a route.

## 2. Review in herdr panes

Requires `HERDR_ENV=1`; outside herdr, say so and stop. Read
[`review-brief.md`](review-brief.md) for the prompt.

1. Group the review set by repo. One pane takes up to 4 MRs of one repo or about
   600 changed lines; a larger MR gets a pane alone. At most 4 panes.
2. Split from the caller pane
   (`herdr pane split --current --direction right --no-focus`, then `down` on
   the new pane) with `--cwd` set to the repo checkout `~/Projects/<repo>`, and
   start `herdr agent start rv-<n> --kind claude --pane <id>`. For an MR from
   `review/updated` or `review/updated_notes`, write its brief line as
   `group/repo!iid since <reviewed_sha>, earlier review <state.session>/reviews/<slug>.json`
   (both from `state.json`).
3. Send each its brief with `herdr agent prompt rv-<n> "<brief>"` (no `--wait`,
   so they run together), then `herdr agent wait` each. A `blocked` agent: read
   it with `herdr agent read`, ask the user.
4. Write `<session>/reviewers.json`:
   `{"rv-<n>": {"session": <herdr agent get … .agent_session.value>,
   "cwd": <repo dir>, "mrs": ["group/repo!iid", …]}}`.
5. For each `review/rebased` MR write `reviews/<slug>.json` yourself:
   `reviewed_sha` = current head, `verdict: "approve"`,
   `summary: "仅 rebase，改动与上次决定时一致"`, no findings.
6. Check every **blocking** finding yourself against the cited code before it
   reaches the user; correct `blocking` / `verified`, or drop it with a reason.
7. Close the reviewer panes.

Done when every MR in the review set has a `reviews/<slug>.json` that parses,
and every blocking finding carries your own check.

## 3. Console

```bash
python3 ~/.agents/skills/gitlab-inbox/scripts/build_session.py
```

Start the server in a **fresh** herdr pane (it binds a port and calls `claude`,
neither of which works in the sandbox), and wait on its own marker:

```bash
p=$(herdr pane split --current --direction down --cwd "$HOME" --no-focus | jq -r .result.pane.pane_id)
herdr pane run "$p" "python3 ~/.agents/skills/gitlab-inbox/scripts/console_server.py <session>"
herdr pane wait-output "$p" --regex '(?m)^gitlab-inbox console ready' --timeout 15000
```

Open `http://127.0.0.1:8765/?variant=A` with `open` from a second short-lived
pane, then close that pane. Tell the user how many MRs and findings wait, and
that `B` / `C` are other layouts. In the console they read each finding against
its code, ask follow-ups about a finding or the whole MR, rewrite drafts, draft
an MR-level comment to the author, re-check findings the console flags as
changed, and press **提交决定**, which writes `<session>/decisions.json`.
Nothing is pre-selected (the reviewer's lean shows as a dashed hint); an MR with
any undecided item, or one marked 暂缓, is skipped by execute and returns at the
next triage. Page state lives in the browser's localStorage, so restarting the
server is safe.

Done when the user says they submitted and `decisions.json` has a `saved_at`
newer than the server start.

## 4. Execute

```bash
python3 ~/.agents/skills/gitlab-inbox/scripts/execute.py
```

It skips any MR whose head moved since the decision (`⛔`), creates the drafts
(inline via `gitlab-mr-review/post_review.py`, replies via
`in_reply_to_discussion_id`), approves and merges with `?sha=`, and records
`state.json`. Report one line per MR. Send `⛔` MRs back to the console
(refresh, re-check, resubmit, re-run). End with the `! … bulk_publish` line the
script prints: publishing is the user's keystroke.

Done when every MR in `decisions.json` has a result line.

## 5. Own MRs

Read [`own-mrs.md`](own-mrs.md) and work each `mine/*` bucket. Done when each
item is handled or handed to the user with the exact next action.

## 6. Wrap up

Close the console pane once the user is finished, and list what is still theirs:
unpublished drafts, threads awaiting their reply, mentions.

## Gotchas

- The sandbox cannot reach `127.0.0.1`: test the console with `curl` from a
  herdr pane.
- `bulk_publish` is blocked for the agent by a hook whatever the user's wording;
  always hand over the `!` line.
- In zsh, write `${var}` before a colon (`$t:t`, `$B:r` are modifiers), and pipe
  JSON straight into `jq` (`echo` expands `\n` inside JSON strings).
- `herdr pane wait-output` also matches old scrollback; wait in a fresh pane or
  on a marker printed once.
- Node CLIs ignore the sandbox proxy: prefix `NODE_USE_ENV_PROXY=1`.
