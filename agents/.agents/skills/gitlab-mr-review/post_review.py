#!/usr/bin/env python3
"""Post code-review findings to a GitLab MR as inline *draft* notes ("add to review").

Why a script: GitLab's draft_notes endpoint needs a nested `position{}` object.
`glab api -f "position[base_sha]=..."` does NOT serialize nested form fields
correctly (only position_type survives; every SHA comes back null and the note
silently degrades to a non-inline comment). The reliable path is a JSON body via
`--input` with `Content-Type: application/json`, which is what this script does.

Findings are read as JSON from a file argument or stdin:

  [
    {"file": "path/to/x.sql", "new_line": 11,  "body": "comment on an ADDED line"},
    {"file": "path/to/x.sql", "old_line": 120, "body": "comment on a REMOVED line"},
    {"file": "path/to/x.sql", "new_line": 50, "old_line": 48, "body": "CONTEXT line"}
  ]

A finding with neither new_line nor old_line is posted as an MR-level note with
no position; SKILL.md's flow never does this.

Add "draft_id": <id> to reword an existing draft in place (PUT) instead of
creating one. Prefer this over delete+recreate: it keeps the draft's id and its
reply-to-discussion linkage, which a recreate cannot restore. GitLab's PUT is
whole-object replacement, so the position must be resent on every update -- a
PUT carrying only `note` blanks the position out and the draft degrades to
MR-level. This script always resends a freshly built position, so keep the file
and line keys on an update finding exactly as on a create.

Rules for line numbers (GitLab requirement):
  - ADDED line   -> new_line only
  - REMOVED line -> old_line only
  - CONTEXT line -> BOTH new_line and old_line (else position won't bind)

Line numbers are given against the MR's own diff (`diff_refs`, i.e. local HEAD
vs the merge-base). The Changes tab, however, defaults to the *merge-ref* diff
(MR merged into the current target HEAD), and the UI places a draft by its
`line_code`. Once the target branch has changed a touched file since the MR
base, the two numberings drift apart and a draft bound by `diff_refs` binds
fine via the API yet never renders inline. So when the target has moved, this
script maps each line into merge-ref coordinates and posts against the merge
ref's SHAs. GitLab then stores `position` normalized back to `diff_refs` while
`line_code` keeps the merge-ref numbering (observed on GitLab 19.5.1-ee).

By default it only creates drafts and stops (review is published by the user, or
by re-running with --publish). Nothing is ever published without --publish.
"""

from __future__ import annotations

import argparse
import difflib
import functools
import json
import subprocess
import sys
import urllib.parse


def glab_api(path: str, method: str = "GET", body: dict | None = None, required: bool = True) -> dict | None:
    cmd = ["glab", "api", "-X", method, path]
    inp = None
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "--input", "-"]
        inp = json.dumps(body, ensure_ascii=False)
    proc = subprocess.run(cmd, input=inp, capture_output=True, text=True)
    if proc.returncode != 0:
        if not required:
            return None
        sys.exit(f"glab api {method} {path} failed:\n{proc.stderr.strip()}")
    out = proc.stdout.strip()
    return json.loads(out) if out else {}


@functools.cache
def file_lines(project_id: int, path: str, sha: str) -> tuple[str, ...] | None:
    quoted = urllib.parse.quote(path, safe="")
    proc = subprocess.run(
        ["glab", "api", f"projects/{project_id}/repository/files/{quoted}/raw?ref={sha}"],
        capture_output=True, text=True,
    )
    return tuple(proc.stdout.splitlines()) if proc.returncode == 0 else None


@functools.cache
def line_map(project_id: int, path: str, src: str, dst: str) -> dict[int, int]:
    """1-based line at `src` -> same line at `dst`, for lines difflib keeps unchanged."""
    a, b = file_lines(project_id, path, src), file_lines(project_id, path, dst)
    if a is None or b is None:
        return {}
    mapping = {}
    for tag, i1, i2, j1, _ in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                mapping[i1 + k + 1] = j1 + k + 1
    return mapping


def merge_ref_refs(project_id: int, iid: int, refs: dict) -> dict | None:
    """SHAs of the merge-ref diff the Changes tab shows, or None when it matches `diff_refs`."""
    ref = glab_api(f"projects/{project_id}/merge_requests/{iid}/merge_ref", required=False)
    if not ref or not ref.get("commit_id"):
        return None  # conflicted or never computed; the UI falls back to the MR diff
    commit = glab_api(f"projects/{project_id}/repository/commits/{ref['commit_id']}")
    target = commit["parent_ids"][0]
    if target == refs["base_sha"]:
        return None
    return {"base_sha": target, "start_sha": target, "head_sha": ref["commit_id"]}


def reanchor(project_id: int, f: dict, refs: dict, merge_refs: dict) -> dict | None:
    """The finding with its lines in merge-ref coordinates, or None if a line has no counterpart."""
    moved = dict(f)
    for key, src, dst in (("new_line", refs["head_sha"], merge_refs["head_sha"]),
                          ("old_line", refs["base_sha"], merge_refs["base_sha"])):
        if key in f:
            line = line_map(project_id, f["file"], src, dst).get(f[key])
            if line is None:
                return None
            moved[key] = line
    return moved


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def project_path_from_remote() -> str:
    """group/repo  <-  git@host:group/repo.git | https://host/group/repo.git"""
    url = git("remote", "get-url", "origin")
    if not url:
        sys.exit("No 'origin' remote found; pass --project explicitly.")
    url = url.removesuffix(".git")
    if url.startswith("http"):
        path = urllib.parse.urlparse(url).path.lstrip("/")
    elif "@" in url and ":" in url:  # scp-style git@host:group/repo
        path = url.split(":", 1)[1]
    else:
        path = url
    return path


