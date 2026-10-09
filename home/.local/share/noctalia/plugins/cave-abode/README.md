# Cave Abode

The "Sealed Cave Abode" lock screen from
[dhrruvsharma/shell](https://github.com/dhrruvsharma/shell) (GPL-3.0, see
LICENSE) as your lock screen and greetd greeter, run by Noctalia.

Noctalia v5 can't host QML, so the screen is the original Quickshell theme
(`quickshell/`) and this plugin drives it: it starts it for every lock and
feeds it your palette, wallpaper and settings.

| Piece | What it does |
|---|---|
| `service.luau` | settings + palette for the theme; `lock`, `lock-and-suspend`, `preview`, `sync` over IPC; runs the before-suspend watcher; mirrors files for the greeter |
| `shortcut.luau`, `bar.luau` | control center tile and bar button that lock |
| `bin/cave-abode-lock` | one lock at a time; falls back to Noctalia's lock if Quickshell fails |
| `bin/cave-abode-sleep-lock` | logind delay inhibitor: locks before every suspend |
| `config/cave-abode.toml` | → `~/.config/noctalia/`: session menu Lock buttons, palette/wallpaper hooks |
| `greeter/`, `greeter-setup.sh` | the same screen as the greetd greeter (`sudo`, once) |

IPC: `noctalia msg plugin nafeel/cave-abode:service all lock|lock-and-suspend|preview|sync`

Wiring outside the plugin (each file has a `.bak-cave-abode-*` next to it):
Mod+L / Mod+Shift+L in `~/.config/umbriel/config.toml`, the idle lock step
in `~/.config/noctalia/idle-profiles/*.toml` and `zz-idle-active.toml`,
`~/.local/bin/idle-suspend`, and `lock_before_suspend = false` in
`~/.config/noctalia/lockscreen-idle.toml`.

Needs `quickshell`, `qt6-imageformats`, Noto Serif + Noto Serif CJK SC, and
`ttf-material-symbols-variable-git` for the media buttons. Put a picture at
`~/.face` for the avatar ring.
