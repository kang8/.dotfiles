# Claude Code Instructions

## Git Commit Guidelines

When creating git commits:

- Only focus on **staged changes** when generating commit messages
- Ignore any unstaged modifications
- The user will stage the specific changes they want to commit
- Generate commit messages based solely on the staged content

Important Notes:

- Do not include unstaged changes in commit message descriptions
- Trust that the user has properly staged the intended changes
- Focus commit messages on what is actually being committed (staged files only)

## Git Branch Naming

- Bugfix branches must use the prefix `bugfix/`

## GitLab Access

When accessing GitLab data (issues, merge requests, pipelines, etc.):

- Use the `glab` CLI tool instead of API calls or other methods

## Information Accuracy

When encountering uncertain or unfamiliar content:

- **Do not guess or fabricate** — if you are not confident about a fact, API,
  configuration, version, behavior, or any technical detail, explicitly state
  the uncertainty
- **Look up the information source** — use available tools (documentation
  lookup, web search, codebase search, etc.) to find authoritative information
- **Provide citations** — always include where the information came from
  (official docs URL, file path, man page, etc.) so the user can verify
- **Cross-reference multiple sources** — validate findings against at least two
  independent sources when possible to ensure accuracy and reduce the risk of
  outdated or incorrect information
