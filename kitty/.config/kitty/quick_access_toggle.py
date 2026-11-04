# The quick-access panel's own toggle hides a visible panel even when another
# app has focus. raycast-script/kitty-quick-access.sh runs this inside the panel
# (kitten @ kitten) so that case focuses the panel instead.
from kitty.fast_data_types import current_focused_os_window_id, os_window_is_invisible, toggle_os_window_visibility
from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    os_window_id = boss.window_id_map[target_window_id].os_window_id
    if os_window_is_invisible(os_window_id):
        # what kittens/panel does on show, with --move-to-active-monitor
        toggle_os_window_visibility(os_window_id, visible=True, move_to_active_screen=True)
        return 'shown'
    if os_window_id == current_focused_os_window_id():
        toggle_os_window_visibility(os_window_id)
        return 'hidden'
    boss.focus_os_window(os_window_id)
    return 'focused'
