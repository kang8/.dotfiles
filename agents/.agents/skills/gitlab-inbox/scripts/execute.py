#!/usr/bin/env python3
"""Carry out <session>/decisions.json: draft notes, approvals, merges; then record review state.

Usage: execute.py [SESSION_DIR] [--dry-run | --record-only]

Undecided gate: the console pre-selects nothing, so an MR with any null decision (action, finding, or MR
comment) is skipped whole and left out of state.json; triage brings it back next time. An MR the user
marked 暂缓 (deferred) is skipped the same way.

Head gate: an MR whose current head differs from the decision's pinned_head is skipped and reported,
since the user decided on code that is no longer there. Approve/merge also pass ?sha= so GitLab refuses
a head that moved after the gate. Comments are created as drafts only; the script ends by printing the
one bulk_publish line the user runs.
"""

import argparse
import datetime as dt
import json
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from common import POST_REVIEW, api, enc, hunks, load_state, local_repo, save_state, sh, today_dir  # noqa: E402


def position(repo, refs, f):
    """post_review.py finding with the right line keys for the current diff (context lines need both)."""
    out = {"file": f["file"], "body": f["body"]}
    if f.get("new_line"):
        rows = hunks(repo, refs["base_sha"], refs["head_sha"], f["file"], ctx=3) if repo else []
        row = next((r for r in rows if r.get("new") == f["new_line"]), None)
        out["new_line"] = f["new_line"]
        if row and row["kind"] == "ctx":
            out["old_line"] = row["old"]
        elif row is None and repo:
            # Outside every hunk: an unchanged line; the nearest context row above gives the old/new offset.
            above = [r for r in rows if r["kind"] == "ctx" and r["new"] < f["new_line"]]
            out["old_line"] = f["new_line"] - (above[-1]["new"] - above[-1]["old"] if above else 0)
    else:
        out["old_line"] = f["old_line"]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session", nargs="?", type=pathlib.Path)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--record-only", action="store_true", help="update review state without touching GitLab")
    args = ap.parse_args()
    session = args.session or today_dir()
    decisions = json.loads((session / "decisions.json").read_text())
    state = load_state()
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    report, publish = [], []

    for d in decisions["mrs"]:
        key, project, iid = d["key"], d["project"], d["iid"]
        if d.get("closed"):
            report.append(f"{key}: 已合并/关闭，跳过")
            continue
        if d.get("deferred"):
            report.append(f"{key}: 暂缓，跳过，下次 triage 还会出现")
            continue
        comment = d.get("comment") or None
        undecided = ([] if d.get("action") else ["MR 动作"]) + \
            [f"#{f['id']}" for f in d["findings"] if f.get("decision") not in ("send", "drop")] + \
            (["MR 评论"] if comment and comment.get("decision") not in ("send", "drop") else [])
        if undecided:
            report.append(f"{key}: ⏸ 未决定（{' '.join(undecided)}），整个跳过，下次 triage 还会出现")
            continue
        cur = api(f"projects/{enc(project)}/merge_requests/{iid}")
        if cur["state"] != "opened":
            report.append(f"{key}: 决定之后变成了 {cur['state']}，跳过")
            continue
        if cur["sha"] != d["pinned_head"]:
            report.append(f"{key}: ⛔ head 从 {d['pinned_head'][:8]} 变成 {cur['sha'][:8]}，跳过，回网页重新看")
            continue
        repo = local_repo(project)
        if repo:
            sh("git", "fetch", "-q", "origin", f"refs/merge-requests/{iid}/head", cwd=repo)
        sends = [f for f in d["findings"] if f["decision"] == "send"]
        inline = [position(repo, cur["diff_refs"], f) for f in sends if not f.get("reply_to")]
        replies = [f for f in sends if f.get("reply_to")]
        general = comment["body"].strip() if comment and comment["decision"] == "send" else ""
        done = []
        if args.dry_run:
            done.append(f"draft×{len(inline)} reply×{len(replies)} mr_note×{int(bool(general))} action={d['action']} (dry run)")
            print(json.dumps(inline, ensure_ascii=False, indent=1))
        elif not args.record_only:
            if inline:
                with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tmp:
                    json.dump(inline, tmp, ensure_ascii=False)
                proc = subprocess.run(["python3", str(POST_REVIEW), tmp.name, "--project", project, "--mr", str(iid)],
                                      capture_output=True, text=True)
                bad = [l for l in proc.stdout.splitlines() if "NOT-BOUND" in l or "HIDDEN" in l]
                done.append(f"draft×{len(inline)}" + (f" ⚠ {len(bad)} 条没挂上行：{bad}" if bad else "") +
                            (f" ⚠ post_review 失败：{proc.stderr.strip()[-300:]}" if proc.returncode else ""))
            for f in replies:
                api(f"projects/{enc(project)}/merge_requests/{iid}/draft_notes", "POST",
                    {"note": f["body"], "in_reply_to_discussion_id": f["reply_to"]})
            if replies:
                done.append(f"reply×{len(replies)}")
            if general:  # a draft note without position is an MR-level comment
                api(f"projects/{enc(project)}/merge_requests/{iid}/draft_notes", "POST", {"note": general})
                done.append("mr_note×1")
            if inline or replies or general:
                publish.append(f"{enc(project)}/merge_requests/{iid}")
            # GitLab answers 401 to a repeat approve, so check first.
            if d["action"] in ("approve", "merge") and \
                    api(f"projects/{enc(project)}/merge_requests/{iid}/approvals").get("user_has_approved"):
                done.append("早已 approve")
            elif d["action"] in ("approve", "merge"):
                try:
                    api(f"projects/{enc(project)}/merge_requests/{iid}/approve?sha={cur['sha']}", "POST")
                    done.append("approved")
                except RuntimeError as e:
                    done.append(f"approve 失败：{e}")
            if d["action"] == "merge":
                try:
                    m = api(f"projects/{enc(project)}/merge_requests/{iid}/merge?sha={cur['sha']}", "PUT")
                    done.append(f"merged {m.get('merge_commit_sha', '')[:8]}")
                except RuntimeError as e:
                    done.append(f"merge 失败（{cur['detailed_merge_status']}）：{e}")
        if not args.dry_run:
            base = sh("git", "merge-base", cur["sha"], cur["diff_refs"]["base_sha"], cwd=repo).strip() if repo else cur["diff_refs"]["base_sha"]
            state[key] = {"reviewed_sha": cur["sha"], "base_sha": base, "reviewed_at": now, "action": d["action"],
                          "sent": [f["id"] for f in sends], "session": str(session)}
            done.append("state recorded")
        report.append(f"{key}: " + "；".join(done))

    if not args.dry_run:
        save_state(state)
    print("\n".join(report))
    if publish:
        print("\n草稿已建好。发布（发出去就撤不回）：\n")
        print("! for p in " + " ".join(publish) + "; do glab api -X POST projects/$p/draft_notes/bulk_publish >/dev/null && echo \"published $p\"; done")


if __name__ == "__main__":
    main()
