# dotfiles

CachyOS desktop: **umbriel** compositor + **Noctalia** shell, tuned for a Windows/macOS feel.

## What's here

| Area | Files |
|---|---|
| Keybinds, touchpad, mouse, Num Lock, overview | `home/.config/umbriel/` |
| Idle kit (hooks, AC/battery profiles, lock screen), Alt+Tab switcher | `home/.config/noctalia/` |
| Bar, dock, theme, enabled plugins + plugin settings | `home/.local/state/noctalia/settings.toml` |
| Terminal (scroll multiplier 20, theme) | `home/.config/foot/` |
| Chrome elastic overscroll flag | `home/.config/chrome-flags.conf` |
| Idle / power / greeter scripts | `home/.local/bin/` |
| Login screen (greetd + noctalia-greeter, Num Lock on) | `system/` |

Highlights:
- Alt+Tab: Noctalia's window switcher with live previews; quick tap switches to the last window.
- Mod+Tab: overview + focus next window. Both work even when an app inhibits shortcuts.
- Touchpad: no acceleration, sensitivity 0.5, scroll factor 0.225. Mouse: no acceleration.
- Num Lock on at the login screen and in the session.

## New machine

```sh
git clone https://github.com/<you>/dotfiles ~/dotfiles
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

## Notes

- Changing anything under `[input]` in the umbriel config resets Num Lock until you press it again.
- 3- and 4-finger swipe distance is hardcoded in umbriel; it can't be tuned from config.
