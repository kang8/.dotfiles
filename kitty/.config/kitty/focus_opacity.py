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
FOCUSED_OPACITY = "0.90"    # keep in sync with `background_opacity` in the .conf
UNFOCUSED_OPACITY = "0.55"  # how see-through it gets when you click away


def on_focus_change(boss, window, data):
    opacity = FOCUSED_OPACITY if data["focused"] else UNFOCUSED_OPACITY
    # Match by window id explicitly: when focus moves to Chrome there is no
    # "active" kitty OS window, so an unmatched set-background-opacity would
    # silently do nothing. Matching the id targets the panel regardless.
    boss.call_remote_control(
        window, ("set-background-opacity", f"--match=id:{window.id}", opacity)
    )
