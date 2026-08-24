"""Pick a plain URL or OSC 8 hyperlink with fzf and open it.

The hints kitten can't do both: --type takes one value, and
--customize-processing is handed sanitised text with no OSC 8 URL in it.
as_text(as_ansi=True) keeps the escapes, so both kinds are recoverable here.

    map ctrl+shift+e kitten links.py
"""

import os
import re
import shlex
import shutil

from kitty.boss import Boss
from kitty.constants import cache_dir
from kittens.tui.handler import result_handler

# ESC ] 8 ; <params> ; <URI> <ST> label ESC ] 8 ; ; <ST>
# kitty re-serialises with a params field (id=...) and ends with ST, not BEL,
# so neither can be hardcoded.
OSC8 = re.compile(
    r'\x1b\]8;[^;\x07\x1b]*;(?P<url>[^\x07\x1b]*)(?:\x07|\x1b\\)'
    r'(?P<label>.*?)'
    r'\x1b\]8;[^;\x07\x1b]*;[^\x07\x1b]*(?:\x07|\x1b\\)',
    re.DOTALL,
)

# Mirrors kitty's url_prefixes. The body stops at CJK punctuation (U+3000-303F)
# and fullwidth forms (U+FF00-FF65) so a URL in Chinese prose ends at the "）";
# other CJK stays, since 路径 can be a real path segment. Controls are out so a
# trailing SGR reset isn't swallowed; \x00 pads short screen lines.
URL = re.compile(
    r'(?:file|ftps?|gemini|git|gopher|https?|ircs?|kitty|mailto|news|sftp|ssh)'
    r'://[^\s\x00-\x20\x7f-\x9f"\'<>()\[\]`|\u3000-\u303f\uff00-\uff65]+'
)

# An OSC 8 URI is percent-encoded ASCII, and emitters get that wrong: Claude
# Code pads them with 30 x U+D7BF U+FFFD, which `open` then chokes on.
URI = re.compile(r'[!-~]+')

# fzf rows are one line, and Claude Code's hyperlinks run past the link text
# into the sentence after it.
MAX_LABEL = 120

# as_ansi=True keeps OSC 8, but also every SGR on the line. fzf runs without
# --ansi, so an unstripped ESC[34m shows up as a literal "[34m" prefix.
CSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')

TRAILING = '.,;:!?\'"'
SEP = '\x1f'  # fzf field separator; cannot occur in screen text


def main(args):
    # Never runs: this is a no_ui kitten, everything happens in handle_result.
    pass


def clean(s):
    s = CSI.sub('', s)
    return s.replace('\n', '').replace('\x00', '').strip()


def clean_uri(s):
    m = URI.match(clean(s))
    return m.group() if m else ''


def clean_label(s):
    label = ' '.join(clean(s).split())
    return label[:MAX_LABEL] + '…' if len(label) > MAX_LABEL else label


def collect(text):
    """Return [(display, url)] for every link, newest (lowest) first.

    OSC 8 goes first so the URI inside the escape is not also matched as a
    bare URL.
    """
    found = []
    covered = []

    for m in OSC8.finditer(text):
        url, label = clean_uri(m.group('url')), clean_label(m.group('label'))
        covered.append((m.start(), m.end()))
        if url:
            # startswith, not ==: that is the shape of an over-long label.
            noisy = not label or label.startswith(url)
            display = url if noisy else f'{label}  →  {url}'
            found.append((m.start(), display, url))

    for m in URL.finditer(text):
        start, end = m.span()
        if any(start < c_end and c_start < end for c_start, c_end in covered):
            continue
        url = clean(m.group()).rstrip(TRAILING)
        if url:
            found.append((start, url, url))

    # Bottom of the screen is newest, so show it first.
    found.sort(key=lambda f: f[0], reverse=True)

    seen = set()
    items = []
    for _, display, url in found:
        if url not in seen:
            seen.add(url)
            items.append((display, url))
    return items


def write_spool(window_id, items):
    d = os.path.join(cache_dir(), 'links', str(window_id))
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, 'records')
    with open(path, 'w') as f:
        f.write('\n'.join(f'{display}{SEP}{url}' for display, url in items))
    return d


def picker_script(d):
    q = shlex.quote
    fzf = shutil.which('fzf') or '/opt/homebrew/bin/fzf'
    opener = shutil.which('open') or '/usr/bin/open'
    copy = shutil.which('pbcopy') or '/usr/bin/pbcopy'
    records = q(os.path.join(d, 'records'))
    selected = q(os.path.join(d, 'selected'))
    # --with-nth=1 hides the URL field, --accept-nth=2 hands it back on select.
    return f'''
if {q(fzf)} --no-sort --no-mouse --exact -i \\
      --delimiter={q(SEP)} --with-nth=1 --accept-nth=2 \\
      --highlight-line --wrap \\
      --bind 'ctrl-y:become(printf %s {{2}} | {q(copy)})' \\
      --header='enter: open   ctrl-y: copy' \\
      < {records} > {selected}; then
  {q(opener)} "$(cat {selected})"
fi
rm -f {selected}
'''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    # as_ansi=True is what preserves the OSC 8 escapes.
    items = collect(w.as_text(as_ansi=True, add_history=True))
    if not items:
        boss.show_error('No links', 'No URLs or hyperlinks found on screen.')
        return

    d = write_spool(w.id, items)
    boss.call_remote_control(w, (
        'launch', f'--match=id:{w.id}', '--type=overlay',
        '--title', 'Links',
        'sh', '-c', picker_script(d),
    ))
