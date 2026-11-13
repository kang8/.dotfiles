#!/usr/bin/env python3
"""Local review console for one gitlab-inbox session.

Usage: console_server.py SESSION_DIR [--port 8765]
Serves console.html + SESSION_DIR/data.json. Must run outside the agent sandbox (a herdr pane): it binds a
local port and calls the user's `claude` CLI.

- /api/ask       follow-up in a fresh Claude session per finding ({finding}) or per MR ({mr}), seeded with its
                 context and the reviewer transcript path; later questions resume it (ids in threads.json).
- /api/rewrite   rewrite one draft comment.
- /api/draft_mr  draft or rewrite an MR-level note to the author, inside that MR's chat session.
- /api/status    compare each MR with the head the reviewer read: pushes (rebase vs code change, per-finding
                 re-anchoring), notes from others, new approvals, merged/closed. Cached 30 s.
- /api/recheck   fresh session judges whether one finding still holds after those changes.
- /api/decisions writes SESSION_DIR/decisions.json for execute.py.
Read-only towards GitLab.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from common import api, code_text, enc, hunks, patch_id, sh, ts  # noqa: E402

HERE = pathlib.Path(__file__).parent
ap = argparse.ArgumentParser()
ap.add_argument("session", type=pathlib.Path)
ap.add_argument("--port", type=int, default=8765)
ARGS = ap.parse_args()
SESSION = ARGS.session
DATA = json.loads((SESSION / "data.json").read_text())
FINDINGS = {f["id"]: f for f in DATA["findings"]}
MRS = {m["key"]: m for m in DATA["mrs"]}
ME = DATA["me"]
THREADS_FILE = SESSION / "threads.json"
# Chat id -> claude session id; on disk so a restarted server resumes the same conversations.
threads: dict[str, str] = json.loads(THREADS_FILE.read_text()) if THREADS_FILE.exists() else {}
status_cache: dict = {"at": 0.0, "value": None}
lock = threading.Lock()
TOOLS = ["Read", "Grep", "Glob", "Bash(git show:*)", "Bash(git diff:*)", "Bash(git log:*)",
         "Bash(glab mr view:*)", "Bash(glab mr diff:*)"]


def mr_of(f):
    return next(m for m in DATA["mrs"] if m["iid"] == f["iid"] and m["project"] == f["project"])


def session_of(f):
    return DATA["sessions"].get(mr_of(f).get("reviewer") or "", {})


def context_block(f, extra_notes=None):
    m, s = mr_of(f), session_of(f)
    notes = m["discussions"] + (extra_notes or [])
    notes_txt = "\n".join(f"- [{n.get('discussion_id', '')}] {n['author']} {n['at']}: {n['body'][:1500]}" for n in notes) or "（无）"
    related = "\n\n".join(f"{r['file']}（源分支）:\n" + code_text(r["lines"]) for r in f["related"]) or "（无）"
    transcript = f"reviewer 的完整 transcript（jsonl，很大）：{s['transcript']}\n需要知道 reviewer 当时怎么查、怎么想时用 Grep 搜关键词，不要整个读。" if s else ""
    return f"""MR：{m['key']} {m['title']}（作者 {m['author']}）
review 时的 head：{m['reviewed_sha']}，base：{m['base_sha']}。读 MR 代码用 `git show <sha>:<path>`，工作区是用户别的分支。
finding #{f['id']}，位置 `{f['file']}:{f['new_line'] or f['old_line']}`，草稿评论：
---
{f['body']}
---
review 时的代码（旧行号 新行号 标记 内容）：
{code_text(f['code'])}

评论引用的其他代码：
{related}

MR 讨论区（方括号里是 discussion_id）：
{notes_txt}

{transcript}
reviewer 报告：
{m['report'][:6000]}"""


def mr_context(m):
    s = DATA["sessions"].get(m.get("reviewer") or "", {})
    notes_txt = "\n".join(f"- {n['author']} {n['at']}: {n['body'][:1500]}" for n in m["discussions"]) or "（无）"
    drafts = "\n".join(f"- #{f['id']} `{f['file']}:{f['new_line'] or f['old_line']}`：{f['body'][:400]}"
                       for f in DATA["findings"] if f["project"] == m["project"] and f["iid"] == m["iid"]) or "（无）"
    transcript = f"reviewer 的完整 transcript（jsonl，很大）：{s['transcript']}\n需要知道 reviewer 当时怎么查、怎么想时用 Grep 搜关键词，不要整个读。" if s else ""
    return f"""MR：{m['key']} {m['title']}（作者 {m['author']}）{m['url']}
