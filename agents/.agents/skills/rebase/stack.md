# Stacked branches

A **stacked** branch was cut from a parent branch with its own MR. When the
parent is amended, rebased, or squashed after the cut, the branch still carries
the parent's old commits, and a plain `git rebase <target>` replays them onto
their new versions as conflicts.

Run this in place of the plain rebase:

- With a local `<parent>` branch:
  `git rebase --onto <target> --fork-point <parent>`
- Without one: `git rebase --fork-point <target>`

`--fork-point` finds the old parent tip in the ref's reflog and replays only the
commits after it, which drops the old copies. Git turns it off whenever the
upstream is named on the command line, so the flag stays explicit. The local
branch goes first because its reflog holds the parent's own history; a
remote-tracking ref only holds the tips this clone fetched or pushed.

When the reflog has no old tip (`git merge-base --fork-point <ref> HEAD` prints
nothing), git falls back to a plain rebase without saying so, and the old copies
surface as conflicts for the conflict loop's **copy** rule.
