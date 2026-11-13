#!/usr/bin/env python3
"""Sort today's GitLab work into buckets and write <session>/triage.json.

Usage: triage.py [--session DIR]

Review side (MRs naming me as reviewer): new / updated (code) / rebased / reviewed (no change) /
approved by me / draft / stale. Author side (my MRs): conflict / pipeline_failed / awaiting_reply /
quiet. Plus pending mentions from the To-Do list that no bucket covers.
"""

import argparse
import concurrent.futures as cf
import datetime as dt
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from common import api, enc, load_state, local_repo, patch_id, sh, today_dir, ts  # noqa: E402

STALE_DAYS = 14
RECENT_DAYS = 7  # older MRs without my state go to backlog/quiet instead of today's list


def mr_detail(ref):
    project, iid = ref
    mr = api(f"projects/{enc(project)}/merge_requests/{iid}")
    appr = api(f"projects/{enc(project)}/merge_requests/{iid}/approvals") or {}
    disc = api(f"projects/{enc(project)}/merge_requests/{iid}/discussions?per_page=100") or []
    return mr, appr, disc


def notes_since(disc, since, me):
    return [
        {"author": n["author"]["username"], "at": n["created_at"], "body": n["body"][:300], "discussion_id": d["id"]}
        for d in disc for n in d["notes"]
        if not n["system"] and n["author"]["username"] != me and (since is None or ts(n["created_at"]) > ts(since))
    ]


def open_threads_waiting_on_me(disc, me):
    out = []
    for d in disc:
        notes = [n for n in d["notes"] if not n["system"]]
        if not notes or not notes[0].get("resolvable") or notes[0].get("resolved"):
            continue
        if notes[-1]["author"]["username"] != me:
            out.append({"discussion_id": d["id"], "last_author": notes[-1]["author"]["username"],
                        "at": notes[-1]["created_at"], "body": notes[-1]["body"][:200]})
    return out


def classify_review(mr, appr, disc, state, me):
    key = f"{mr['references']['full']}"
    project = mr["references"]["full"].split("!")[0]
    prev = state.get(key)
    age = (dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(mr["updated_at"].replace("Z", "+00:00"))).days
    item = {"key": key, "project": project, "iid": mr["iid"], "title": mr["title"], "author": mr["author"]["username"],
            "url": mr["web_url"], "head": mr["sha"], "merge_status": mr["detailed_merge_status"],
            "changes": mr.get("changes_count"), "updated_at": mr["updated_at"],
            "approved_by": [a["user"]["username"] for a in appr.get("approved_by", [])]}
    if mr["draft"]:
        return "draft", item
    if me in item["approved_by"] and (not prev or prev.get("reviewed_sha") == mr["sha"]):
        return "approved", item
    if not prev:
        if mr["detailed_merge_status"] == "conflict" and age > STALE_DAYS:
            return "stale", item
        return ("new" if age <= RECENT_DAYS else "backlog"), item
    item["reviewed_sha"] = prev["reviewed_sha"]
    item["new_notes"] = notes_since(disc, prev.get("reviewed_at"), me)
    if prev["reviewed_sha"] == mr["sha"]:
        return ("updated_notes" if item["new_notes"] else "reviewed"), item
    repo = local_repo(project)
    if repo:
        sh("git", "fetch", "-q", "origin", f"refs/merge-requests/{mr['iid']}/head", cwd=repo)
        new_base = sh("git", "merge-base", mr["sha"], mr["diff_refs"]["base_sha"], cwd=repo).strip()
        old = patch_id(repo, prev.get("base_sha"), prev["reviewed_sha"])
        if old and old == patch_id(repo, new_base, mr["sha"]):
            return ("updated_notes" if item["new_notes"] else "rebased"), item
    return "updated", item


