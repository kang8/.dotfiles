#!/usr/bin/env python3
"""Fast-forward local master to origin/master in every primary checkout under a root.

Usage: sync_master.py [--dry-run] [--root DIR] [REPO ...]

Only fast-forwards: never switches branches, stashes, resets, or creates merge commits.
"""

import argparse
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

FETCH_TIMEOUT = 120
GIT_ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}


def git(repo, *args, check=False, timeout=None):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        env=GIT_ENV,
        check=check,
        timeout=timeout,
    )


def out(repo, *args):
    return git(repo, *args, check=True).stdout.strip()


def has_ref(repo, ref):
    return git(repo, "show-ref", "-q", "--verify", ref).returncode == 0


def fetch(repo):
    try:
        r = git(repo, "fetch", "--quiet", "origin", "master", timeout=FETCH_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "timed out"
    if r.returncode == 0:
        return None
    lines = [l for l in r.stderr.strip().splitlines() if l.strip()]
    return lines[-1] if lines else f"exit {r.returncode}"


def master_worktree(repo):
    path = None
    for line in out(repo, "worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = line[len("worktree "):]
        elif line == "branch refs/heads/master":
            return Path(path)
    return None


def status_paths(wt):
    """Return (all dirty paths, untracked paths) from porcelain v1 -z output."""
    raw = git(wt, "status", "--porcelain", "-z").stdout
    entries = raw.split("\0")
    dirty, untracked = set(), set()
    i = 0
    while i < len(entries):
        e = entries[i]
        i += 1
        if not e:
            continue
        code, path = e[:2], e[3:]
        dirty.add(path)
        if code == "??":
            untracked.add(path)
        if code[0] in "RC":
            # rename/copy carries the source path as the next entry
            dirty.add(entries[i])
            i += 1
    return dirty, untracked


def overlaps(dirty, incoming):
    hits = []
    for p in sorted(dirty):
        if p.endswith("/"):
            if any(f.startswith(p) for f in incoming):
                hits.append(p)
        elif p in incoming:
            hits.append(p)
    return hits


def busy(wt):
    for name in ("rebase-merge", "rebase-apply", "MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD"):
        p = Path(out(wt, "rev-parse", "--git-path", name))
        if not p.is_absolute():
            p = wt / p
        if p.exists():
            return name
    return None


def sandbox_denied(wt, incoming):
    """Paths the checkout would write that the current sandbox refuses."""
    denied = []
    for rel in incoming:
        p = wt / rel
        try:
            if os.path.lexists(p):
                open(p, "rb+").close()
                continue
            q = p
            while not os.path.lexists(q.parent):
                q = q.parent
            if q == p:
                os.close(os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL))
                os.remove(p)
            else:
                q.mkdir()
                q.rmdir()
        except PermissionError:
            denied.append(rel)
        except OSError:
            pass
    return denied


def short(repo, ref):
    return out(repo, "rev-parse", "--short", ref)


def classify_and_sync(repo, dry_run):
    name = repo.name
    if not has_ref(repo, "refs/remotes/origin/master"):
        return name, "no-origin-master", ""
    left, right = out(repo, "rev-list", "--left-right", "--count", "master...origin/master").split()
    ahead, behind = int(left), int(right)
    if ahead == 0 and behind == 0:
        return name, "up-to-date", ""
    if ahead > 0:
        commits = out(repo, "log", "--format=%h %ad %s", "--date=short", "origin/master..master")
        local = "; ".join(commits.splitlines()[:5])
        return name, "skip-diverged", f"ahead {ahead} behind {behind}; local-only: {local}"

    span = f"{short(repo, 'master')}..{short(repo, 'origin/master')} ({behind} commits)"
    wt = master_worktree(repo)

    if wt is None:
        if dry_run:
            return name, "would-update-ref", span
        r = git(repo, "fetch", "-q", ".", "refs/remotes/origin/master:refs/heads/master")
        if r.returncode != 0:
            return name, "failed", r.stderr.strip().splitlines()[-1]
        return name, "ref-updated", span

    if not wt.is_dir():
        return name, "failed", f"master checked out in missing worktree {wt}"
    op = busy(wt)
    if op:
        return name, "skip-busy", f"{op} in progress in {wt}"
    incoming = set(out(repo, "diff", "--name-only", "master", "origin/master").splitlines())
    dirty, untracked_before = status_paths(wt)
    hits = overlaps(dirty, incoming)
    if hits:
        return name, "skip-overlap", f"{wt}: " + ", ".join(hits)
    denied = sandbox_denied(wt, incoming)
    if denied:
        return name, "skip-sandbox", ", ".join(sorted(denied))
    if dry_run:
        return name, "would-ff-merge", f"{span} in {wt}"

    r = git(wt, "merge", "-q", "--ff-only", "origin/master")
    if r.returncode != 0:
        return name, "failed", r.stderr.strip().replace("\n", " ")
    detail = f"{span} in {wt}"
    _, untracked_after = status_paths(wt)
    new = sorted(untracked_after - untracked_before)
    if new:
        detail += "; new-untracked: " + ", ".join(new)
    if dirty:
        detail += f"; kept {len(dirty)} local change(s)"
    return name, "ff-merged", detail


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--root", default=str(Path.home() / "Projects"))
    ap.add_argument("repos", nargs="*")
    args = ap.parse_args()
    root = Path(args.root)

    names = args.repos or sorted(p.name for p in root.iterdir() if (p / ".git").is_dir())
    candidates, skipped = [], []
    for n in names:
        repo = root / n
        if not (repo / ".git").is_dir():
            skipped.append(f"{n} (not a primary checkout)")
        elif not has_ref(repo, "refs/heads/master"):
            skipped.append(f"{n} (no local master)")
        elif git(repo, "remote", "get-url", "origin").returncode != 0:
            skipped.append(f"{n} (no origin remote)")
        else:
            candidates.append(repo)

    with ThreadPoolExecutor(max_workers=8) as pool:
        fetch_errors = dict(zip(candidates, pool.map(fetch, candidates)))

    rows = []
    for repo in candidates:
        err = fetch_errors[repo]
        if err and "couldn't find remote ref" in err:
            rows.append((repo.name, "no-origin-master", ""))
        elif err:
            rows.append((repo.name, "fetch-failed", err))
        else:
            try:
                rows.append(classify_and_sync(repo, args.dry_run))
            except subprocess.CalledProcessError as e:
                rows.append((repo.name, "failed", (e.stderr or str(e)).strip()))

    width = max((len(r[0]) for r in rows), default=0)
    for name, status, detail in sorted(rows, key=lambda r: (r[1], r[0])):
        print(f"{name:<{width}}  {status:<18}  {detail}".rstrip())
    if skipped:
        print(f"\nnot applicable ({len(skipped)}): " + ", ".join(skipped))


if __name__ == "__main__":
    main()
