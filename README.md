# dotfiles

CachyOS desktop: the **umbriel** compositor + **[nafeel-shell](https://github.com/Naf-Mughal/nafeel-shell)**
(my Quickshell shell, its own repo since 2026-10-12), a xianxia (ink, mist, gold, cinnabar) world
with Material 3 Expressive motion. This repo keeps my personal configs; the shell's code lives in
its repo and `install.sh` here fetches it.

## What's here

| Area | Files |
|---|---|
| Keybinds, touchpad, mouse, Num Lock, overview | `home/.config/umbriel/` |
| The shell's settings (Mod+S: look, wallpaper, weather, …) | `home/.config/nafeel-shell/settings.json` |
| Noctalia config and GUI state (only used if Noctalia runs as a fallback) | `home/.config/noctalia/`, `home/.local/state/noctalia/settings.toml` |
| Old Noctalia plugins (retired; kept for the umbriel fragments some still own) | `home/.local/share/noctalia/plugins/` |
| Terminal (scroll multiplier 20, theme) | `home/.config/foot/` |
| Shell: fish, starship | `home/.config/fish/`, `home/.config/starship.toml` |
| fastfetch, neovim, fuzzel | `home/.config/{fastfetch,nvim,fuzzel}/` |
| GTK 3/4 colours | `home/.config/gtk-3.0/`, `home/.config/gtk-4.0/` |
| Login screen (SDDM with the shell's lock) | `system/sddm/` (written by the shell's `nafeel-greeter install`) |
| Boot recovery (hidden Limine menu) | `system/boot-recovery/` |

## The shell

See the [nafeel-shell README](https://github.com/Naf-Mughal/nafeel-shell). It's cloned to
`~/.local/share/nafeel-shell` and upgraded with `git pull && ./install.sh` there (or by rerunning
`./install.sh` here, which pulls it).

Highlights of the rest of the setup:
- Touchpad: no acceleration, sensitivity 0.5, scroll factor 0.225. Mouse: no acceleration.
- Num Lock on at the login screen and in the session.
- Alt+Tab: the shell's switcher (live previews, most recent first); Mod+Tab: overview + focus next.

## New machine

```sh
git clone https://github.com/Naf-Mughal/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh --packages   # packages, configs (backs up what it replaces), then the shell
```

Then log out and choose the Umbriel session. Wallpapers (`~/Pictures/Wallpapers`) are not in the repo.

## Upgrading from the Noctalia-based setup

If this machine still runs the `nafeel/shell` Noctalia plugin (anything before 2026-10-12):
`git pull && ./install.sh`. It clones nafeel-shell and runs its installer, which retires the old
plugin, points umbriel's autostart at the new shell and offers the SDDM login screen in place of
greetd. Details in the [nafeel-shell README](https://github.com/Naf-Mughal/nafeel-shell#install).

## Saving changes

```sh
cd ~/dotfiles
./sync.sh    # copy live configs into the repo and show what changed (the shell is pushed from its own repo)
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
