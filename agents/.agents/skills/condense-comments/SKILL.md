---
name: condense-comments
description: Shorten long code comments to their smallest useful form, and delete the ones carrying nothing. Use when asked to condense, shorten, trim, or simplify comments, or via `/condense-comments [<path>|all]`.
---

# Condense Comments

Most comments an agent writes are three times longer than they need to be.
Rewrite them short. Delete only what survives no rewrite.

## Invocation

| Command                     | Scope                                                                         |
| --------------------------- | ----------------------------------------------------------------------------- |
| `/condense-comments`        | Comments in the working-tree diff against `HEAD` — what was just written.     |
| `/condense-comments <path>` | Every comment under that file or directory.                                   |
| `/condense-comments all`    | Every comment in the repo's own source (skip vendored, generated, lockfiles). |

Default to the diff. It is where verbose comments are freshest and least
reviewed.

## The two tests

Apply in order to each comment:

1. **Delete test** — if this comment were gone, would the next person write the
   same code? Yes → delete it.
2. **Line test** — what is the one sentence that survives? Everything else goes.

## Cut

- **Openers that restate the signature.**
  `/** Fetch a single issue as IIssue. */` above `getIssue(): Promise<IIssue>`.
- **Inferable conclusions.** A sentence the reader derives from the sentence
  before it.
- **Context the location supplies.** Inside `integration/jira/`, `jira.js v6` is
  `v6`.
- **Restated values.** Reference the constant by name; don't copy its number.
- **Narrative build-up.** "There are three reasons for this. First, …" → the
  reason.

## Keep

Anything the code cannot carry, at whatever length it genuinely needs:

- external API, SDK, or platform behavior that is not visible locally;
- workarounds, and the condition under which they can be removed;
- trade-offs and rejected alternatives;
- ticket, RFC, and bug references;
- non-obvious invariants and ordering constraints.

When a comment mixes both, keep the fact and cut the narration around it.

## Prefer present tense over version archaeology

"v6 models this endpoint as JSON, so it rejects image bytes" outlives "we used
to use v5, which returned a buffer, but v6 changed to …". Describe why the code
looks the way it does now.

## Workflow

1. Resolve scope. For the default, read `git diff HEAD` and collect added
   comment lines.
2. For each candidate, draft the condensed form before deciding to delete — a
   comment worth one line is not worth zero.
3. Apply the rewrites. Do not ask first — the tests above are the approval.
4. Run the project's formatter, linter, and typecheck.
5. Report the table below, covering what changed and what was left alone.

Delegate the read-only scan to a fast subagent when one is available: ask for
path, line, full comment text, and the declaration it sits above.

When the working-tree diff is empty, fall back to the current branch's commits
against `master`, and say that is what you scoped to.

## Required output

```markdown
| Location                       | Before                                                                                                                                     | After                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `integration/jira/issue.ts:47` | 6 lines — "Fetch a single issue as the repo's own `IIssue` shape. `jira.js` v6 derives its issue type from zod as a `$loose` record, so …" | 1 line — `/** v6 types the issue as a $loose record, leaving fields untyped; the cast lives here alone. */` |
| `lib/queue.ts:12`              | 3 lines explaining that the loop iterates the queue                                                                                        | _Delete._ Restates `for (const job of queue)`.                                                              |
```

Show the real before-text, truncated at ~120 chars. Give line counts so the
reduction is visible. Never report a rewrite you have not actually drafted.

## Stop conditions

- Comments in files you were not asked to touch stay untouched, even when
  verbose.
- Never condense a comment into something you are not sure is true. If the
  original is the only record of why the code exists and you cannot verify it,
  keep it verbatim.
- Leave license headers, `@ts-expect-error` justifications, and eslint-disable
  reasons alone — linters and reviewers depend on their exact wording.
