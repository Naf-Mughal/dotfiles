# Shell (nafeel/shell)

The desktop: a [Quickshell](https://quickshell.org) shell that Noctalia starts as a plugin. Noctalia
keeps its services (palette, wallpaper, idle, settings, launcher fallback, clipboard); the
shell draws everything on screen as one frame of four bars and four corners, in a xianxia look with
Material 3 Expressive motion.

- `service.luau` starts and supervises it (`bin/nafeel-shell`), turns Noctalia's bars, dock,
  notification server and matching OSDs off while it runs, reserves the frame in umbriel, registers
  the colour template, and writes the plugin settings for it. Disabling the plugin hands the desktop
  back to Noctalia.
- `bin/shell-msg` is the keybind entry (linked into `~/.local/bin`), falling back to Noctalia's
  panels when the shell is off.
- `native/` is its native QML module (`Nafeel`: live window capture, held modifiers), built with
  `native/build.sh` (cmake, Qt 6, wayland-protocols); rebuild after a Qt minor upgrade.
- `quickshell/` is the shell: `config/` tokens and settings, `services/`, `components/`, `modules/`
  (frame, bar, command center, notifications, OSD, lock, switcher), `extensions/`, `shaders/`.

Try the lock safely: `quickshell -p ~/.local/share/noctalia/plugins/shell/quickshell/LockPreview.qml`
(any passcode unlocks it).

## Credits

GPL-3.0-or-later (full notices in NOTICE). It ports code and ideas from:

- [Caelestia shell](https://github.com/caelestia-dots/shell) (GPL-3.0): the colour service and
  scheme, the frame and drawer approach, popout behaviour.
- [Ryoku](https://github.com/ryoku-dev/ryoku) (GPL-3.0): the design discipline (tokens, glosses,
  hairlines), motion tokens, and the BlobRect goo spring.
- [Cave Abode](../cave-abode) (dhrruvsharma/shell, GPL-3.0): the xianxia lock screen and theme.
