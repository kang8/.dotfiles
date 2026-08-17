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
    {"file": "path/to/x.sql", "new_line": 50, "old_line": 48, "body": "CONTEXT line"},
    {"body": "overall MR-level note with no position"}
  ]

Rules for line numbers (GitLab requirement):
  - ADDED line   -> new_line only
  - REMOVED line -> old_line only
  - CONTEXT line -> BOTH new_line and old_line (else position won't bind)

By default it only creates drafts and stops (review is published by the user, or
by re-running with --publish). Nothing is ever published without --publish.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.parse


def glab_api(path: str, method: str = "GET", body: dict | None = None) -> dict:
    cmd = ["glab", "api", "-X", method, path]
    inp = None
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "--input", "-"]
        inp = json.dumps(body, ensure_ascii=False)
    proc = subprocess.run(cmd, input=inp, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"glab api {method} {path} failed:\n{proc.stderr.strip()}")
    out = proc.stdout.strip()
    return json.loads(out) if out else {}


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

    results = []
    for f in findings:
        body = {"note": f["body"]}
        pos = build_position(refs, f)
        if pos:
            body["position"] = pos
        d = glab_api(f"projects/{project_id}/merge_requests/{iid}/draft_notes", "POST", body)
        rp = d.get("position") or {}
        wanted_inline = pos is not None
        bound = rp.get("new_line") is not None or rp.get("old_line") is not None
        status = "OK" if (not wanted_inline or bound) else "NOT-BOUND"
        results.append((d.get("id"), f.get("file", "-"),
                        rp.get("new_line") or rp.get("old_line") or "-", status))

    print(f"{'draft':>7}  {'line':>6}  status  file")
    for did, file, line, status in results:
        flag = "  " if status == "OK" else "!!"
        print(f"{did:>7}  {str(line):>6}  {flag}{status:<9} {file}")

    bad = [r for r in results if r[3] != "OK"]
    if bad:
        print(f"\n  {len(bad)} note(s) did not bind to a line (check new_line/old_line "
              "vs added/removed/context rules). They were created as general notes.")

    if args.publish:
        glab_api(f"projects/{project_id}/merge_requests/{iid}/draft_notes/bulk_publish", "POST", {})
        print("\nPublished the review (all drafts are now live).")
    else:
        print("\nDrafts created (unpublished). Review them in the MR UI and Submit, "
              "or re-run with --publish.")


if __name__ == "__main__":
    main()
