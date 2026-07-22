# vim:ft=python
#
# kitty watcher: dim the quick-access dropdown when it loses keyboard focus,
# and restore it when focus returns.
#
# Wired up only for the quick-access-terminal instance (NOT your normal kitty
# windows) via these lines in quick-access-terminal.conf:
#
#     kitty_override dynamic_background_opacity=yes   # allow runtime opacity changes
#     kitty_override watcher=focus_opacity.py         # load this file
#
# Tweak the two values below to taste (0.0 = fully transparent, 1.0 = opaque).
FOCUSED_OPACITY = "0.95"    # keep in sync with `background_opacity` in the .conf
UNFOCUSED_OPACITY = "0.35"  # how see-through it gets when you click away

# Focus *events* alone are not reliable: Window.focus_changed() dedupes on
# Window.is_focused, a flag that tab/window activation also sets while the OS
# window is unfocused (kitty/tabs.py). When that happens, the event fired on
# regaining OS focus is swallowed and this watcher never runs, leaving the
# panel stuck dimmed. So besides reacting to events, a cheap repeating timer
# reconciles opacity against the real focus state and self-heals such cases.
POLL_INTERVAL = 0.4  # seconds

_last_applied: dict = {}  # os_window_id -> opacity we last set
_poll_started = False


def _apply(boss, window):
    # Don't trust event payloads: background opacity is an *OS-window*
    # property while focus events fire per kitty-window (tab switches produce
    # stale focused=False events while the OS window still holds keyboard
    # focus). Always re-derive from which OS window is actually focused.
    from kitty.fast_data_types import current_focused_os_window_id

    focused = current_focused_os_window_id() == window.os_window_id
    opacity = FOCUSED_OPACITY if focused else UNFOCUSED_OPACITY
    # Only send the command on transitions, so the poller stays silent in the
    # steady state and never fights an opacity set manually via kitten @.
    if _last_applied.get(window.os_window_id) == opacity:
        return
    _last_applied[window.os_window_id] = opacity
    # Match by window id explicitly: when focus moves to Chrome there is no
    # "active" kitty OS window, so an unmatched set-background-opacity would
    # silently do nothing. Matching the id targets the panel regardless.
    boss.call_remote_control(
        window, ("set-background-opacity", f"--match=id:{window.id}", opacity)
    )


def _reconcile(timer_id=None):
    from kitty.fast_data_types import get_boss

    boss = get_boss()
    if boss is None:
        return
    seen = set()
    for window in tuple(boss.window_id_map.values()):
        if window.destroyed or window.os_window_id in seen:
            continue
        seen.add(window.os_window_id)
        try:
            _apply(boss, window)
        except Exception:
            pass  # never let a transient error kill the repeating timer


def _ensure_poller():
    global _poll_started
    if not _poll_started:
        from kitty.fast_data_types import add_timer

        add_timer(_reconcile, POLL_INTERVAL, True)
        _poll_started = True


def on_focus_change(boss, window, data):
    _ensure_poller()
    _apply(boss, window)
