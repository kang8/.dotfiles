---
name: condense-comments
description: Shorten long code comments to their smallest useful form, delete the ones restating the code, and cut the ghosts pointing at code the reader cannot see. Use on your own once you finish writing or editing code that left comments behind, when asked to clean up the comments on a diff or a new file, or via `/condense-comments`.
---

# Condense Comments

A comment earns its place by helping the **cold reader** — someone holding only
this code, with no chat history, no prior versions, no memory of what was tried
and rejected. An agent writes for the reader it just talked to, and that reader
is gone. Most of what it leaves behind is three times longer than it needs to
be.

Rewrite them short. Delete only what survives no rewrite.

## The bar

A comment survives only if, without it, the cold reader would have to trace
**several separate parts of the code** to reconstruct what it says.

- **Clears the bar:** external API, SDK, or platform behavior invisible locally;
  a workaround and the condition that retires it; a trade-off or rejected
  alternative; a ticket, RFC, or bug reference; a cross-cutting invariant or
  ordering constraint; a constraint one call site imposes on another.
- **Local facts are not distant.** The line it sits on, its enclosing function,
  and the name and signature of the function it calls on the next line are all
  local. If the point is clear from those, it is restatement.
- **Greppable facts never clear the bar.** Who calls this, who implements it,
  how many exist — the reader greps, and grep never goes stale.
- **Being a _why_ earns nothing on its own.** A why the local code already makes
  obvious is still noise.
- **Partial keeps are fine.** Keep the fragment that clears the bar; cut the
  narration around it.

## Cut

**Restated** — the code already says it.

- Openers echoing the signature. `/** Fetch a single issue as IIssue. */` above
  `getIssue(): Promise<IIssue>`.
- Values copied out of a constant. Reference it by name instead.
- Context the location supplies. Inside `integration/jira/`, `jira.js v6` is
  `v6`.
- Guarantees the construct already makes — "don't mutate", "keep in sync" — over
  a `const` or a frozen object. A real invariant names a place the code _could_
  break it.
- A census of the codebase: how many other places use this thing, or which ones.
- Prose narrating a delegate call, above the one line calling a well-named
  function.

**Ghost** — points at something absent from the code. Ruled-out approaches,
deleted alternatives, "as requested", a design from earlier in the conversation.
`// switched from Redux to Zustand`, `// no longer need the wrapper class`. Only
a reader who watched the code change can use these.

Version archaeology is the same smell in past tense: "v6 models this endpoint as
JSON, so it rejects image bytes" outlives "we used to use v5, which returned a
buffer, but v6 changed to …". Describe why the code looks the way it does now.

A ghost also hides as a clause inside a comment worth keeping — "unlike X",
"rather than X", "no longer Y". Excise the clause, keep the rest. Contrastive
phrasing is the tell.

**Padding** — the right fact, too many words.

- Inferable conclusions: a sentence the reader derives from the one before it.
- Narrative build-up: "There are three reasons for this. First, …" → the reason.
- Length tracks how non-obvious the target is. When you are defending a
  paragraph one true sentence at a time, the target is the tell: ordinary code,
  over-documented. Cut to the line that would surprise a competent reader.

## Workflow

1. Scope the working tree: run `git status --porcelain`, then take the changed
   lines of tracked files and all of each new file. Untracked files carry the
   densest fresh comments and `git diff` alone hides them. Delegate the
   read-only scan to a fast subagent when one is available: ask for path, line,
   full comment text, and the declaration it sits above.
2. Classify every comment in scope against the bar.
3. Draft the condensed form before deciding to delete — a comment worth one line
   is not worth zero.
4. Apply the rewrites. Do not ask first: the bar is the approval. Touch only
   comments; if a cut tempts you to rename a variable or restructure a line,
   report it instead.
5. Run the project's formatter, linter, and typecheck.
6. Report the table below, covering what changed and what was left alone.

Done when every comment in scope is accounted for — condensed, deleted, or
deliberately kept — none skipped.

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
- Condense a comment only into something you are sure is true. When the original
  is the only record of why the code exists and you cannot verify it, keep it
  verbatim.
- Leave license headers, `@ts-expect-error` justifications, and eslint-disable
  reasons alone — linters and reviewers depend on their exact wording.
- Commented-out code is a separate call. Flag it and leave it in place.
- Condense a comment in the language it is written in. A Chinese comment stays
  Chinese.
