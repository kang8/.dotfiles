# Pick one of the recent command outputs with fzf and copy it. Needs
# shell_integration. Usage: map cmd+shift+o kitten recent_outputs.py 15
import os
import shutil
import shlex

from kitty.boss import Boss
from kitty.constants import cache_dir
from kitty.window import CommandOutput
from kittens.tui.handler import result_handler

DEFAULT_COUNT = 15
# Lines per item when collapsed. fzf only matches what it renders, so this
# also caps the search depth in that mode.
DISPLAY_LINES = 8


def main(args):
    pass


def collect(w, count):
    """Return up to `count` command outputs, newest first."""
    w.scroll_end()
    seen = set()
    items = []

    def add(text):
        if text and text.strip() and text not in seen:
            seen.add(text)
            items.append(text)

    # scroll_to_prompt() is viewport-relative and jumps straight past every
    # prompt already on screen, so those are probed row by row instead.
    onscreen = []
    for y in range(w.screen.lines):
        w.screen.set_last_visited_prompt(y)
        text = w.cmd_output(CommandOutput.last_visited)
        if text and text not in onscreen:
            onscreen.append(text)
    for text in reversed(onscreen):
        add(text)

    # It always returns None, so progress is detected via scrolled_by.
    previous_offset = -1
    for _ in range(count * 4 + 20):
        if len(items) >= count:
            break
        w.scroll_to_prompt(-1)
        offset = w.screen.scrolled_by
        if offset == previous_offset:
            break
        previous_offset = offset
        add(w.cmd_output(CommandOutput.last_visited))

    w.scroll_end()
    w.finish_scroll_animation()
    return items[:count]


def write_spool(w, items):
    d = os.path.join(cache_dir(), 'recent-outputs', str(w.id))
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d, exist_ok=True)
    records = [
        f'❯ -{i}  [{len(text.splitlines())} lines]\n{text}'
        for i, text in enumerate(items, 1)
    ]
    with open(os.path.join(d, 'records'), 'w') as f:
        f.write('\0'.join(records))
    return d


def picker_script(d):
    q = shlex.quote
    records = q(os.path.join(d, 'records'))
    selected = q(os.path.join(d, 'selected'))
    edited = q(os.path.join(d, 'output.txt'))
    # --delimiter='\n' turns each output line into a field: --with-nth caps
    # how much of an item is rendered, --accept-nth=2.. drops the header.
    # ctrl-o must use execute() not become(), or nvim would inherit fzf's
    # stdout redirection. {f} still has the header, hence sed 1d.
    #
    # Bare command names, never absolute paths: this kitten runs inside kitty,
    # whose PATH comes from launchd and has no brew prefix in it. The script
    # itself runs in a launched child, which does get the env from kitty.conf.
    return f'''
if fzf --read0 --print0 --no-sort --no-mouse --exact -i \\
      --delimiter='\\n' --with-nth=.. --accept-nth=2.. \\
      --gap --gap-line='─' --highlight-line --wrap \\
      --bind 'ctrl-e:change-with-nth(1..{DISPLAY_LINES}|..)' \\
      --bind 'ctrl-o:execute(sed 1d {{f}} > {edited}; nvim {edited})' \\
      --header='enter: copy   ctrl-o: nvim   ctrl-e: collapse/expand' \\
      < {records} > {selected}; then
  tr -d '\\000' < {selected} | pbcopy
fi
rm -f {selected} {edited}
'''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss):
    count = DEFAULT_COUNT
    if len(args) > 1:
        try:
            count = int(args[1])
        except ValueError:
            pass

    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    items = collect(w, count)
    if not items:
        boss.show_error('No command output',
                        'Nothing found -- shell integration must be enabled.')
        return

    d = write_spool(w, items)
    boss.call_remote_control(w, (
        'launch', f'--match=id:{w.id}', '--type=overlay',
        '--title', 'Recent command outputs',
        'sh', '-c', picker_script(d),
    ))