review 时的 head：{m['reviewed_sha']}，base：{m['base_sha']}。读 MR 代码用 `git show <sha>:<path>` 或 `git diff {m['base_sha']} {m['reviewed_sha']}`，工作区是用户别的分支。
改动的文件：{', '.join(m['files'][:60])}

MR 描述：
---
{m['description'][:8000]}
---

MR 讨论区：
{notes_txt}

reviewer 已有的 finding 草稿：
{drafts}

{transcript}
reviewer 报告：
{m['report'][:6000]}"""


def claude(prompt, cwd, session_id=None, resume=None):
    args = ["claude", "-p", "--output-format", "json", "--permission-mode", "plan",
            "--add-dir", str(pathlib.Path.home() / ".claude/projects"), "--allowedTools", *TOOLS]
    if resume:
        args += ["--resume", resume]
    elif session_id:
        args += ["--session-id", session_id]
    proc = subprocess.run(args, input=prompt, cwd=cwd, capture_output=True, text=True, timeout=900)
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {"error": (proc.stderr or proc.stdout or "no output")[-2000:]}


ASK_RULES = """你在帮用户处理 MR review。用户在网页上逐条看 finding，针对下面这条追问。
只读：不要修改文件，不要对 GitLab 做写操作。用中文（全角标点）回答，先给结论再给依据，引用代码写 `path:line`，不要复述问题。

"""


ASK_MR_RULES = """你在帮用户处理 MR review。下面这个 MR 用户想就整体提问（方案、描述里的取舍、有没有更省的做法），不针对某一行。
只读：不要修改文件，不要对 GitLab 做写操作。用中文（全角标点）回答，先给结论再给依据，引用代码写 `path:line`，不要复述问题。
涉及成本、数据量、外部服务行为的判断，查得到就查（代码、仓库文档、glab），查不到就明确说没核实。

"""


def remember(chat_id, sid):
    with lock:
        threads[chat_id] = sid
        THREADS_FILE.write_text(json.dumps(threads, indent=1))


def ask(chat_id, question):
    """chat_id is a finding id, or 'mr:<key>' for a question about the whole MR."""
    m = MRS[chat_id[3:]] if chat_id.startswith("mr:") else mr_of(FINDINGS[chat_id])
    with lock:
        sid = threads.get(chat_id)
    if sid:
        out = claude(question, m["repo"], resume=sid)
    else:
        sid = str(uuid.uuid4())
        seed = ASK_MR_RULES + mr_context(m) if chat_id.startswith("mr:") else ASK_RULES + context_block(FINDINGS[chat_id])
        out = claude(seed + "\n\n用户的问题：" + question, m["repo"], session_id=sid)
        if "error" not in out:
            remember(chat_id, sid)
    if "error" in out:
        return out
    return {"answer": out.get("result", ""), "cost": out.get("total_cost_usd")}


def comment_shape():
    shape = (pathlib.Path.home() / ".agents/skills/gitlab-mr-review/SKILL.md").read_text()
    return shape[shape.find("### Comment shape"):shape.find("## Step 4")]


def draft_mr(key, instruction, current):
    """Draft or rewrite an MR-level note to the author; resumes the MR chat so earlier answers inform it."""
    m = MRS[key]
    cur = f"当前草稿：\n---\n{current}\n---\n" if current.strip() else ""
    task = f"""按用户要求{'改写这条' if current.strip() else '起草一条'}发给作者的 MR 评论（MR 级普通评论，不挂行）。
只输出评论正文（Markdown），不要解释，不要代码块包裹。语言跟 MR 描述和讨论区一致。按下面的评论写法：
{comment_shape()}
{cur}用户要求：{instruction}"""
    with lock:
        sid = threads.get("mr:" + key)
    if sid:
        out = claude(task, m["repo"], resume=sid)
    else:
        sid = str(uuid.uuid4())
        out = claude(ASK_MR_RULES + mr_context(m) + "\n\n" + task, m["repo"], session_id=sid)
        if "error" not in out:
            remember("mr:" + key, sid)
    if "error" in out:
        return out
    return {"body": out.get("result", "").strip(), "cost": out.get("total_cost_usd")}


def rewrite(fid, instruction, current):
    f = FINDINGS[fid]
    out = claude(f"""把这条 MR 评论草稿按用户要求改写，只输出改写后的正文（Markdown），不要解释。按下面的评论写法：
{comment_shape()}

