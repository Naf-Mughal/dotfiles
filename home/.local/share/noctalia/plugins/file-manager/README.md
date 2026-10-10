# File Manager

One default file manager everywhere (Dolphin out of the box).

| Where | |
|---|---|
| **Mod+E** | opens it |
| **xdg-open on a folder** | `inode/directory` default (`xdg-mime`) |
| **Show in folder** | owns `org.freedesktop.FileManager1` on D-Bus (screenshots, browsers, ...) |

Settings → Plugins → File Manager: `dolphin`, `thunar`, `nemo` or `nautilus`.

Generated, don't edit by hand:

- `~/.config/umbriel/plugins/file-manager.toml`: the Mod+E keybind, pulled in by
  `[include.optional]` in `~/.config/umbriel/config.toml`
- `~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service`

IPC: `noctalia msg plugin nafeel/file-manager:service all apply`
