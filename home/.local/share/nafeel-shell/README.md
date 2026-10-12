# Shell (nafeel/shell)

The desktop: a [Quickshell](https://quickshell.org) shell on the umbriel compositor. It draws
everything on screen as one frame of four bars and four corners, in a xianxia look with Material 3
Expressive motion, and runs the desktop's services itself (notifications, polkit, idle, lock,
clipboard, wallpaper, theme).

The shell is a kernel with plugins on it:

- **Kernel** (`quickshell/`): the frame and its drawers, the bar, the dock and command center,
  Settings (`config/`), the primitives (`components/`), the platform services (`services/`: audio,
  network, power, media, time, weather, apps, wallpapers, theme, umbriel, the Bus) and IPC.
- **Plugins** (`quickshell/plugins/<id>/`): every feature on it, each a folder with a
  `plugin.json` (see `services/Plugins.qml` for the format): a root for its services, drawers,
  frame overlays, bar slot items, bar corner panels and command center tabs. Switch them on and
  off on the Settings panel's Plugins page (or `qs ipc call plugins disable <id>`); one that's off
  loads nothing.

Around it:

- `bin/nafeel-shell` starts and supervises it, and generates `quickshell/PluginModules.qml` (an
  import per plugin folder) at every start.
- `bin/shell-msg` is the keybind entry (linked into `~/.local/bin`).
- `bin/nafeel-greeter` and `sddm/` make the login screen: an SDDM theme built from the lock
  plugin's surface, with the shell's palette and wallpaper.
- `native/` is its native QML module (`Nafeel`: live window capture, held modifiers, the goo,
  the annotator canvas), built with `native/build.sh` (cmake, Qt 6, wayland-protocols); rebuild
  after a Qt minor upgrade.

Try the lock safely: `quickshell -p ~/.local/share/nafeel-shell/quickshell/LockPreview.qml`
(any passcode unlocks it).

## Credits

GPL-3.0-or-later (full notices in NOTICE). It ports code and ideas from:

- [Caelestia shell](https://github.com/caelestia-dots/shell) (GPL-3.0): the colour service and
  scheme, the frame and drawer approach, popout behaviour.
- [Ryoku](https://github.com/ryoku-dev/ryoku) (GPL-3.0): the design discipline (tokens, glosses,
  hairlines), motion tokens, and the BlobRect goo spring.
- [Cave Abode](../cave-abode) (dhrruvsharma/shell, GPL-3.0): the xianxia lock screen and theme.
