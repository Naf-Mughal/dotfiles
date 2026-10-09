# Window Switcher

Alt+Tab like Windows and macOS on Noctalia + Umbriel.

| Key | |
|---|---|
| **Alt+Tab** / **Alt+Shift+Tab** | Noctalia's switcher with live previews; hold Alt, release to pick |
| **Mod+Tab** | Umbriel overview + focus the next window (can be turned off) |

The switcher's look and behaviour (carousel, most recently used first,
current workspace only, captions, count, icons, all monitors) stay in
Noctalia's own **Settings → Shell → Window Switcher**. This plugin writes
those values as the baseline, so the switcher comes back the same even if the
GUI settings are reset. Settings → Plugins → Window Switcher only has the
Mod+Tab overview toggle.

The service writes, and keeps rewriting, two generated files. Don't edit
them by hand:

- `~/.config/noctalia/window-switcher.toml`: `[shell.window_switcher]`
- `~/.config/umbriel/plugins/window-switcher.toml`: the keybinds, pulled in by
  `[include.optional]` in `~/.config/umbriel/config.toml` (one line there, once)

IPC: `noctalia msg plugin nafeel/window-switcher:service all apply`
