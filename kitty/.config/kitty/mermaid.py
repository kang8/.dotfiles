"""Render the mermaid diagrams from Claude Code's latest reply in a new window.

Reads the transcript of the Claude Code session in the active window, so it
gets the raw source instead of the markdown-rendered screen text. Without a
session or a diagram it renders the clipboard instead. Needs ~/.local/bin/mmd.

    map cmd+shift+m kitten mermaid.py
"""

import glob
import json
import os
import re
import shlex
import tempfile

from kitty.boss import Boss
from kittens.tui.handler import result_handler

SESSIONS = os.path.expanduser('~/.claude/sessions')
PROJECTS = os.path.expanduser('~/.claude/projects')
MMD = os.path.expanduser('~/.local/bin/mmd')

# Fences can be indented when the diagram sits inside a list item.
FENCE = re.compile(r'^[ \t]*```mermaid[ \t]*\n(.*?)^[ \t]*```', re.M | re.S)


def main(args):
    # Never runs: this is a no_ui kitten, everything happens in handle_result.
    pass


def transcript(window):
    # Claude Code writes ~/.claude/sessions/<pid>.json for each running process.
    for proc in window.child.foreground_processes:
        try:
            with open(f'{SESSIONS}/{proc["pid"]}.json') as f:
                sid = json.load(f)['sessionId']
        except (OSError, ValueError, KeyError):
            continue
        hits = glob.glob(f'{PROJECTS}/*/{sid}.jsonl')
        if hits:
            return hits[0]
    return None


def latest_diagrams(path):
    # All diagrams of the last assistant text block that has any.
    last = []
    with open(path) as f:
        for line in f:
            if '```mermaid' not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get('type') != 'assistant':
                continue
            for block in entry.get('message', {}).get('content', []):
                if block.get('type') == 'text':
                    last = FENCE.findall(block['text']) or last
    return last


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss: Boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    path = transcript(window)
    diagrams = latest_diagrams(path) if path else []

    tmp = tempfile.mkdtemp(prefix='kitty-mermaid-')
    files = []
    for i, src in enumerate(diagrams):
        files.append(os.path.join(tmp, f'{i}.mmd'))
        with open(files[-1], 'w') as f:
            f.write(src)

    prepare = ''
    if not files:
        files.append(os.path.join(tmp, '0.mmd'))
        prepare = f'echo "no diagram in the session, rendering the clipboard"; pbpaste > {shlex.quote(files[0])}; '

    # Each diagram is followed by its source, separated by a dim rule.
    script = (
        f'{prepare}echo rendering...; '
        f'for f in {" ".join(map(shlex.quote, files))}; do '
        f'{shlex.quote(MMD)} "$f"; printf "\\n\\e[2m%s\\e[0m\\n" "$(printf "─%.0s" $(seq 40))"; '
        'cat "$f"; printf "\\n\\n"; done; '
        f'rm -rf {shlex.quote(tmp)}; printf "press any key to close"; read -rsn1'
    )
    boss.launch('--title=mermaid', 'bash', '-c', script)
