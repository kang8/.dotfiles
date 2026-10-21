#!/usr/bin/env python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Pele Playground
# @raycast.mode silent
# @raycast.description Open pele.run's playground with the given diagram, the clipboard, or its example
#
# Optional parameters:
# @raycast.packageName Customized
# @raycast.icon 🌋
# @raycast.argument1 { "type": "text", "placeholder": "diagram (\\n for newline, empty = clipboard)", "optional": true }

import re
import subprocess
import sys
import urllib.parse

PLAYGROUND = "https://pele.run/playground"

DIAGRAM_START = re.compile(
    r"""^\s*(%%|---|
        graph|flowchart|sequenceDiagram|classDiagram|stateDiagram(-v2)?|erDiagram|
        journey|gantt|pie|quadrantChart|requirementDiagram|gitGraph|mindmap|
        timeline|zenuml|sankey(-beta)?|xychart(-beta)?|block(-beta)?|packet(-beta)?|
        kanban|architecture(-beta)?|radar(-beta)?|treemap|C4Context)\b""",
    re.VERBOSE,
)


def clipboard() -> str:
    return subprocess.run(["pbpaste"], capture_output=True, text=True).stdout


def editor_url(code: str) -> str:
    # The playground reads the hash with URLSearchParams, the same encoding as urlencode.
    return PLAYGROUND + "#" + urllib.parse.urlencode({"source": code})


def restore_newlines(code: str) -> str:
    # Raycast's argument field is single-line: a pasted diagram arrives with every
    # newline flattened to a space. The runs of 2+ spaces are the old indentation.
    pasted = clipboard()
    if collapse(pasted) == collapse(code):
        return pasted
    return re.sub(r" {2,}", "\n", code)


def collapse(text: str) -> str:
    return " ".join(text.split())


if __name__ == "__main__":
    code = sys.argv[1].replace("\\n", "\n") if len(sys.argv) > 1 else ""

    if not code.strip():
        code = clipboard()
    elif "\n" not in code:
        code = restore_newlines(code)

    # A clipboard holding something else should not become a broken diagram.
    url = editor_url(code.strip()) if DIAGRAM_START.match(code) else PLAYGROUND

    subprocess.run(["open", url])
