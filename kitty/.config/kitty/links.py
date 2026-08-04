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

# Mirrors kitty's url_prefixes. Excluding \x1b stops a trailing SGR reset being
# swallowed; \x00 pads short screen lines.
URL = re.compile(
    r'(?:file|ftps?|gemini|git|gopher|https?|ircs?|kitty|mailto|news|sftp|ssh)'
    r'://[^\s\x00\x1b\x07"\'<>()\[\]`|]+'
)

TRAILING = '.,;:!?\'"'
SEP = '\x1f'  # fzf field separator; cannot occur in screen text


def main(args):
    # Never runs: this is a no_ui kitten, everything happens in handle_result.
    pass


def clean(s):
    return s.replace('\n', '').replace('\x00', '').strip()


def collect(text):
    """Return [(display, url)] for every link, newest (lowest) first.

    OSC 8 goes first so the URI inside the escape is not also matched as a
    bare URL.
    """
    found = []
    covered = []

    for m in OSC8.finditer(text):
        url, label = clean(m.group('url')), clean(m.group('label'))
        covered.append((m.start(), m.end()))
        if url and label:
            found.append((m.start(), f'{label}  →  {url}', url))

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
