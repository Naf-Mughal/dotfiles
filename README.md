# dotfiles

CachyOS desktop: **umbriel** compositor + **Noctalia** shell, tuned for a Windows/macOS feel.

## What's here

| Area | Files |
|---|---|
| Keybinds, touchpad, mouse, Num Lock, overview | `home/.config/umbriel/` |
| Idle kit (hooks, AC/battery profiles, lock screen), Alt+Tab switcher | `home/.config/noctalia/` |
| Bar, dock, theme, enabled plugins + plugin settings | `home/.local/state/noctalia/settings.toml` |
| My Noctalia plugins: Capture, Cave Abode, Wallpaper Palette | `home/.local/share/noctalia/plugins/` |
| Terminal (scroll multiplier 20, theme) | `home/.config/foot/` |
| Shell: fish, starship | `home/.config/fish/`, `home/.config/starship.toml` |
| fastfetch, neovim, fuzzel | `home/.config/{fastfetch,nvim,fuzzel}/` |
| GTK 3/4 colours, Thunar styling | `home/.config/gtk-3.0/`, `home/.config/gtk-4.0/` |
| Chrome elastic overscroll flag | `home/.config/chrome-flags.conf` |
| Idle / power / greeter scripts | `home/.local/bin/` |
| Login screen (greetd + noctalia-greeter, Num Lock on) | `system/` |

Highlights:
- Alt+Tab: Noctalia's window switcher with live previews; quick tap switches to the last window.
- Mod+Tab: overview + focus next window. Both work even when an app inhibits shortcuts.
- Touchpad: no acceleration, sensitivity 0.5, scroll factor 0.225. Mouse: no acceleration.
- Num Lock on at the login screen and in the session.
- Wallpaper colours: Caelestia's Material You generator (tonal spot, content, fruit salad, …) via the
  Wallpaper Palette plugin, applied to the shell, apps and greeter.

## Plugins

| Plugin | What it does |
|---|---|
| `nafeel/capture` | Screenshots and region/screen recordings with rich notifications (Mod+Shift+S, Mod+Shift+R) |
| `nafeel/cave-abode` | Xianxia sealed-cave lock screen (and matching greeter): ink-wash wallpaper, sealing formation, runes |
| `nafeel/wallpaper-palette` | Palette from the wallpaper via a port of Caelestia's scheme generator, with all M3 variants (GPL-3.0) |

Edit them live in `~/.local/share/noctalia/plugins/`, then `./sync.sh` to copy them here.

## New machine

```sh
git clone https://github.com/Naf-Mughal/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh --packages   # installs packages, then copies configs (backs up anything it replaces)
```

Then log out and choose the Umbriel session. Wallpapers (`~/Pictures/Wallpapers`) are not in the repo.

## Saving changes

```sh
cd ~/dotfiles
sudo -v      # optional: also refresh the root-only greeter config
./sync.sh    # copy live configs into the repo and show what changed
git add -A && git commit -m "update" && git push
```

To track another file, add its path (relative to `~`) to `files.txt` and run `./sync.sh`.

## Boot recovery

`system/boot-recovery/` makes Limine behave like Windows: no menu on normal boots, and the menu comes
back on its own when something breaks.

- A boot that reaches your desktop (an active Wayland user session, not the greeter) arms
  "boot instantly, no menu" for the **next** boot (`bootctl set-timeout-oneshot menu-disabled`;
  Limine erases it once read).
- A boot that never gets there (bad driver, hang, power cut) never arms it, so the next power-on shows the
  menu for 10 s: pick the LTS kernel, fallback, or a snapshot.
- On purpose from a running system: `systemctl reboot --boot-loader-menu=30`.

Install with `sudo system/boot-recovery/install.sh` (it backs up `/boot/limine.conf`, sets `timeout: 10` and
`remember_last_entry: no`, and checks the one-shot variable is in the form Limine expects).

## Notes

- Changing anything under `[input]` in the umbriel config resets Num Lock until you press it again.
- 3- and 4-finger swipe distance is hardcoded in umbriel; it can't be tuned from config.
