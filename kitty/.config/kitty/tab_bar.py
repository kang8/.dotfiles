# Tab title for {custom} in tab_title_template: the OSC 7501 program status,
# then the "dir: topic" context that claude/.claude/set-session-context.sh
# publishes from the window behind that status (the active one if none has a
# status), else the window title.
# Also loaded as a watcher, since kitty doesn't redraw tabs on SetUserVar or
# on its own to animate the working spinner.
import time

from kitty.fast_data_types import add_timer, get_boss
from kitty.program_status import URGENCY, State

CONTEXT_VAR = 'claude_context'
# kitty's done symbol is a one-cell Nerd Font glyph padded with two spaces;
# ✅ is two cells wide, so it takes one
DONE_SYMBOL = ('\uf00c  ', '✅ ')
WORKING_SYMBOL = '\uf110  '
SPINNER = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINNER_INTERVAL = 0.1


def draw_title(data):
    status = data['tab'].program_status.replace(*DONE_SYMBOL).replace(WORKING_SYMBOL, spinner_frame())
    tab = get_boss().tab_for_id(data['tab_id'])
    context = None
    if tab and (candidates := [w for w in tab if w.user_vars.get(CONTEXT_VAR)]):
        # the window whose status the tab shows, ranked like combined_status_symbol()
        best = max(candidates, key=lambda w: (*urgency(w), w is tab.active_window))
        context = best.user_vars[CONTEXT_VAR]
    return status + (context or data['title'])


def urgency(window):
    ps = window.program_status
    r = ps.most_urgent()
    return (URGENCY[r.state], ps.update_seq[r.id]) if r else (-1, -1)


def spinner_frame():
    return SPINNER[int(time.monotonic() / SPINNER_INTERVAL) % len(SPINNER)] + ' '


def on_load(boss, data):
    add_timer(redraw_working_tabs, SPINNER_INTERVAL, True)


def redraw_working_tabs(timer_id):
    for tm in get_boss().all_tab_managers:
        if any(r.state is State.working for tab in tm for w in tab for r in w.program_status):
            tm.mark_tab_bar_dirty()


def on_set_user_var(boss, window, data):
    if data['key'] == CONTEXT_VAR and (tab := window.tabref()) is not None:
        tab.mark_tab_bar_dirty()
