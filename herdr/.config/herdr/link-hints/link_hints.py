"""Hint the links in the focused herdr pane with kitty's hints kitten.

herdr's pane.read drops OSC 8, so a hyperlink's URL is not in the text.
pane.link.activate returns the URL under a cell, OSC 8 or plain, without
opening anything unless a plugin registered a link handler for it; that is
how links are found. It refuses a pane that is off screen, and the zoomed
overlay hides the pane, so probing runs before the overlay opens.
"""

import fcntl
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unicodedata

SOCK = os.environ['HERDR_SOCKET_PATH']
PLUGIN = os.environ['HERDR_PLUGIN_ID']
PICK_TIMEOUT = 600

URL_START = re.compile(r'[A-Za-z][A-Za-z0-9+.-]*://|www\.')
# pane.read --format ansi: SGR runs, and any other escape to drop.
ESCAPE = re.compile(r'\x1b\[([0-?]*)([ -/]*[@-~])|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b.')
# Claude Code pads its OSC 8 URIs with U+D7BF U+FFFD, which `open` chokes on.
URI = re.compile(r'[^\s\ud7bf\ufffd]+')


class HerdrError(Exception):
    def __init__(self, error):
        super().__init__(error.get('message', error))
        self.code = error.get('code')


def call(method, **params):
    # The server answers one request per connection.
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(SOCK)
        req = {'id': '1', 'method': method, 'params': params}
        s.sendall(json.dumps(req).encode() + b'\n')
        resp = json.loads(s.makefile('rb').readline())
    if 'error' in resp:
        raise HerdrError(resp['error'])
    return resp['result']


def open_overlay(**env):
    # Overlays always cover the active pane; target_pane_id is rejected.
    call('plugin.pane.open', plugin_id=PLUGIN, entrypoint='picker', focus=True, env=env)


def show(message):
    try:
        open_overlay(LINK_HINTS_MESSAGE=message)
    except HerdrError:
        call('notification.show', title='Link hints', body=message)


def width(ch):
    if unicodedata.combining(ch) or unicodedata.category(ch) in ('Mn', 'Me', 'Cf'):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ('W', 'F') else 1


def columns(line):
    """Return the display column at which each char of line starts."""
    cols, col = [], 0
    for ch in line:
        cols.append(col)
        col += width(ch)
    return cols


def read_screen(pane):
    """Return the visible lines and, per line, the indices where a color run starts."""
    text = call('pane.read', pane_id=pane, source='visible', format='ansi')['read']['text']
    lines, runs = [], []
    for raw in text.replace('\r', '').split('\n'):
        line, starts, pos = [], set(), 0
        for m in ESCAPE.finditer(raw):
            line.append(raw[pos:m.start()])
            pos = m.end()
            if m.group(2) == 'm':
                starts.add(sum(map(len, line)))
        line.append(raw[pos:])
        lines.append(''.join(line))
        runs.append(starts)
    return lines, runs


def candidates(line, runs):
    """Yield the char indices where a link could start, with the run end.

    Each probe costs 0.1-5 ms depending on how busy the server is, so only
    likely starts are probed. Plain URLs are found by their scheme; a
    hyperlink's URL is not on screen, but Claude Code and ls-style tools color
    its label, so it starts a color run.
    """
    run_starts = sorted(set(runs) | {len(line)})
    for i in sorted(set(runs) | {m.start() for m in URL_START.finditer(line)}):
        if i < len(line) and not line[i].isspace():
            yield i, next(s for s in run_starts if s > i)


def find_links(pane, lines, runs):
    """Return [(row, start, end, url)] with start/end as char indices."""
    def probe(item):
        row, i, run_end = item
        cols = columns(lines[row])
        url = call('pane.link.activate', pane_id=pane, viewport_row=row, col=cols[i]).get('url')
        m = URI.match(url or '')
        if not m:
            return None
        # resolve knows the extent of a plain URL; a hyperlink label is taken
        # to fill its color run.
        regions = call('pane.link.resolve', pane_id=pane, viewport_row=row, col=cols[i])['regions']
        region = next((r for r in regions if r['row'] == row), None)
        if region:
            start = max(j for j, c in enumerate(cols) if c <= region['start_col'])
            end = max(j for j, c in enumerate(cols) if c <= region['end_col']) + 1
        else:
            start, end = i, run_end
            while end > start and lines[row][end - 1].isspace():
                end -= 1
        return row, start, end, m.group()

    items = [
        (row, i, run_end)
        for row, (line, starts) in enumerate(zip(lines, runs))
        for i, run_end in candidates(line, starts)
    ]
    # Serially: 100 probes take ~10 ms, while concurrent connections stall
    # the server in steps of ~100 ms.
    found = sorted({link for link in map(probe, items) if link})
    # A color run inside a link probes the same link twice; keep the outer one.
    return [
        a for a in found
        if not any(b != a and b[0] == a[0] and b[1] <= a[1] and a[2] <= b[2] for b in found)
    ]


def hints_input(lines, links, pad_x, pad_y):
    """Lay the pane text out where it sits in the tab, with links as OSC 8."""
    by_row = {}
    for row, start, end, url in links:
        by_row.setdefault(row, []).append((start, end, url))
    out = []
    for row, line in enumerate(lines):
        # Insert from the end so earlier indices stay valid.
        for start, end, url in sorted(by_row.get(row, []), reverse=True):
            line = f'{line[:start]}\x1b]8;;{url}\x1b\\{line[start:end]}\x1b]8;;\x1b\\{line[end:]}'
        out.append(' ' * pad_x + line)
    return '\n' * pad_y + '\n'.join(out)


def offset_in_tab(pane):
    layout = call('pane.layout', pane_id=pane)['layout']
    if layout['zoomed']:
        return 0, 0
    area = layout['area']
    rect = next(p['rect'] for p in layout['panes'] if p['pane_id'] == pane)
    return rect['x'] - area['x'], rect['y'] - area['y']


def pick(text):
    d = tempfile.mkdtemp(prefix='link-hints-')
    try:
        with open(os.path.join(d, 'input'), 'w') as f:
            f.write(text)
        open_overlay(LINK_HINTS_DIR=d)
        result = os.path.join(d, 'result')
        deadline = time.monotonic() + PICK_TIMEOUT
        while not os.path.exists(result):
            if time.monotonic() > deadline:
                return None
            time.sleep(0.05)
        with open(result) as f:
            out = f.read()
    finally:
        shutil.rmtree(d, ignore_errors=True)
    # Esc exits non-zero with nothing on stdout. On a pick the kitten prints
    # the JSON followed by " <nil>", its Println'd error value.
    try:
        return json.JSONDecoder().raw_decode(out)[0]['match'][0]
    except (ValueError, KeyError, IndexError):
        return None


def main(pane):
    lines, runs = read_screen(pane)
    links = find_links(pane, lines, runs)
    if not links:
        show('No links in this pane')
        return
    url = pick(hints_input(lines, links, *offset_in_tab(pane)))
    if url:
        subprocess.run(['open' if sys.platform == 'darwin' else 'xdg-open', url])


if __name__ == '__main__':
    # Holding the key repeats it, and the binding still fires inside the
    # overlay; one run at a time.
    lock = open(os.path.join(os.environ['HERDR_PLUGIN_STATE_DIR'], 'lock'), 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)
    pane = os.environ.get('HERDR_PANE_ID') or call('pane.current')['pane']['pane_id']
    try:
        main(pane)
    except HerdrError as e:
        show(f'herdr: {e}')
        raise
