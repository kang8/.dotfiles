#!/usr/bin/env python3
"""Assemble <session>/data.json for the console from the reviewers' output.

Usage: build_session.py [SESSION_DIR]

Reads  <session>/reviewers.json         {name: {"session": id, "cwd": dir, "mrs": ["group/repo!iid", ...]}}
       <session>/reviews/<slug>.json    one per MR, schema in review-brief.md
       <session>/reviews/<slug>.md      the reviewer's prose report (optional)
Code windows come from the head the reviewer read, so line numbers match the drafts.
A review whose head state.json already records is left out, so a second round the same day shows only new work.
"""

import datetime as dt
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from common import api, enc, hunks, load_state, local_repo, sh, today_dir, transcript_path  # noqa: E402


def window(rows, new_line, old_line, radius=14):
    idx = next((i for i, r in enumerate(rows)
                if (new_line is not None and r.get("new") == new_line and (old_line is None or r.get("old") == old_line))
                or (new_line is None and r.get("old") == old_line and r["kind"] == "del")), None)
    if idx is None:
        return rows[:40]
    return rows[max(0, idx - radius):idx + radius + 1]


def file_slice(repo, sha, path, start, end):
    lines = sh("git", "show", f"{sha}:{path}", cwd=repo).splitlines()
    start, end = max(1, start or 1), min(len(lines), end or (start or 1) + 15)
    return [{"new": i, "kind": "ctx", "text": lines[i - 1]} for i in range(start, end + 1)]


def main():
    session = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else today_dir()
    reviewers = json.loads((session / "reviewers.json").read_text())
    by_mr = {mr: name for name, r in reviewers.items() for mr in r["mrs"]}
    me = api("user")["username"]
    cutoff = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    data = {"me": me, "session": str(session), "built_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
            "sessions": {}, "mrs": [], "findings": []}
    for name, r in reviewers.items():
        t = transcript_path(r["cwd"], r["session"])
        if not t.exists():  # fall back to a glob if the project-dir encoding differs
            hits = list((pathlib.Path.home() / ".claude/projects").glob(f"*/{r['session']}.jsonl"))
            t = hits[0] if hits else t
        data["sessions"][name] = {"id": r["session"], "cwd": r["cwd"], "transcript": str(t)}

    n = 0
    decided = load_state()
    for path in sorted((session / "reviews").glob("*.json")):
        rv = json.loads(path.read_text())
        project, iid = rv["project"], int(rv["iid"])
        key = f"{project}!{iid}"
        if decided.get(key, {}).get("reviewed_sha") == rv["reviewed_sha"]:
            continue  # decided in an earlier round today
        repo = local_repo(project)
        if repo is None:
            print(f"skip {key}: no local checkout at ~/Projects/{project.split('/')[-1]}", file=sys.stderr)
            continue
        mr = api(f"projects/{enc(project)}/merge_requests/{iid}")
        sh("git", "fetch", "-q", "origin", f"refs/merge-requests/{iid}/head", cwd=repo)
        head = rv["reviewed_sha"]
        base = sh("git", "merge-base", head, mr["diff_refs"]["base_sha"], cwd=repo).strip()
        disc = api(f"projects/{enc(project)}/merge_requests/{iid}/discussions?per_page=100") or []
        appr = api(f"projects/{enc(project)}/merge_requests/{iid}/approvals") or {}
        report = path.with_suffix(".md")
        data["mrs"].append({
            "project": project, "iid": iid, "key": key, "title": mr["title"], "author": mr["author"]["username"],
            "url": mr["web_url"], "description": mr["description"] or "", "verdict": rv.get("verdict", ""),
            "summary": rv.get("summary", ""), "reviewer": by_mr.get(key), "reviewed_sha": head, "base_sha": base,
            "files": sh("git", "diff", "--name-only", base, head, cwd=repo).split(), "cutoff": cutoff, "repo": str(repo),
            "approved_by": [a["user"]["username"] for a in appr.get("approved_by", [])],
            "discussions": [
                {"author": x["author"]["username"], "at": x["created_at"][11:16], "body": x["body"], "discussion_id": d["id"],
                 "path": (x.get("position") or {}).get("new_path"), "line": (x.get("position") or {}).get("new_line")}
                for d in disc for x in d["notes"] if not x["system"]
            ],
            "report": report.read_text() if report.exists() else "",
        })
        for f in rv.get("findings", []):
            n += 1
            rows = hunks(repo, base, head, f["file"])
            data["findings"].append({
                "id": str(n), "iid": iid, "project": project, "file": f["file"],
                "new_line": f.get("new_line"), "old_line": f.get("old_line"),
                "blocking": bool(f.get("blocking")), "verified": f.get("verified", "yes"), "note": f.get("note"),
                "body": f["body"], "code": window(rows, f.get("new_line"), f.get("old_line")),
                "related": [{"file": r["file"], "lines": file_slice(repo, head, r["file"], r.get("start"), r.get("end"))}
                            for r in f.get("related", [])],
            })
    (session / "data.json").write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(f"wrote {session / 'data.json'}: {len(data['mrs'])} MRs, {n} findings")


if __name__ == "__main__":
    main()