def classify_mine(mr, disc, me):
    item = {"key": mr["references"]["full"], "project": mr["references"]["full"].split("!")[0], "iid": mr["iid"],
            "title": mr["title"], "url": mr["web_url"], "head": mr["sha"], "draft": mr["draft"],
            "merge_status": mr["detailed_merge_status"], "pipeline": (mr.get("head_pipeline") or {}).get("status"),
            "pipeline_url": (mr.get("head_pipeline") or {}).get("web_url"), "updated_at": mr["updated_at"],
            "waiting": open_threads_waiting_on_me(disc, me)}
    age = (dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(mr["updated_at"].replace("Z", "+00:00"))).days
    if age > RECENT_DAYS:
        return "quiet", item
    if item["waiting"]:
        return "awaiting_reply", item
    if mr["draft"] and age > 3:
        return "quiet", item
    if mr["detailed_merge_status"] == "conflict":
        return "conflict", item
    if item["pipeline"] == "failed":
        return "pipeline_failed", item
    return "quiet", item


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session", type=pathlib.Path, default=None)
    args = ap.parse_args()
    session = args.session or today_dir()
    session.mkdir(parents=True, exist_ok=True)
    me = api("user")["username"]
    state = load_state()

    reviews = api(f"merge_requests?scope=all&state=opened&reviewer_username={me}&per_page=100") or []
    mine = api(f"merge_requests?scope=all&state=opened&author_username={me}&per_page=100") or []
    refs = {(m["references"]["full"].split("!")[0], m["iid"]) for m in reviews + mine}
    with cf.ThreadPoolExecutor(8) as pool:
        details = dict(zip(refs, pool.map(mr_detail, refs)))

    out = {"me": me, "generated_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
           "review": {}, "mine": {}, "mentions": []}
    for m in reviews:
        mr, appr, disc = details[(m["references"]["full"].split("!")[0], m["iid"])]
        bucket, item = classify_review(mr, appr, disc, state, me)
        out["review"].setdefault(bucket, []).append(item)
    for m in mine:
        mr, appr, disc = details[(m["references"]["full"].split("!")[0], m["iid"])]
        bucket, item = classify_mine(mr, disc, me)
        out["mine"].setdefault(bucket, []).append(item)

    covered = {(p, i) for p, i in refs}
    for t in api("todos?state=pending&per_page=100") or []:
        if t["action_name"] in ("mentioned", "directly_addressed") and t.get("target_type") == "MergeRequest":
            ref = (t["project"]["path_with_namespace"], t["target"]["iid"])
            if ref not in covered and t["target"].get("state") == "opened":
                out["mentions"].append({"key": f"{ref[0]}!{ref[1]}", "title": t["target"]["title"], "author": t["author"]["username"],
                                        "url": t["target_url"], "at": t["created_at"], "body": (t.get("body") or "")[:200]})

    (session / "triage.json").write_text(json.dumps(out, ensure_ascii=False, indent=1))
    print(f"session: {session}")
    quiet = {"draft", "stale", "backlog", "approved", "reviewed", "quiet"}
    for side, buckets in (("review", out["review"]), ("mine", out["mine"])):
        for bucket, items in sorted(buckets.items()):
            print(f"\n## {side}/{bucket} ({len(items)})")
            if bucket in quiet:
                continue  # counts only; the full list stays in triage.json
            for it in sorted(items, key=lambda x: x["updated_at"], reverse=True):
                extra = ""
                if it.get("new_notes"):
                    extra += f"  notes+{len(it['new_notes'])}"
                if it.get("waiting"):
                    extra += f"  waiting:{','.join(w['last_author'] for w in it['waiting'])}"
                if side == "mine" and it.get("pipeline") == "failed":
                    extra += "  pipeline:failed"
                print(f"- {it['key']}  {it.get('author', '')}  {it['title'][:70]}{extra}")
    if out["mentions"]:
        print(f"\n## mentions ({len(out['mentions'])})")
        for t in out["mentions"]:
            print(f"- {t['key']}  {t['author']}  {t['title'][:70]}")


if __name__ == "__main__":
    main()
