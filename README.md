# dotfiles

CachyOS desktop: **umbriel** compositor + **Noctalia** services + my own **Quickshell** shell on top,
a xianxia (ink, mist, gold, cinnabar) world with Material 3 Expressive motion.

## What's here

| Area | Files |
|---|---|
| Keybinds, touchpad, mouse, Num Lock, overview | `home/.config/umbriel/` |
| Idle kit (hooks, AC/battery profiles, lock screen) | `home/.config/noctalia/` |
| The desktop shell (frame, bar, drawers, dock, command center, notifications, lock) | `home/.local/share/noctalia/plugins/shell/` |
| Theme, enabled plugins + plugin settings | `home/.local/state/noctalia/settings.toml` |
| My Noctalia plugins (shell, capture, cave-abode, wallpaper-palette, …) | `home/.local/share/noctalia/plugins/` |
| Terminal (scroll multiplier 20, theme) | `home/.config/foot/` |
| Shell: fish, starship | `home/.config/fish/`, `home/.config/starship.toml` |
| fastfetch, neovim, fuzzel | `home/.config/{fastfetch,nvim,fuzzel}/` |
| GTK 3/4 colours, Thunar styling | `home/.config/gtk-3.0/`, `home/.config/gtk-4.0/` |
| Chrome elastic overscroll flag | `home/.config/chrome-flags.conf` |
| Idle / power / greeter scripts | `home/.local/bin/` |
| Login screen (greetd + noctalia-greeter, Num Lock on) | `system/` |

## The shell

`nafeel/shell` is a Quickshell shell started by Noctalia as a plugin. Noctalia keeps the services
(palette, wallpaper, idle, settings, launcher fallback, clipboard); the shell draws everything
on screen as one frame of **four bars and four corners**:

- **Left bar**: workspaces; notifications · clipboard · capture; the clock with its 时辰 in the middle;
  media, tray, volume · brightness, Wi-Fi · Bluetooth · battery, power.
- **Corners** grow out of the corner, merged into both bars: notifications and capture (top-left),
  session, Wi-Fi, Bluetooth and battery (bottom-left, part of the bar), toasts (top-right),
  the action center (bottom-right).
- **Bottom centre**: the dock (visible on an empty workspace), which grows into the **command center**:
  search with `>` commands, `=` calculator, `:` clipboard, and tabs for home, apps, media, audio,
  display, system, power, network, Bluetooth, weather, calendar and notifications.
- **Notifications**: the shell is the notification server (toasts, history, actions).
- **Lock**: the cave-abode xianxia lock runs inside the shell, inside the same frame.
- **Motion**: springs with overshoot, Caelestia/Ryoku-style goo (drawers squash and stretch with
  their speed), Noctalia-style concave corners, staggered content, gliding toasts, dock magnify.
- **Settings** (Noctalia settings → Plugins → Shell): corner rounding (tight / compact / restrained /
  relaxed / generous), xianxia immersion (fully immersive with mist and spirit motes, or ornament
  only), and motion (normal / brisk / reduced).

Keys (umbriel): `Mod` command center · `Mod+Space` launcher · `Mod+V` clipboard · `Mod+N`
notifications · `Mod+A` action center · `Mod+Escape` session · `Mod+L` lock. They go through
`shell-msg`, which falls back to Noctalia's panels when the shell is off
(`noctalia msg plugins disable nafeel/shell` hands the desktop back to Noctalia).

Highlights:
- Alt+Tab: the shell's switcher, a carousel of live window previews (most recent first); a quick tap
  switches to the last window, letting go of Alt picks the selection, Esc cancels.
- Mod+Tab: overview + focus next window. Both work even when an app inhibits shortcuts.
- Touchpad: no acceleration, sensitivity 0.5, scroll factor 0.225. Mouse: no acceleration.
- Num Lock on at the login screen and in the session.
- Wallpaper colours: Caelestia's Material You generator (tonal spot, content, fruit salad, …) via the
  Wallpaper Palette plugin, applied to the shell, apps and greeter.

## Plugins

| Plugin | What it does |
|---|---|
| `nafeel/shell` | The desktop: a Quickshell shell (see above), GPL-3.0, with code ported from Caelestia and Ryoku |
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
