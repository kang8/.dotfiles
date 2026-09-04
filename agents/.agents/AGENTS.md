# Agent Instructions

## Git Commit Guidelines

Base commit messages solely on **staged changes** — the user stages what they
want committed. Ignore unstaged modifications.

## Writing Style

Ban these constructions in prose, commit messages, and code comments:

- **Negative parallelism** — "not X, but Y", "it's not just X, it's Y", "X isn't
  the problem; Y is". Assert Y directly.
- **Tricolon / polycolon** — three or more parallel clauses used for rhythm
  ("faster, cleaner, safer"). Keep only the items that carry information.
- **Superlatives and persuasive framing** — "critical", "powerful",
  "seamlessly", "robust". Describe the mechanism instead.
- **Restating the question** before answering it.

Write for a competent colleague who lacks only this project's context. Prefer
plain language over compressed jargon: shorter is not better if it takes longer
to decode.

## Homebrew Paths

Homebrew's prefix is `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel.
This machine is `/usr/local`, and the repo is written for both — `zsh/.zshrc`
runs `brew shellenv` from whichever `brew` exists. Reach a brew-installed
program through `$HOMEBREW_PREFIX` or a bare command name on `PATH`; a literal
prefix runs on one kind of machine and fails on the other.

launchd (GUI apps, agents) and cron start programs with a bare `PATH` —
launchd's is `/usr/bin:/bin:/usr/sbin:/sbin` — and none of zsh's exports, so
those configs resolve the prefix themselves: probe for both, as `zsh/.zshrc`
does.

## Information Accuracy

When unsure about any technical detail (fact, API, config, version, behavior):

- **State the uncertainty** explicitly rather than guessing.
- **Look it up** with available tools (docs, web search, codebase).
- **Cite the source** (docs URL, file path, man page) so the user can verify.
- **Cross-reference** at least two independent sources when possible.
