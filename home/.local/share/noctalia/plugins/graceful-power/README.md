# Graceful Power

Restart and Shut down from Noctalia's session menu work like Windows: every
window is asked to close (apps save their session or ask about unsaved work),
apps get 10 s, and if any hold out a notification says "N apps are preventing
restart" with Restart anyway / Cancel (cancels by itself after 2 min). Closing
the holdouts yourself carries on automatically.

The service writes `[shell.session.power]` to
`~/.config/noctalia/graceful-power.toml` (generated, don't edit), pointing at
`bin/graceful-power`. `bin/graceful-power logout` also works, for a keybind.

Needs `jq`, `libnotify`.