def resolve_mr(project_id: int, mr_iid: int | None) -> dict:
    if mr_iid is None:
        branch = git("rev-parse", "--abbrev-ref", "HEAD")
        mrs = glab_api(
            f"projects/{project_id}/merge_requests"
            f"?source_branch={urllib.parse.quote(branch, safe='')}&state=opened"
        )
        if not mrs:
            sys.exit(f"No open MR found for branch '{branch}'; pass --mr <iid>.")
        mr_iid = mrs[0]["iid"]
    return glab_api(f"projects/{project_id}/merge_requests/{mr_iid}")


def build_position(refs: dict, f: dict) -> dict | None:
    if "new_line" not in f and "old_line" not in f:
        return None  # general, non-inline note
    path = f["file"]
    pos = {
        "position_type": "text",
        "base_sha": refs["base_sha"],
        "start_sha": refs["start_sha"],
        "head_sha": refs["head_sha"],
        "new_path": path,
        "old_path": path,
    }
    if "new_line" in f:
        pos["new_line"] = f["new_line"]
    if "old_line" in f:
        pos["old_line"] = f["old_line"]
    return pos


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("findings", nargs="?", help="JSON file of findings (default: stdin)")
    ap.add_argument("--project", help="Project path (group/repo) or numeric id; default: from git remote")
    ap.add_argument("--mr", type=int, help="MR iid; default: open MR for current branch")
    ap.add_argument("--publish", action="store_true", help="Publish the whole draft review after creating notes")
    args = ap.parse_args()

    raw = open(args.findings, encoding="utf-8").read() if args.findings else sys.stdin.read()
    findings = json.loads(raw)
    if not isinstance(findings, list) or not findings:
        sys.exit("Findings must be a non-empty JSON array.")

    proj = args.project or project_path_from_remote()
    project = glab_api(f"projects/{urllib.parse.quote(str(proj), safe='')}")
    project_id = project["id"]

    mr = resolve_mr(project_id, args.mr)
    iid, refs = mr["iid"], mr["diff_refs"]
    print(f"MR !{iid}  {mr['web_url']}\n")

    merge_refs = merge_ref_refs(project_id, iid, refs)
    if merge_refs:
        print(f"Target moved past the MR base; anchoring to merge ref {merge_refs['head_sha'][:8]} "
              "(the Changes tab's default view). Lines in the table use its numbering.\n")

    endpoint = f"projects/{project_id}/merge_requests/{iid}/draft_notes"
    results = []
    for f in findings:
        body = {"note": f["body"]}
        pos_refs, pf = refs, f
        if merge_refs and ("new_line" in f or "old_line" in f):
            moved = reanchor(project_id, f, refs, merge_refs)
            if moved:
                pos_refs, pf = merge_refs, moved
            else:
                print(f"  warning: {f['file']} line has no counterpart in the merge ref; posting "
                      "against the MR diff, so the draft may not render in the default view.")
        pos = build_position(pos_refs, pf)
        if pos:
            body["position"] = pos
        draft_id = f.get("draft_id")
        if draft_id and not pos:
            print(f"  warning: draft {draft_id} has no line; the update will blank its "
                  "position and turn it into an MR-level note.")
        if draft_id:
            d = glab_api(f"{endpoint}/{draft_id}", "PUT", body)
        else:
            d = glab_api(endpoint, "POST", body)
        # A wiped position comes back as a hash of nulls, not as null, so test a
        # line number -- truthiness of `position` (or a stale line_code) says OK
        # on a draft that has actually lost its binding.
        rp = d.get("position") or {}
        wanted_inline = pos is not None
        bound = rp.get("new_line") is not None or rp.get("old_line") is not None
        status = "OK" if (not wanted_inline or bound) else "NOT-BOUND"
        # The UI renders by `line_code` (`<hash>_<old>_<new>`), which PUT never refreshes.
        lc = (d.get("line_code") or "").split("_")
        if status == "OK" and wanted_inline and len(lc) == 3:
            expected = (2, pf["new_line"]) if "new_line" in pf else (1, pf["old_line"])
            if lc[expected[0]] != str(expected[1]):
                status = "HIDDEN"
        results.append((d.get("id"), "PUT" if draft_id else "POST", f.get("file", "-"),
                        pf.get("new_line") or pf.get("old_line") or "-", status))

    print(f"{'draft':>7}  {'verb':<5} {'line':>6}  status  file")
    for did, verb, file, line, status in results:
        flag = "  " if status == "OK" else "!!"
        print(f"{did:>7}  {verb:<5} {str(line):>6}  {flag}{status:<9} {file}")

    unbound = [r for r in results if r[4] == "NOT-BOUND"]
    if unbound:
        print(f"\n  {len(unbound)} note(s) did not bind to a line (check new_line/old_line "
              "vs added/removed/context rules). They are now general notes.")
    hidden = [r for r in results if r[4] == "HIDDEN"]
    if hidden:
        print(f"\n  {len(hidden)} note(s) bound, but their line_code points at another row, so "
              "the Changes tab won't show them. Re-post without draft_id and delete the old one.")

    if args.publish:
        glab_api(f"projects/{project_id}/merge_requests/{iid}/draft_notes/bulk_publish", "POST", {})
        print("\nPublished the review (all drafts are now live).")
    else:
        print("\nDrafts written (unpublished). Review them in the MR UI and Submit, "
              "or re-run with --publish.")


if __name__ == "__main__":
    main()
