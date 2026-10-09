# Capture

Screenshots and screen recordings for Noctalia on Umbriel: a Windows-style
recording toolbar, and notifications that show a preview and let you Open /
Edit / open the Folder / Delete.

| | Unlocked | Locked (Cave Abode) |
|---|---|---|
| **Mod+Shift+S** | opens the dialog on Screenshot · Region and goes straight into the region picker (the dialog hides), saved + copied | whole monitor |
| **Mod+Shift+R** | opens the dialog on Record; again starts; again stops | records the whole monitor; again stops |
| **影 / 录 tokens** | - | on the lock screen: screenshot / record-stop with timer |

**Dialog** (`nafeel/capture:toolbar`, attached to the bar like the control
center): Screenshot | Record · Region / Screen (/ Annotate) · a delay (off,
3, 5, 10 s) or the microphone and system audio · Take screenshot / Start
recording, which hides the dialog first. While recording: the timer, Stop,
Pause, a live microphone mute and the system audio (fixed once started).
Panel placement (attached / floating) is in Settings → Plugins → Capture.

**Bar** (`nafeel/capture:bar`): idle - click dialog, right-click region
screenshot, middle-click record; recording - red timer, click dialog,
right-click stop, middle-click pause.

Umbriel refuses screencopy while the session is locked, so lock-screen
captures read the monitor from the GPU with gpu-screen-recorder instead.

Settings → Plugins → Capture: recordings folder, frame rate, quality, codec,
pointer, notifications, copy recordings to the clipboard. Screenshot folder
and name pattern are Noctalia's (Settings → Screenshot).

`config/capture.toml` → `~/.config/noctalia/`: Noctalia stops saving
screenshots itself and pipes each one here.

IPC (`noctalia msg plugin nafeel/capture:service all …`): `snip` (the
Mod+Shift+S behaviour), `screenshot [region|screen|edit]`, `record` (the
Mod+Shift+R behaviour), `capture` (the dialog's button), `start
[region|screen]`, `stop`, `pause`, `mic`, `toolbar`, `set kind|shot|area|delay|mic|system <value>`.

Needs `gpu-screen-recorder`, `slurp`, `ffmpeg`, `libnotify`, `imagemagick`,
`libpulse` (pactl, for the live mic mute).