{context_block({**f, 'body': current or f['body']})}

用户要求：{instruction}""", mr_of(f)["repo"])
    return {"body": out.get("result", "").strip()} if "error" not in out else out


def reanchor(repo, f, new_sha):
    rows = [r for r in f["code"] if r.get("new") is not None]
    idx = next((i for i, r in enumerate(rows) if r["new"] == f["new_line"]), None)
    if idx is None:
        return {"state": "unknown"}
    target = rows[idx]["text"]
    before = [r["text"] for r in rows[max(0, idx - 3):idx]]
    after = [r["text"] for r in rows[idx + 1:idx + 4]]
    new_lines = sh("git", "show", f"{new_sha}:{f['file']}", cwd=repo).splitlines()
    if not new_lines:
        return {"state": "gone", "why": "文件在新代码里不存在了"}
    hits = [i for i, l in enumerate(new_lines) if l == target]
    if not hits:
        return {"state": "changed", "why": "被评论的那一行在新代码里找不到了"}
    best = min(hits, key=lambda i: abs(i + 1 - f["new_line"]))
    same = new_lines[max(0, best - len(before)):best] == before and new_lines[best + 1:best + 1 + len(after)] == after
    return {"state": "same" if same else "changed", "new_line": best + 1,
            "why": None if same else "被评论的那一行还在，但上下文有改动"}


def mr_status(m):
    repo = m["repo"]
    cur = api(f"projects/{enc(m['project'])}/merge_requests/{m['iid']}")
    st = {"state": cur["state"], "merged_by": (cur.get("merged_by") or {}).get("username"),
          "merged_at": (cur.get("merged_at") or "")[11:16], "head": cur["sha"], "push": None, "findings": {}}
    disc = api(f"projects/{enc(m['project'])}/merge_requests/{m['iid']}/discussions?per_page=100") or []
    st["new_notes"] = [
        {"author": n["author"]["username"], "at": n["created_at"][11:16], "body": n["body"], "discussion_id": d["id"],
         "path": (n.get("position") or {}).get("new_path"), "line": (n.get("position") or {}).get("new_line")}
        for d in disc for n in d["notes"]
        if not n["system"] and ts(n["created_at"]) >= ts(m["cutoff"]) and n["author"]["username"] != ME
    ]
    appr = api(f"projects/{enc(m['project'])}/merge_requests/{m['iid']}/approvals") or {}
    st["new_approvals"] = sorted({a["user"]["username"] for a in appr.get("approved_by", [])} - set(m["approved_by"]) - {ME})
    if cur["sha"] != m["reviewed_sha"]:
        sh("git", "fetch", "-q", "origin", f"refs/merge-requests/{m['iid']}/head", cwd=repo)
        new_base = sh("git", "merge-base", cur["sha"], cur["diff_refs"]["base_sha"], cwd=repo).strip()
        rebase_only = patch_id(repo, m["base_sha"], m["reviewed_sha"]) == patch_id(repo, new_base, cur["sha"])
        commits = sh("git", "log", "--format=%h %an %s", f"{m['reviewed_sha']}..{cur['sha']}", "--", *m["files"], cwd=repo).strip().splitlines()
        st["push"] = {"rebase_only": rebase_only, "commits": commits[:10],
                      "files": sh("git", "diff", "--name-only", m["reviewed_sha"], cur["sha"], "--", *m["files"], cwd=repo).split()}
        for f in DATA["findings"]:
            if f["iid"] == m["iid"] and f["project"] == m["project"] and f.get("new_line"):
                a = reanchor(repo, f, cur["sha"])
                if a["state"] != "same" and not rebase_only:
                    a["interdiff"] = hunks(repo, m["reviewed_sha"], cur["sha"], f["file"], ctx=5)
                st["findings"][f["id"]] = a
    return st


def status(force=False):
    with lock:
        if not force and status_cache["value"] and time.time() - status_cache["at"] < 30:
            return status_cache["value"]
    value = {}
    for m in DATA["mrs"]:
        try:
            value[m["key"]] = mr_status(m)
        except Exception as e:  # one broken MR must not blank the whole page
            value[m["key"]] = {"error": str(e)}
    value["_checked_at"] = time.strftime("%H:%M:%S")
    with lock:
        status_cache.update(at=time.time(), value=value)
    return value


def recheck(fid):
    f = FINDINGS[fid]
    m = mr_of(f)
    st = (status_cache["value"] or status()).get(m["key"], {})
    fa = st.get("findings", {}).get(fid, {})
    interdiff = code_text(fa.get("interdiff") or []) or "（代码没有变化）"
    new_notes = st.get("new_notes", [])
    out = claude(f"""用户正准备发这条 MR review 评论，但在那之后 MR 有了变化。判断这条评论现在还该不该发。只读。

