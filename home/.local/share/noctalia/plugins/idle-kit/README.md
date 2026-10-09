# Idle Kit

Windows/macOS-style idle and battery behaviour for Noctalia on Umbriel.

| | Plugged in | On battery |
|---|---|---|
| Dim to 30 % | 9:30 | 2:30 |
| Fade, then lock (Cave Abode) | 10:00 | 3:00 |
| Screen off | 10:30 | 3:15 |
| Suspend (waits while audio plays, then 2 min) | 30:00 | 10:00 |

Battery saver: Power Saver below 30 % on battery, Balanced when plugged in
or above 30 %; notifications at 20 % and 10 %. Picking a mode yourself sticks
until the next plug / unplug / 30 % crossing.

| File | |
|---|---|
| `config/idle-kit.toml` | → `~/.config/noctalia/idle-kit.toml` (written by the service): `[hooks]` for start, charger and battery events, `[lockscreen]` |
| `profiles/ac.toml`, `profiles/battery.toml` | the `[idle]` timeouts; `bin/idle-profile` copies the right one to `~/.config/noctalia/zz-idle-active.toml` |
| `bin/idle-profile` | `auto`, `ac`, `battery`, `apply`, `status` |
| `bin/power-mode` | battery saver (`POWER_SAVER_THRESHOLD`, default 30) |
| `bin/idle-dim` | dims the backlight before the lock (`IDLE_DIM_PERCENT`) |
| `bin/idle-suspend` | suspend that waits for audio to stop (`IDLE_QUIET_SECS`) |
| `bin/battery-warn` | 20 % / 10 % notifications |

To change timeouts, edit `profiles/*.toml`, then
`noctalia msg plugin nafeel/idle-kit:service all apply`. Idle settings made in
Noctalia's GUI (`[idle]` in `~/.local/state/noctalia/settings.toml`) win over
the profiles; `bin/idle-profile status` warns about that.

IPC (`noctalia msg plugin nafeel/idle-kit:service all …`): `apply`,
`profile [auto|ac|battery]`.

Needs `brightnessctl`, `libnotify`, `libpulse` (pactl), `power-profiles-daemon`;
`playerctl` optional.
