# Tab title for {custom} in tab_title_template: the OSC 7501 program status,
# then the "dir: topic" context that claude/.claude/set-session-context.sh
# publishes, else the window title.
# Also loaded as a watcher, since kitty doesn't redraw tabs on SetUserVar.
from kitty.fast_data_types import get_boss

CONTEXT_VAR = 'claude_context'
# kitty's done symbol is a one-cell Nerd Font glyph padded with two spaces;
# ✅ is two cells wide, so it takes one
DONE_SYMBOL = ('\uf00c  ', '✅ ')


def draw_title(data):
    status = data['tab'].program_status.replace(*DONE_SYMBOL)
    tab = get_boss().tab_for_id(data['tab_id'])
    window = tab.active_window if tab else None
    return status + ((window.user_vars.get(CONTEXT_VAR) if window else None) or data['title'])


def on_set_user_var(boss, window, data):
    if data['key'] == CONTEXT_VAR and (tab := window.tabref()) is not None:
        tab.mark_tab_bar_dirty()
