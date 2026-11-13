"""Shared helpers for the gitlab-inbox scripts."""

import datetime as dt
import json
import os
import pathlib
import re
import subprocess

HOME = pathlib.Path.home()
# Under ~/Projects because the agent sandbox can write there; state must survive across days.
ROOT = pathlib.Path(os.environ.get("GITLAB_INBOX_HOME", HOME / "Projects/.gitlab-inbox"))
STATE = ROOT / "state.json"
POST_REVIEW = HOME / ".agents/skills/gitlab-mr-review/post_review.py"


def sh(*args, cwd=None, input=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, input=input).stdout


def api(path, method="GET", fields=None):
    args = ["glab", "api", "-X", method, path]
    for k, v in (fields or {}).items():
        args += ["-f", f"{k}={v}"]
    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"glab api {method} {path}: {proc.stderr.strip()[:500]}")
    return json.loads(proc.stdout) if proc.stdout.strip() else None


def ts(s):
    """Aware datetime from GitLab's ISO strings (`Z` or `+08:00`); compare these, never the raw strings."""
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def enc(project):
    return project.replace("/", "%2F")


def today_dir():
    return ROOT / dt.date.today().isoformat()


def load_state():
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(state):
    ROOT.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=1))


def local_repo(project):
    """~/Projects/<last path segment>, if its origin really is that project."""
    repo = HOME / "Projects" / project.split("/")[-1]
    if not (repo / ".git").exists():
        return None
    url = sh("git", "remote", "get-url", "origin", cwd=repo).strip()
    return repo if re.search(rf"[:/]{re.escape(project)}(\.git)?$", url) else None


def patch_id(repo, base, head):
    if not base or not head:
        return ""
    diff = sh("git", "diff", base, head, cwd=repo)
    out = sh("git", "patch-id", "--stable", cwd=repo, input=diff)
    return out.split()[0] if out.strip() else ""


def hunks(repo, a, b, path, ctx=12):
    """Annotated diff of one file: [{old, new, kind, text}] with kind in hunk/add/del/ctx."""
    out = sh("git", "diff", f"-U{ctx}", a, b, "--", path, cwd=repo)
    rows, o, n = [], 0, 0
    for line in out.splitlines():
        m = re.match(r"^@@ -(\d+)(?:,\d+)? \+(\d+)", line)
        if m:
            o, n = int(m[1]), int(m[2])
            rows.append({"kind": "hunk", "text": line})
            continue
        if line.startswith(("diff ", "index ", "--- ", "+++ ", "new file", "deleted file", "similarity", "rename ", "\\")):
            continue
        if line.startswith("+"):
            rows.append({"old": None, "new": n, "kind": "add", "text": line[1:]}); n += 1
        elif line.startswith("-"):
            rows.append({"old": o, "new": None, "kind": "del", "text": line[1:]}); o += 1
        else:
            rows.append({"old": o, "new": n, "kind": "ctx", "text": line[1:]}); o += 1; n += 1
    return rows


def code_text(rows):
    out = []
    for r in rows:
        if r["kind"] == "hunk":
            out.append(r["text"])
        else:
            mark = {"add": "+", "del": "-"}.get(r["kind"], " ")
            out.append(f"{r.get('old') or '':>5} {r.get('new') or '':>5} {mark}{r['text']}")
    return "\n".join(out)


def transcript_path(cwd, session_id):
    return HOME / ".claude/projects" / str(cwd).replace("/", "-").replace(".", "-") / f"{session_id}.jsonl"