{context_block(f, new_notes)}

review 之后的变化：
- 当前 head：{st.get('head')}（review 时 {m['reviewed_sha']}）
- 新提交：{json.dumps(st.get('push'), ensure_ascii=False)}
- 这条 finding 所在位置：{json.dumps({k: v for k, v in fa.items() if k != 'interdiff'}, ensure_ascii=False)}
- 该文件从 review 时到现在的 diff：
{interdiff}
- review 之后别人的新评论：讨论区最后 {len(new_notes)} 条。

只输出一个 JSON 对象，不要代码块：
{{"status": "still_valid" | "fixed" | "obsolete" | "duplicate", "new_line": 当前 head 上该挂的行号或 null,
  "reason": "一句中文理由", "suggested_body": "需要改写时给出新正文，否则空字符串",
  "reply_to_discussion_id": "适合改成在某条已有 thread 下回复时填它的 discussion_id，否则空字符串"}}
fixed=作者已改好；duplicate=别人已提过（若草稿还有新增内容，用 suggested_body + reply_to_discussion_id 改成补充回复）；obsolete=代码已删或不再适用。""",
                 m["repo"])
    if "error" in out:
        return out
    text = re.sub(r"^```(?:json)?|```$", "", out.get("result", "").strip()).strip()
    try:
        verdict = json.loads(text[text.find("{"):text.rfind("}") + 1])
    except (json.JSONDecodeError, ValueError):
        verdict = {"status": "unknown", "reason": text[:500]}
    verdict["cost"] = out.get("total_cost_usd")
    return verdict


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        raw = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        path, _, query = self.path.partition("?")
        if path in ("/", "/index.html"):
            return self._send(200, (HERE / "console.html").read_bytes(), "text/html")
        if path == "/data.json":
            return self._send(200, (SESSION / "data.json").read_bytes())
        if path == "/decisions.json":
            p = SESSION / "decisions.json"
            return self._send(200, p.read_bytes() if p.exists() else b"null")
        if path == "/api/status":
            return self._send(200, status(force="force=1" in query))
        self._send(404, {"error": "not found"})

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or "{}")
        if self.path == "/api/decisions":
            body["saved_at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
            (SESSION / "decisions.json").write_text(json.dumps(body, ensure_ascii=False, indent=1))
            print(f"[console] decisions saved → {SESSION / 'decisions.json'}", flush=True)
            return self._send(200, {"ok": True, "path": str(SESSION / "decisions.json")})
        mr_key = body.get("mr")
        if mr_key is not None:
            if mr_key not in MRS:
                return self._send(400, {"error": "unknown mr"})
            if self.path == "/api/ask":
                return self._send(200, ask("mr:" + mr_key, body["question"]))
            if self.path == "/api/draft_mr":
                return self._send(200, draft_mr(mr_key, body["instruction"], body.get("current") or ""))
            return self._send(404, {"error": "not found"})
        fid = body.get("finding")
        if fid not in FINDINGS:
            return self._send(400, {"error": "unknown finding"})
        if self.path == "/api/ask":
            return self._send(200, ask(fid, body["question"]))
        if self.path == "/api/rewrite":
            return self._send(200, rewrite(fid, body["instruction"], body.get("current")))
        if self.path == "/api/recheck":
            return self._send(200, recheck(fid))
        self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        print("[console]", fmt % args, flush=True)


if __name__ == "__main__":
    print(f"gitlab-inbox console ready {time.strftime('%H%M%S')} → http://127.0.0.1:{ARGS.port}/?variant=A", flush=True)
    ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler).serve_forever()
